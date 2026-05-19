defmodule ClienteJugadorWeb.PageController do
  use ClienteJugadorWeb, :controller

  alias ServidorCentral.{GestorSorteos, Sorteo, Usuarios}

  def home(conn, params) do
    jugador = get_session(conn, :jugador)
    
    if jugador do
      filtro = Map.get(params, "orden", "fecha")

      sorteos =
        GestorSorteos.listar_sorteos()
        |> Enum.filter(&(&1.estado == :activo))
        |> case do
          lista when filtro == "premio" ->
            Enum.sort_by(lista, fn s -> 
              s.premios |> Enum.map(& &1.valor) |> Enum.max(fn -> 0 end)
            end, :desc)
          lista ->
            Enum.sort_by(lista, & &1.fecha, :asc)
        end
  
      creditos =
        case Usuarios.saldo(jugador) do
          {:ok, c} -> c
          _ -> 0
        end
  
      render(conn, :home, 
        sorteos: sorteos, 
        jugador: jugador, 
        creditos: creditos,
        filtro_orden: filtro
      )
    else
      conn
      |> put_layout(html: false)
      |> render(:landing)
    end
  end

  def sorteo(conn, %{"nombre" => nombre}) do
    case GestorSorteos.consultar_estado(nombre) do
      nil ->
        conn
        |> put_flash(:error, "Este sorteo no está disponible.")
        |> redirect(to: ~p"/")

      %Sorteo{} = sorteo ->
        jugador = get_session(conn, :jugador)
        precio = precio_fraccion(sorteo)
        target_ts = fecha_to_timestamp(sorteo.fecha)

        # Obtener billetes disponibles
        disponibles =
          case GestorSorteos.listar_billetes_disponibles(nombre) do
            {:ok, list} -> list
            _ -> []
          end

        render(conn, :sorteo,
          sorteo: sorteo,
          jugador: jugador,
          precio_fraccion: precio,
          tiempo_restante: target_ts,
          disponibles: disponibles
        )
    end
  end

  # Compra aleatoria (compatibilidad)
  def comprar(conn, %{"nombre" => nombre}) do
    jugador = get_session(conn, :jugador)

    case GestorSorteos.comprar_fraccion(nombre, jugador) do
      {:ok, _venta} ->
        conn
        |> put_flash(:info, "¡Compra confirmada! Se te asignó una fracción al azar.")
        |> redirect(to: ~p"/mis-boletos")

      {:error, razon} ->
        msg = error_msg(razon)
        conn |> put_flash(:error, msg) |> redirect(to: ~p"/sorteos/#{nombre}")
    end
  end

  # Compra de fracción específica
  def comprar_especifica(conn, %{"nombre" => nombre} = params) do
    jugador = get_session(conn, :jugador)
    billete = parse_int(Map.get(params, "billete"))
    fraccion = parse_int(Map.get(params, "fraccion"))

    case GestorSorteos.comprar_fraccion_especifica(nombre, jugador, billete, fraccion) do
      {:ok, _venta} ->
        conn
        |> put_flash(:info, "¡Compra confirmada! Billete ##{billete}, fracción ##{fraccion}.")
        |> redirect(to: ~p"/mis-boletos")

      {:error, razon} ->
        msg = error_msg(razon)
        conn |> put_flash(:error, msg) |> redirect(to: ~p"/sorteos/#{nombre}")
    end
  end

  # Compra de billete completo
  def comprar_completo(conn, %{"nombre" => nombre} = params) do
    jugador = get_session(conn, :jugador)
    billete = parse_int(Map.get(params, "billete"))

    case GestorSorteos.comprar_billete_completo(nombre, jugador, billete) do
      {:ok, _ventas} ->
        conn
        |> put_flash(:info, "¡Billete ##{billete} comprado completo!")
        |> redirect(to: ~p"/mis-boletos")

      {:error, razon} ->
        msg = error_msg(razon)
        conn |> put_flash(:error, msg) |> redirect(to: ~p"/sorteos/#{nombre}")
    end
  end

  def mis_boletos(conn, params) do
    jugador = get_session(conn, :jugador)
    filtro_sorteo = Map.get(params, "sorteo", "todos")

    boletos =
      case jugador do
        nil ->
          []

        nombre when is_binary(nombre) ->
          GestorSorteos.listar_sorteos()
          |> Enum.flat_map(fn s ->
            s.ventas
            |> Enum.filter(&(&1.jugador == nombre))
            |> Enum.group_by(& &1.billete)
            |> Enum.map(fn {billete_num, ventas} ->
              billete_info = Enum.find(s.billetes_generados, &(&1.billete == billete_num))

              # Calcular ganancia total para este billete
              ganancia =
                Enum.reduce(s.premios, 0, fn p, acc ->
                  # El billete ganador está en el premio, no en el ganador individual
                  if Map.get(p, :ganador_billete) == billete_num do
                    Enum.reduce(Map.get(p, :ganadores, []), acc, fn g, a ->
                      if g.jugador == nombre do
                        a + Map.get(g, :premio_ganado, 0)
                      else
                        a
                      end
                    end)
                  else
                    acc
                  end
                end)

              %{
                sorteo: s,
                billete_num: billete_num,
                numero: (if billete_info, do: billete_info.numero, else: "????"),
                ventas: Enum.sort_by(ventas, & &1.fraccion),
                ganancia_total: ganancia
              }
            end)
          end)
          |> Enum.sort_by(fn b -> b.sorteo.fecha end, :desc)
      end

    nombres_sorteos =
      boletos
      |> Enum.map(& &1.sorteo.nombre)
      |> Enum.uniq()
      |> Enum.sort()

    boletos_filtrados =
      if filtro_sorteo == "todos" do
        boletos
      else
        Enum.filter(boletos, &(&1.sorteo.nombre == filtro_sorteo))
      end

    render(conn, :mis_boletos, 
      jugador: jugador, 
      boletos: boletos_filtrados,
      nombres_sorteos: nombres_sorteos,
      filtro_sorteo: filtro_sorteo
    )
  end

  def devolver(conn, %{"venta_id" => venta_id}) do
    jugador = get_session(conn, :jugador)

    case jugador do
      nil ->
        conn
        |> put_flash(:error, "Debes iniciar sesión.")
        |> redirect(to: ~p"/login")

      nombre ->
        resultado =
          Enum.find_value(GestorSorteos.listar_sorteos(), fn s ->
            if Enum.any?(s.ventas, &(&1.id == venta_id && &1.jugador == nombre)) do
              GestorSorteos.devolver_compra(s.nombre, venta_id)
            else
              nil
            end
          end)

        case resultado do
          {:ok, _venta} ->
            conn
            |> put_flash(:info, "Devolución exitosa. Créditos reintegrados.")
            |> redirect(to: ~p"/mis-boletos")

          {:error, _} ->
            conn
            |> put_flash(:error, "No se pudo procesar la devolución.")
            |> redirect(to: ~p"/mis-boletos")

          nil ->
            conn
            |> put_flash(:error, "Boleto no encontrado.")
            |> redirect(to: ~p"/mis-boletos")
        end
    end
  end

  def recargar(conn, _params) do
    jugador = get_session(conn, :jugador)
    render(conn, :recargar, jugador: jugador)
  end

  def do_recargar(conn, %{"monto" => monto_str, "numero_tarjeta" => _tarjeta}) do
    jugador = get_session(conn, :jugador)

    case Integer.parse(monto_str) do
      {monto, _} when monto > 0 ->
        case Usuarios.recargar_creditos(jugador, monto) do
          :ok ->
            conn
            |> put_flash(:info, "Recarga de $#{monto} exitosa.")
            |> redirect(to: ~p"/balance")

          _ ->
            conn
            |> put_flash(:error, "Error en la recarga.")
            |> redirect(to: ~p"/recargar")
        end

      _ ->
        conn
        |> put_flash(:error, "Monto inválido.")
        |> redirect(to: ~p"/recargar")
    end
  end

  def balance(conn, _params) do
    jugador = get_session(conn, :jugador)

    {saldo, ingresado, gastado} =
      if jugador do
        user = Usuarios.buscar_por_usuario(jugador)
        {
          Map.get(user, "creditos", 0),
          Map.get(user, "ingresado", 0),
          Map.get(user, "gastado", 0)
        }
      else
        {0, 0, 0}
      end

    render(conn, :balance, jugador: jugador, saldo: saldo, ingresado: ingresado, gastado: gastado)
  end

  defp precio_fraccion(%Sorteo{valor_billete: v, fracciones: f}) when f > 0, do: div(v, f)
  defp precio_fraccion(_), do: 0

  defp fecha_to_timestamp(fecha_str) when is_binary(fecha_str) do
    normalized =
      cond do
        String.contains?(fecha_str, "Z") or String.contains?(fecha_str, "+") -> fecha_str
        String.length(fecha_str) == 16 -> fecha_str <> ":00Z"
        String.length(fecha_str) == 19 -> fecha_str <> "Z"
        true -> fecha_str <> "Z"
      end

    case DateTime.from_iso8601(normalized) do
      {:ok, fecha, _} -> DateTime.to_unix(fecha)
      _ -> 0
    end
  end
  defp fecha_to_timestamp(_), do: 0

  defp parse_int(nil), do: 0
  defp parse_int(v) when is_integer(v), do: v
  defp parse_int(v) when is_binary(v) do
    case Integer.parse(String.trim(v)) do
      {n, _} -> n
      :error -> 0
    end
  end

  def historial(conn, params) do
    jugador = get_session(conn, :jugador)
    filtro = Map.get(params, "orden", "fecha")

    sorteos_finalizados =
      GestorSorteos.listar_sorteos()
      |> Enum.filter(&(&1.estado == :finalizado))
      |> case do
        lista when filtro == "premio" ->
          Enum.sort_by(lista, fn s -> 
            s.premios |> Enum.map(& &1.valor) |> Enum.max(fn -> 0 end)
          end, :desc)
        lista ->
          Enum.sort_by(lista, & &1.fecha, :desc)
      end

    render(conn, :historial, 
      sorteos: sorteos_finalizados, 
      jugador: jugador,
      filtro_orden: filtro
    )
  end

  defp error_msg(:cerrado), do: "Este sorteo ya cerró ventas."
  defp error_msg(:agotado), do: "No quedan fracciones disponibles."
  defp error_msg(:sin_fondos), do: "No tienes suficientes créditos."
  defp error_msg(:billete_invalido), do: "Billete no válido."
  defp error_msg(:fraccion_invalida), do: "Fracción no válida."
  defp error_msg(:fraccion_ocupada), do: "Esa fracción ya fue comprada."
  defp error_msg(:billete_agotado), do: "Todas las fracciones de ese billete ya fueron vendidas."
  defp error_msg(:no_encontrado), do: "Sorteo no disponible."
  defp error_msg(_), do: "No pudimos completar la compra."
end
