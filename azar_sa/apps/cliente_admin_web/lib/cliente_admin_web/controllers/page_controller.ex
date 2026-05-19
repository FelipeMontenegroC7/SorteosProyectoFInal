defmodule ClienteAdminWeb.PageController do
  use ClienteAdminWeb, :controller

  alias ServidorCentral.{Bitacora, GestorSorteos, Sorteo, Usuarios}

  def home(conn, params) do
    orden = Map.get(params, "orden", "desc")
    
    state_weight = fn
      :activo -> 1
      :pendiente -> 2
      :finalizado -> 3
      _ -> 4
    end

    sorteos = GestorSorteos.listar_sorteos()
    
    sorteos = if orden == "asc" do
      Enum.sort_by(sorteos, & &1.fecha, :asc)
    else
      Enum.sort_by(sorteos, & &1.fecha, :desc)
    end

    sorteos = Enum.sort_by(sorteos, fn s -> state_weight.(s.estado) end, :asc)

    stats = dashboard_stats(sorteos)
    render(conn, :home, sorteos: sorteos, stats: stats, orden: orden)
  end

  def clientes(conn, _params) do
    admin = get_session(conn, :admin)
    clientes = GestorSorteos.lista_clientes_detallada()
    # Ordenar por inversión total (mayor a menor)
    clientes = Enum.sort_by(clientes, & &1.valor_fracciones, :desc)
    Bitacora.registrar("admin_consulto_jugadores", :ok, %{admin_id: admin})
    render(conn, :clientes, clientes: clientes)
  end

  def cliente_detalle(conn, %{"usuario" => usuario}) do
    admin = get_session(conn, :admin)
    sorteos = GestorSorteos.listar_sorteos()
    user_info = Usuarios.buscar_por_usuario(usuario)

    case user_info do
      nil ->
        conn
        |> put_flash(:error, "Jugador no encontrado.")
        |> redirect(to: ~p"/clientes")

      user ->
        # Recopilar todas las compras del jugador
        ventas_jugador =
          for %Sorteo{} = s <- sorteos,
              v <- s.ventas,
              v.jugador == usuario,
              do: %{sorteo: s, venta: v}

        # Agrupar por sorteo
        ventas_por_sorteo =
          ventas_jugador
          |> Enum.group_by(fn %{sorteo: s} -> s.nombre end)

        total_fracciones = length(ventas_jugador)

        valor_fracciones =
          Enum.sum(
            Enum.map(ventas_jugador, fn %{sorteo: s} ->
              div(s.valor_billete, max(s.fracciones, 1))
            end)
          )

        # Ganancias obtenidas
        ganancias =
          Enum.reduce(ventas_jugador, 0, fn %{sorteo: s, venta: v}, acc ->
            if s.estado == :finalizado do
              premio_ganado =
                Enum.reduce(s.premios, 0, fn p, pacc ->
                  ganador = Enum.find(Map.get(p, :ganadores, []), &(&1.jugador == v.jugador && &1.fraccion == v.fraccion))
                  if ganador, do: pacc + Map.get(ganador, :premio_ganado, 0), else: pacc
                end)
              acc + premio_ganado
            else
              acc
            end
          end)

        # Lista de sorteos para el filtro
        nombres_sorteos = ventas_por_sorteo |> Map.keys() |> Enum.sort()

        Bitacora.registrar("admin_consulto_jugador", :ok, %{admin_id: admin, jugador_id: usuario})

        render(conn, :cliente_detalle,
          usuario: usuario,
          user: user,
          ventas_jugador: ventas_jugador,
          ventas_por_sorteo: ventas_por_sorteo,
          total_fracciones: total_fracciones,
          valor_fracciones: valor_fracciones,
          ganancias: ganancias,
          nombres_sorteos: nombres_sorteos,
          sorteos: sorteos
        )
    end
  end

  def balance(conn, params) do
    admin = get_session(conn, :admin)
    balance = GestorSorteos.balance_global()
    filtro_sorteo_param = Map.get(params, "sorteo", "todos")
    filtro_estado = Map.get(params, "estado", "todos")
    ocultar_finalizados = Map.get(params, "ocultar_finalizados", "false") == "true"

    # Filtrar primero por estado para poblar el dropdown de sorteos
    sorteos_por_estado =
      balance.balances_por_sorteo
      |> Enum.filter(fn b ->
        if filtro_estado == "todos", do: true, else: to_string(b.estado) == filtro_estado
      end)
      |> Enum.filter(fn b ->
        if ocultar_finalizados, do: b.estado != :finalizado, else: true
      end)

    nombres_sorteos =
      sorteos_por_estado
      |> Enum.map(& &1.nombre)
      |> Enum.sort()

    # Resetear el filtro de sorteo si el seleccionado ya no está en la lista tras aplicar filtros de estado
    filtro_sorteo =
      if filtro_sorteo_param != "todos" and filtro_sorteo_param not in nombres_sorteos do
        "todos"
      else
        filtro_sorteo_param
      end

    balances_filtrados =
      sorteos_por_estado
      |> Enum.filter(fn b -> 
        if filtro_sorteo == "todos", do: true, else: b.nombre == filtro_sorteo
      end)
      |> Enum.sort_by(fn b ->
        peso_estado =
          case b.estado do
            :activo -> 1
            :pendiente -> 2
            :finalizado -> 3
            _ -> 4
          end
        {peso_estado, b.nombre}
      end)

    # Recalcular balance general con lo filtrado
    balance_recalculado = %{
      usuarios_total: balance.usuarios_total,
      ingresos_global: Enum.sum(Enum.map(balances_filtrados, & &1.ingreso)),
      total_premios_pagados: Enum.sum(Enum.map(balances_filtrados, & &1.premios_pagados)),
      total_premios_ofertados: Enum.sum(Enum.map(balances_filtrados, fn b -> 
         Map.get(b, :premios, []) |> Enum.map(&Map.get(&1, :valor, 0)) |> Enum.sum() 
      end)),
      ganancia_neta_global: Enum.sum(Enum.map(balances_filtrados, & &1.ganancia_neta))
    }

    Bitacora.registrar("balance_consultado", :ok, %{admin_id: admin, filtro: filtro_sorteo})

    render(conn, :balance,
      balance: balance_recalculado,
      balances_filtrados: balances_filtrados,
      nombres_sorteos: nombres_sorteos,
      filtro_sorteo: filtro_sorteo,
      filtro_estado: filtro_estado,
      ocultar_finalizados: ocultar_finalizados
    )
  end

  defp dashboard_stats(sorteos) do
    ventas_total = Enum.sum(Enum.map(sorteos, &length(&1.ventas)))

    ingresos =
      Enum.sum(for %Sorteo{} = s <- sorteos, do: precio_fraccion(s) * length(s.ventas))

    activos = Enum.count(sorteos, &(&1.estado == :activo))
    pendientes = Enum.count(sorteos, &(&1.estado == :pendiente))
    finalizados = Enum.count(sorteos, &(&1.estado == :finalizado))

    %{
      total_sorteos: length(sorteos),
      ventas_total: ventas_total,
      ingresos: ingresos,
      activos: activos,
      pendientes: pendientes,
      finalizados: finalizados
    }
  end

  defp precio_fraccion(%Sorteo{valor_billete: v, fracciones: f}) when f > 0, do: div(v, f)
  defp precio_fraccion(_), do: 0
end
