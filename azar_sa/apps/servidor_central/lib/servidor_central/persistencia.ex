defmodule ServidorCentral.Persistencia do
  @moduledoc """
  Persistencia JSON de sorteos en la carpeta `data/` de la raíz del umbrella.
  """

  @excluir ~w(bitacora usuarios admins prueba_final)

  defp data_dir do
    Application.get_env(:servidor_central, :data_dir) ||
      Path.expand("data", File.cwd!())
  end

  @doc false
  def path_sorteo(nombre_sorteo) do
    Path.join(data_dir(), "#{nombre_sorteo}.json")
  end

  def path_usuarios, do: Path.join(data_dir(), "usuarios.json")
  def path_admins, do: Path.join(data_dir(), "admins.json")

  @doc """
  Lista nombres de sorteo (sin extensión) presentes en disco.
  """
  def listar_nombres_sorteos do
    case File.ls(data_dir()) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".json"))
        |> Enum.map(&String.replace_suffix(&1, ".json", ""))
        |> Enum.reject(&(&1 in @excluir))
        |> Enum.reject(&(&1 == ""))

      {:error, _} ->
        []
    end
  end

  @doc """
  Guarda un mapa o struct compatible con Jason (sorteo serializable).
  """
  def guardar_sorteo(nombre, datos) do
    File.mkdir_p!(data_dir())
    path = path_sorteo(nombre)

    with {:ok, json} <- Jason.encode(datos) do
      case File.write(path, json) do
        :ok -> {:ok, path}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Carga un sorteo desde JSON. Devuelve mapa con claves de cadena (normalizar con Sorteo.from_map/1).
  """
  def cargar_sorteo(nombre) do
    path = path_sorteo(nombre)

    with {:ok, bin} <- File.read(path),
         {:ok, map} <- Jason.decode(bin) do
      {:ok, map}
    else
      {:error, :enoent} -> {:error, :no_encontrado}
      {:error, %Jason.DecodeError{}} -> {:error, :json_invalido}
      {:error, reason} -> {:error, reason}
    end
  end
end
