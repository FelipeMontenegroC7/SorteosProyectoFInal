defmodule ServidorCentral.GestorSorteos do
  @moduledoc """
  Supervisor dinámico de `SorteoServer`. API única hacia los clientes web.
  """
  use DynamicSupervisor

  alias ServidorCentral.{Bitacora, Persistencia, Sorteo, SorteoServer, Usuarios}

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Arranca procesos para cada archivo JSON encontrado en `data/`.
  """
  def preload_desde_disco do
    for nombre <- Persistencia.listar_nombres_sorteos() do
      _ = asegurar_servidor(nombre)
    end

    :ok
  end

  @doc """
  Crea un sorteo nuevo y lo persiste al arrancar el GenServer.
  """
  def crear_nuevo_sorteo(%Sorteo{} = sorteo) do
    cond do
      servidor_vivo?(sorteo.nombre) ->
        Bitacora.registrar("crear_sorteo", :negado, %{sorteo_id: sorteo.nombre, razon: :ya_existe})
        {:error, :ya_existe}

      File.exists?(Persistencia.path_sorteo(sorteo.nombre)) ->
        Bitacora.registrar("crear_sorteo", :negado, %{sorteo_id: sorteo.nombre, razon: :ya_existe})
        {:error, :ya_existe}

      true ->
        # Generar números de 4 dígitos para cada billete antes de crear
        billetes_generados =
          for billete_num <- 1..sorteo.cantidad_billetes do
            %{
              billete: billete_num,
              numero: :rand.uniform(10000) - 1 |> Integer.to_string() |> String.pad_leading(4, "0")
            }
          end

        sorteo_con_billetes = %{sorteo | billetes_generados: billetes_generados}

        case DynamicSupervisor.start_child(__MODULE__, {SorteoServer, sorteo_con_billetes}) do
          {:ok, _pid} = ok ->
            Bitacora.registrar("crear_sorteo", :ok, %{sorteo_id: sorteo.nombre})
            ok

          {:error, {:already_started, _}} ->
            {:error, :ya_existe}

          {:error, reason} ->
            Bitacora.registrar("crear_sorteo", :negado, %{sorteo_id: sorteo.nombre, razon: reason})
            {:error, reason}
        end
    end
  end

  def listar_sorteos do
    Persistencia.listar_nombres_sorteos()
    |> Enum.flat_map(fn nombre ->
      _ = asegurar_servidor(nombre)

      case consultar_estado(nombre) do
        nil -> []
        s -> [s]
      end
    end)
  end

  def consultar_estado(nombre) do
    case SorteoServer.obtener_estado(nombre) do
      %Sorteo{} = s -> s
      {:error, _} -> nil
    end
  end

  def actualizar_sorteo(nombre, attrs), do: SorteoServer.actualizar_sorteo(nombre, attrs)

  def agregar_premio(nombre, premio_map), do: SorteoServer.agregar_premio(nombre, premio_map)

  def eliminar_premio(nombre, premio_id), do: SorteoServer.eliminar_premio(nombre, premio_id)

  def editar_premio(nombre, premio_id, nuevos_datos), do: SorteoServer.editar_premio(nombre, premio_id, nuevos_datos)

  def comprar_fraccion(nombre, jugador), do: SorteoServer.comprar_fraccion(nombre, jugador)

  def comprar_fraccion_especifica(nombre, jugador, billete, fraccion),
    do: SorteoServer.comprar_fraccion_especifica(nombre, jugador, billete, fraccion)

  def comprar_billete_completo(nombre, jugador, billete),
    do: SorteoServer.comprar_billete_completo(nombre, jugador, billete)

  def listar_billetes_disponibles(nombre),
    do: SorteoServer.listar_billetes_disponibles(nombre)

  def devolver_compra(nombre, venta_id), do: SorteoServer.devolver_compra(nombre, venta_id)

  def ejecutar_sorteo(nombre), do: SorteoServer.ejecutar_sorteo(nombre)

  def eliminar_sorteo(nombre) do
    case SorteoServer.eliminar_sorteo(nombre) do
      {:ok, ^nombre} ->
        # Detener el proceso
        case GenServer.whereis(SorteoServer.via(nombre)) do
          nil -> :ok
          pid -> DynamicSupervisor.terminate_child(__MODULE__, pid)
        end
        # Borrar archivo del disco
        path = Persistencia.path_sorteo(nombre)
        File.rm(path)
        Bitacora.registrar("eliminar_sorteo", :ok, %{sorteo_id: nombre})
        {:ok, nombre}

      {:error, :tiene_ventas} ->
        Bitacora.registrar("eliminar_sorteo", :negado, %{sorteo_id: nombre, razon: :tiene_ventas})
        {:error, :tiene_ventas}

      err ->
        err
    end
  end

  defp asegurar_servidor(nombre) do
    cond do
      servidor_vivo?(nombre) ->
        :ok

      true ->
        case Persistencia.cargar_sorteo(nombre) do
          {:ok, map} ->
            sorteo = Sorteo.from_map(map)

            case DynamicSupervisor.start_child(__MODULE__, {SorteoServer, sorteo}) do
              {:ok, _} -> :ok
              {:error, {:already_started, _}} -> :ok
              _ -> :error
            end

          _ ->
            :error
        end
    end
  end

  defp servidor_vivo?(nombre), do: GenServer.whereis(SorteoServer.via(nombre)) != nil

  # === consultas para admin ===

  @doc """
  Devuelve mapa con estadísticas globales.
  """
  def balance_global do
    usuarios = Usuarios.listar()
    sorteos = listar_sorteos()

    total_usuarios = length(usuarios)

    # Balance por sorteo con detalle financiero
    balances_por_sorteo =
      Enum.map(sorteos, fn s ->
        precio = div(s.valor_billete, max(s.fracciones, 1))
        ingreso = precio * length(s.ventas)

        premios_pagados =
          if s.estado == :finalizado do
            s.premios
            |> Enum.flat_map(&Map.get(&1, :ganadores, []))
            |> Enum.reduce(0, fn g, a -> a + Map.get(g, :premio_ganado, 0) end)
          else
            0
          end

        ganancia = ingreso - premios_pagados

        num_ganadores =
          s.premios
          |> Enum.flat_map(&Map.get(&1, :ganadores, []))
          |> length()

        %{
          nombre: s.nombre,
          estado: s.estado,
          ingreso: ingreso,
          ventas: length(s.ventas),
          fracciones_total: s.cantidad_billetes * s.fracciones,
          premios_pagados: premios_pagados,
          ganancia_neta: ganancia,
          num_ganadores: num_ganadores,
          premios: s.premios
        }
      end)

    # Ingresos brutos = sumatoria del ingreso por fracciones vendidas de todos los sorteos
    ingresos_global = Enum.sum(Enum.map(balances_por_sorteo, & &1.ingreso))

    # Premios pagados = sumatoria de todos los premios pagados de todos los sorteos
    total_premios_pagados = Enum.sum(Enum.map(balances_por_sorteo, & &1.premios_pagados))

    # Premios ofertados = sumatoria del valor de todos los premios definidos en todos los sorteos
    total_premios_ofertados =
      Enum.sum(for s <- sorteos, p <- s.premios, do: Map.get(p, :valor, 0))

    # Ganancia neta = ingresos brutos - premios pagados
    ganancia_neta_global = ingresos_global - total_premios_pagados

    %{
      usuarios_total: total_usuarios,
      ingresos_global: ingresos_global,
      total_premios_pagados: total_premios_pagados,
      total_premios_ofertados: total_premios_ofertados,
      ganancia_neta_global: ganancia_neta_global,
      balances_por_sorteo: balances_por_sorteo
    }
  end

  @doc """
  Lista detallada de clientes con sus compras.
  """
  def lista_clientes_detallada do
    usuarios = Usuarios.listar()
    sorteos = listar_sorteos()

    Enum.map(usuarios, fn u ->
      usuario_nombre = Map.get(u, "usuario")

      # Recopilar todas las ventas de este jugador
      ventas_jugador =
        for s <- sorteos,
            v <- s.ventas,
            v.jugador == usuario_nombre,
            do: %{sorteo: s, venta: v}

      total_fracciones = length(ventas_jugador)

      valor_fracciones =
        Enum.sum(
          Enum.map(ventas_jugador, fn %{sorteo: s} ->
            div(s.valor_billete, max(s.fracciones, 1))
          end)
        )

      # Calcular billetes completos
      billetes_completos =
        ventas_jugador
        |> Enum.group_by(fn %{sorteo: s, venta: v} -> {s.nombre, v.billete} end)
        |> Enum.count(fn {{sorteo_nombre, _billete}, ventas} ->
          sorteo = Enum.find(sorteos, &(&1.nombre == sorteo_nombre))
          sorteo && length(ventas) >= sorteo.fracciones
        end)

      %{
        usuario: usuario_nombre,
        creditos: Map.get(u, "creditos", 0),
        ingresado: Map.get(u, "ingresado", 0),
        gastado: Map.get(u, "gastado", 0),
        total_compras: total_fracciones,
        valor_fracciones: valor_fracciones,
        billetes_completos: billetes_completos
      }
    end)
  end

  # === balance por sorteo ===

  @doc """
  Calcula el balance financiero de un sorteo individual.
  Lógica: Ingresos Brutos - Premios Pagados = Ganancia Neta.
  """
  def calcular_balance_sorteo(nombre) do
    case consultar_estado(nombre) do
      nil ->
        {:error, :no_encontrado}

      %Sorteo{} = s ->
        precio_fraccion = div(s.valor_billete, max(s.fracciones, 1))
        ingresos_brutos = precio_fraccion * length(s.ventas)

        premios_pagados =
          if s.estado == :finalizado do
            s.premios
            |> Enum.flat_map(&Map.get(&1, :ganadores, []))
            |> Enum.reduce(0, fn g, acc -> acc + Map.get(g, :premio_ganado, 0) end)
          else
            0
          end

        ganancia_neta = ingresos_brutos - premios_pagados

        {:ok,
         %{
           nombre: s.nombre,
           estado: s.estado,
           ingresos_brutos: ingresos_brutos,
           premios_pagados: premios_pagados,
           ganancia_neta: ganancia_neta,
           total_ventas: length(s.ventas),
           total_fracciones: s.cantidad_billetes * s.fracciones,
           fracciones_vendidas: length(s.ventas),
           num_ganadores:
             s.premios
             |> Enum.flat_map(&Map.get(&1, :ganadores, []))
             |> length()
         }}
    end
  end
end
