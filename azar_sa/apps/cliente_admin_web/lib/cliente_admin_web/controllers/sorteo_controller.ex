defmodule ClienteAdminWeb.SorteoController do
  use ClienteAdminWeb, :controller

  alias ServidorCentral.GestorSorteos
  alias ServidorCentral.Sorteo
  alias ServidorCentral.Sorteo.Changesets

  @default_desc_completo "Depende del premio establecido, si tienes un billete completo te llevas TODO el premio para ti."
  @default_desc_fraccion "Te llevas una parte dependiendo de la fracción."

  def nuevo(conn, _params) do
    render(conn, :nuevo, changeset: empty_crear_changeset())
  end

  def crear(conn, params) do
    attrs = param_map_crear(params)

    # Convertir fecha a ISO8601 con zona UTC
    fecha_str = Map.get(attrs, :fecha, "") <> "Z"
    attrs = Map.put(attrs, :fecha, fecha_str)

    with {:ok, data} <- apply_insert(Changesets.crear_sorteo(attrs)),
         sorteo <- build_sorteo_struct(data),
         {:ok, _pid} <- GestorSorteos.crear_nuevo_sorteo(sorteo) do
      conn
      |> put_flash(:info, "Sorteo «#{sorteo.nombre}» creado correctamente. Está en estado Pendiente.")
      |> redirect(to: "/")
    else
      {:error, %Ecto.Changeset{} = cs} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_flash(:error, ClienteAdminWeb.ChangesetHelpers.messages(cs))
        |> render(:nuevo, changeset: cs)

      {:error, :ya_existe} ->
        conn
        |> put_flash(:error, "Ya existe un sorteo con ese nombre.")
        |> put_status(:unprocessable_entity)
        |> render(:nuevo, changeset: Changesets.crear_sorteo(attrs))

      {:error, _} ->
        conn
        |> put_flash(:error, "No fue posible crear el sorteo.")
        |> put_status(:unprocessable_entity)
        |> render(:nuevo, changeset: Changesets.crear_sorteo(attrs))
    end
  end

  def show(conn, %{"nombre" => nombre}) do
    case GestorSorteos.consultar_estado(nombre) do
      nil ->
        conn
        |> put_flash(:error, "Sorteo no encontrado.")
        |> redirect(to: ~p"/")

      %Sorteo{} = sorteo ->
        target_ts = fecha_to_timestamp(sorteo.fecha)
        render(conn, :show, sorteo: sorteo, tiempo_restante: target_ts)
    end
  end

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

  def edit(conn, %{"nombre" => nombre}) do
    case GestorSorteos.consultar_estado(nombre) do
      nil ->
        conn
        |> put_flash(:error, "Sorteo no encontrado.")
        |> redirect(to: ~p"/")

      %Sorteo{} = sorteo ->
        cs = Changesets.editar_sorteo(sorteo_to_edit_params(sorteo))
        render(conn, :edit, sorteo: sorteo, changeset: cs)
    end
  end

  def update(conn, %{"nombre" => nombre} = params) do
    attrs = param_map_edicion(params)

    case GestorSorteos.consultar_estado(nombre) do
      nil ->
        conn |> put_flash(:error, "Sorteo no encontrado.") |> redirect(to: ~p"/")

      %Sorteo{} = sorteo ->
        with {:ok, data} <- apply_insert(Changesets.editar_sorteo(attrs)),
             {:ok, _} <- GestorSorteos.actualizar_sorteo(nombre, data) do
          conn
          |> put_flash(:info, "Sorteo actualizado.")
          |> redirect(to: ~p"/sorteos/#{nombre}")
        else
          {:error, %Ecto.Changeset{} = cs} ->
            conn
            |> put_status(:unprocessable_entity)
            |> put_flash(:error, ClienteAdminWeb.ChangesetHelpers.messages(cs))
            |> render(:edit, sorteo: sorteo, changeset: cs)

          {:error, :tiene_ventas} ->
            conn
            |> put_flash(:error, "No se puede cambiar el estado porque ya han comprado Billetes o fracciones.")
            |> redirect(to: ~p"/sorteos/#{nombre}/editar")

          {:error, :cerrado} ->
            conn
            |> put_flash(:error, "El sorteo ya está cerrado o finalizado.")
            |> redirect(to: ~p"/sorteos/#{nombre}")

          {:error, _} ->
            conn
            |> put_flash(:error, "No se pudo actualizar.")
            |> redirect(to: ~p"/sorteos/#{nombre}")
        end
    end
  end

  def agregar_premio(conn, %{"nombre" => nombre} = params) do
    orden_raw = parse_int(Map.get(params, "orden"))

    with %Sorteo{} = sorteo <- GestorSorteos.consultar_estado(nombre),
         orden <- premio_orden(orden_raw, sorteo),
         attrs <- %{
           nombre: Map.get(params, "nombre_premio") || Map.get(params, "nombre"),
           descripcion: Map.get(params, "descripcion", ""),
           objeto: Map.get(params, "objeto", ""),
           valor: parse_int(Map.get(params, "valor")),
           orden: orden
         },
         {:ok, p} <- apply_insert(Changesets.premio(attrs)),
         premio <- build_premio_map(p),
         {:ok, _} <- GestorSorteos.agregar_premio(nombre, premio) do
      conn
      |> put_flash(:info, "Premio agregado.")
      |> redirect(to: ~p"/sorteos/#{nombre}")
    else
      nil ->
        conn |> put_flash(:error, "Sorteo no encontrado.") |> redirect(to: ~p"/")

      {:error, %Ecto.Changeset{} = cs} ->
        case GestorSorteos.consultar_estado(nombre) do
          nil ->
            conn |> put_flash(:error, "Sorteo no encontrado.") |> redirect(to: ~p"/")

          sorteo ->
            conn
            |> put_status(:unprocessable_entity)
            |> put_flash(:error, ClienteAdminWeb.ChangesetHelpers.messages(cs))
            |> render(:show, sorteo: sorteo, tiempo_restante: fecha_to_timestamp(sorteo.fecha))
        end

      {:error, :cerrado} ->
        conn
        |> put_flash(:error, "El sorteo está cerrado.")
        |> redirect(to: ~p"/sorteos/#{nombre}")

      {:error, _} ->
        conn
        |> put_flash(:error, "No se pudo agregar el premio.")
        |> redirect(to: ~p"/sorteos/#{nombre}")
    end
  end

  def eliminar_premio(conn, %{"nombre" => nombre, "premio_id" => premio_id}) do
    case GestorSorteos.eliminar_premio(nombre, premio_id) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Premio eliminado.")
        |> redirect(to: ~p"/sorteos/#{nombre}")

      {:error, :cerrado} ->
        conn
        |> put_flash(:error, "El sorteo está cerrado.")
        |> redirect(to: ~p"/sorteos/#{nombre}")

      {:error, _} ->
        conn
        |> put_flash(:error, "No se pudo eliminar el premio.")
        |> redirect(to: ~p"/sorteos/#{nombre}")
    end
  end

  def editar_premio(conn, %{"nombre" => nombre, "premio_id" => premio_id} = params) do
    valor = parse_int(Map.get(params, "valor"))
    nuevos_datos = %{
      nombre: Map.get(params, "nombre_premio"),
      objeto: Map.get(params, "objeto"),
      descripcion: Map.get(params, "descripcion"),
      valor: valor
    }

    case GestorSorteos.editar_premio(nombre, premio_id, nuevos_datos) do
      {:ok, _sorteo} ->
        conn
        |> put_flash(:info, "Premio actualizado correctamente.")
        |> redirect(to: ~p"/sorteos/#{nombre}")

      {:error, :no_encontrado} ->
        conn
        |> put_flash(:error, "Sorteo o premio no encontrado.")
        |> redirect(to: ~p"/sorteos/#{nombre}")

      {:error, :cerrado} ->
        conn
        |> put_flash(:error, "El sorteo está cerrado.")
        |> redirect(to: ~p"/sorteos/#{nombre}")

      {:error, _} ->
        conn
        |> put_flash(:error, "No se pudo actualizar el premio.")
        |> redirect(to: ~p"/sorteos/#{nombre}")
    end
  end

  def ejecutar(conn, %{"nombre" => nombre}) do
    case GestorSorteos.ejecutar_sorteo(nombre) do
      {:ok, sorteo} ->
        conn
        |> put_flash(:info, "¡Sorteo ejecutado! Número ganador: #{sorteo.numero_ganador}")
        |> redirect(to: ~p"/sorteos/#{nombre}")

      {:error, razon} ->
        msg =
          case razon do
            :ya_finalizado -> "El sorteo ya fue ejecutado."
            :sin_premios -> "Agrega al menos un premio antes de sortear."
            :sin_ventas -> "No hay ventas registradas."
            _ -> "No se pudo ejecutar el sorteo."
          end

        conn
        |> put_flash(:error, msg)
        |> redirect(to: ~p"/sorteos/#{nombre}")
    end
  end

  def eliminar(conn, %{"nombre" => nombre}) do
    case GestorSorteos.eliminar_sorteo(nombre) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Sorteo «#{nombre}» eliminado correctamente.")
        |> redirect(to: ~p"/")

      {:error, :tiene_ventas} ->
        conn
        |> put_flash(:error, "No se puede eliminar: ya hay fracciones vendidas.")
        |> redirect(to: ~p"/sorteos/#{nombre}")

      {:error, _} ->
        conn
        |> put_flash(:error, "No se pudo eliminar el sorteo.")
        |> redirect(to: ~p"/sorteos/#{nombre}")
    end
  end

  defp empty_crear_changeset do
    Changesets.crear_sorteo(%{})
  end

  defp param_map_crear(params) do
    %{
      nombre: Map.get(params, "nombre"),
      fecha: Map.get(params, "fecha"),
      valor_billete: parse_int(Map.get(params, "valor_billete")),
      fracciones: parse_int(Map.get(params, "fracciones")),
      cantidad_billetes: parse_int(Map.get(params, "cantidad_billetes")),
      descripcion_premio_completo: Map.get(params, "descripcion_premio_completo", ""),
      descripcion_premio_fraccion: Map.get(params, "descripcion_premio_fraccion", "")
    }
  end

  defp param_map_edicion(params) do
    fecha_raw = Map.get(params, "fecha", "")
    fecha_str =
      cond do
        String.contains?(fecha_raw, "Z") or String.contains?(fecha_raw, "+") -> fecha_raw
        true -> fecha_raw
      end

    %{
      fecha: fecha_str,
      valor_billete: parse_int(Map.get(params, "valor_billete")),
      fracciones: parse_int(Map.get(params, "fracciones")),
      cantidad_billetes: parse_int(Map.get(params, "cantidad_billetes")),
      descripcion_premio_completo: Map.get(params, "descripcion_premio_completo", ""),
      descripcion_premio_fraccion: Map.get(params, "descripcion_premio_fraccion", ""),
      estado: Map.get(params, "estado")
    }
  end

  defp sorteo_to_edit_params(%Sorteo{} = s) do
    %{
      fecha: s.fecha,
      valor_billete: s.valor_billete,
      fracciones: s.fracciones,
      cantidad_billetes: s.cantidad_billetes,
      descripcion_premio_completo: s.descripcion_premio_completo,
      descripcion_premio_fraccion: s.descripcion_premio_fraccion,
      estado: Atom.to_string(s.estado)
    }
  end

  defp parse_int(nil), do: nil

  defp parse_int(v) when is_binary(v) do
    case Integer.parse(String.trim(v)) do
      {n, _} -> n
      :error -> nil
    end
  end

  defp parse_int(v) when is_integer(v), do: v

  defp apply_insert(cs) do
    Ecto.Changeset.apply_action(cs, :insert)
  end

  defp build_sorteo_struct(data) do
    ts = DateTime.utc_now() |> DateTime.to_iso8601()

    desc_completo = Map.get(data, :descripcion_premio_completo, "")
    desc_fraccion = Map.get(data, :descripcion_premio_fraccion, "")

    struct(Sorteo, %{
      nombre: data.nombre,
      fecha: data.fecha,
      valor_billete: data.valor_billete,
      fracciones: data.fracciones,
      cantidad_billetes: data.cantidad_billetes,
      estado: :pendiente,
      premios: [],
      ventas: [],
      numero_ganador: nil,
      inserted_at: ts,
      descripcion_premio_completo: if(desc_completo == "", do: @default_desc_completo, else: desc_completo),
      descripcion_premio_fraccion: if(desc_fraccion == "", do: @default_desc_fraccion, else: desc_fraccion)
    })
  end

  defp premio_orden(nil, sorteo), do: premio_orden(0, sorteo)
  defp premio_orden(0, %Sorteo{premios: ps}), do: length(ps) + 1
  defp premio_orden(n, _) when is_integer(n) and n > 0, do: n
  defp premio_orden(_, %Sorteo{premios: ps}), do: length(ps) + 1

  defp build_premio_map(%{nombre: nombre, valor: valor, orden: orden} = data) do
    %{
      id: Ecto.UUID.generate(),
      nombre: nombre,
      descripcion: Map.get(data, :descripcion, ""),
      objeto: Map.get(data, :objeto, ""),
      valor: valor,
      orden: orden,
      ganador_billete: nil,
      ganador_fraccion: nil,
      jugador: nil
    }
  end
end
