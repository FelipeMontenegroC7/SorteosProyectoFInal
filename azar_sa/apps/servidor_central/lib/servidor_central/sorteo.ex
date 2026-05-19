defmodule ServidorCentral.Sorteo do
  @moduledoc """
  Estado de un sorteo: configuración, premios, ventas y resultado.
  """

  @derive {Jason.Encoder,
           only: [
             :nombre,
             :fecha,
             :valor_billete,
             :fracciones,
             :cantidad_billetes,
             :estado,
             :premios,
             :ventas,
             :numero_ganador,
             :inserted_at,
             :billetes_generados,
             :descripcion_premio_completo,
             :descripcion_premio_fraccion
           ]}

  defstruct nombre: "",
            fecha: "",
            valor_billete: 0,
            fracciones: 0,
            cantidad_billetes: 0,
            estado: :pendiente,
            premios: [],
            ventas: [],
            numero_ganador: nil,
            inserted_at: nil,
            billetes_generados: [],
            descripcion_premio_completo: "",
            descripcion_premio_fraccion: ""

  def from_map(map) when is_map(map) do
    map = stringify_keys(map)

    %__MODULE__{
      nombre: fetch_str(map, "nombre"),
      fecha: fetch_str(map, "fecha"),
      valor_billete: fetch_int(map, "valor_billete"),
      fracciones: fetch_int(map, "fracciones"),
      cantidad_billetes: fetch_int(map, "cantidad_billetes"),
      estado: normalize_estado(Map.get(map, "estado")),
      premios: normalize_premios(Map.get(map, "premios", [])),
      ventas: normalize_ventas(Map.get(map, "ventas", [])),
      numero_ganador: Map.get(map, "numero_ganador"),
      inserted_at: Map.get(map, "inserted_at"),
      billetes_generados: normalize_billetes_generados(Map.get(map, "billetes_generados", [])),
      descripcion_premio_completo: fetch_str(map, "descripcion_premio_completo"),
      descripcion_premio_fraccion: fetch_str(map, "descripcion_premio_fraccion")
    }
  end

  defp stringify_keys(%{} = m) do
    for {k, v} <- m, into: %{} do
      key = if is_atom(k), do: Atom.to_string(k), else: k
      {key, v}
    end
  end

  defp fetch_str(m, k), do: m |> Map.get(k, "") |> to_string()

  defp fetch_int(m, k) do
    case Map.get(m, k) do
      n when is_integer(n) -> n
      n when is_binary(n) -> String.to_integer(n)
      _ -> 0
    end
  end

  defp normalize_estado(nil), do: :pendiente
  defp normalize_estado(:activo), do: :activo
  defp normalize_estado(:finalizado), do: :finalizado
  defp normalize_estado(:pendiente), do: :pendiente
  defp normalize_estado("activo"), do: :activo
  defp normalize_estado("finalizado"), do: :finalizado
  defp normalize_estado("pendiente"), do: :pendiente
  defp normalize_estado("realizado"), do: :finalizado
  defp normalize_estado(_), do: :pendiente

  defp normalize_premios(list) when is_list(list) do
    list
    |> Enum.with_index(1)
    |> Enum.map(fn
      {%{} = p, idx} ->
        p = stringify_keys(p)
        orden_raw = fetch_int(p, "orden")
        orden = if orden_raw == 0, do: idx, else: orden_raw

        %{
          id: Map.get(p, "id") || Ecto.UUID.generate(),
          nombre: fetch_str(p, "nombre"),
          descripcion: fetch_str(p, "descripcion"),
          objeto: fetch_str(p, "objeto"),
          valor: fetch_int(p, "valor"),
          orden: orden,
          ganador_billete: Map.get(p, "ganador_billete"),
          ganador_fraccion: Map.get(p, "ganador_fraccion"),
          ganador_numero: Map.get(p, "ganador_numero"),
          jugador: Map.get(p, "jugador"),
          ganadores: normalize_ganadores(Map.get(p, "ganadores", []))
        }

      {_, idx} ->
        %{id: Ecto.UUID.generate(), nombre: "", descripcion: "", objeto: "", valor: 0, orden: idx}
    end)
    |> Enum.sort_by(& &1.orden)
  end

  defp normalize_premios(_), do: []

  defp normalize_ganadores(list) when is_list(list) do
    Enum.map(list, fn
      %{} = g ->
        g = stringify_keys(g)
        %{
          jugador: fetch_str(g, "jugador"),
          fraccion: fetch_int(g, "fraccion"),
          premio_ganado: fetch_int(g, "premio_ganado")
        }
      _ -> %{jugador: "", fraccion: 0, premio_ganado: 0}
    end)
  end
  defp normalize_ganadores(_), do: []

  defp normalize_ventas(list) when is_list(list) do
    Enum.map(list, fn
      %{} = v ->
        v = stringify_keys(v)

        %{
          id: Map.get(v, "id") || Ecto.UUID.generate(),
          jugador: fetch_str(v, "jugador"),
          billete: fetch_int(v, "billete"),
          fraccion: fetch_int(v, "fraccion"),
          inserted_at: Map.get(v, "inserted_at") || DateTime.utc_now() |> DateTime.to_iso8601()
        }

      _ ->
        %{id: Ecto.UUID.generate(), jugador: "", billete: 0, fraccion: 0, inserted_at: ""}
    end)
  end

  defp normalize_ventas(_), do: []

  defp normalize_billetes_generados(list) when is_list(list) do
    Enum.map(list, fn
      %{} = b ->
        b = stringify_keys(b)
        %{
          billete: fetch_int(b, "billete"),
          numero: fetch_str(b, "numero")
        }
      _ -> %{billete: 0, numero: "0000"}
    end)
  end
  defp normalize_billetes_generados(_), do: []

  def to_serializable(%__MODULE__{} = s) do
    %{
      nombre: s.nombre,
      fecha: s.fecha,
      valor_billete: s.valor_billete,
      fracciones: s.fracciones,
      cantidad_billetes: s.cantidad_billetes,
      estado: s.estado |> to_string(),
      premios: s.premios,
      ventas: s.ventas,
      numero_ganador: s.numero_ganador,
      inserted_at: s.inserted_at,
      billetes_generados: s.billetes_generados,
      descripcion_premio_completo: s.descripcion_premio_completo,
      descripcion_premio_fraccion: s.descripcion_premio_fraccion
    }
  end
end
