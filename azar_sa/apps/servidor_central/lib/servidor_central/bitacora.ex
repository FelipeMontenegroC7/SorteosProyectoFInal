defmodule ServidorCentral.Bitacora do
  @moduledoc """
  Bitácora obligatoria en consola y `data/bitacora.txt` con el formato:

  `[Fecha-Hora - Solicitud - Resultado OK/Negado]`

  Soporta metadatos opcionales para registro enriquecido:
  `[Fecha-Hora - Solicitud - Resultado | clave1=valor1, clave2=valor2]`
  """

  defp data_dir do
    Application.get_env(:servidor_central, :data_dir) ||
      Path.expand("data", File.cwd!())
  end

  defp txt_path, do: Path.join(data_dir(), "bitacora.txt")

  @doc """
  Registra un evento en consola y archivo.

  - `solicitud`: texto corto (ej. "recargar_creditos")
  - `resultado`: `:ok` o `:negado` (o strings equivalentes)
  - `metadata`: mapa opcional con campos adicionales (admin_id, sorteo_id, jugador_id, etc.)
  """
  def registrar(solicitud, resultado, metadata \\ %{})

  def registrar(solicitud, resultado, metadata) when is_map(metadata) do
    File.mkdir_p!(data_dir())

    ts = DateTime.utc_now() |> DateTime.to_string()
    res = normalizar_resultado(resultado)

    meta_str =
      if map_size(metadata) > 0 do
        campos =
          metadata
          |> Enum.map(fn {k, v} -> "#{k}=#{inspect(v)}" end)
          |> Enum.join(", ")

        " | #{campos}"
      else
        ""
      end

    linea = "[#{ts} - #{solicitud} - #{res}#{meta_str}]\n"

    IO.write(linea)
    _ = File.write(txt_path(), linea, [:append])
    :ok
  end

  defp normalizar_resultado(:ok), do: "OK"
  defp normalizar_resultado(:negado), do: "Negado"
  defp normalizar_resultado("ok"), do: "OK"
  defp normalizar_resultado("OK"), do: "OK"
  defp normalizar_resultado("negado"), do: "Negado"
  defp normalizar_resultado("Negado"), do: "Negado"
  defp normalizar_resultado(other), do: other |> to_string()
end
