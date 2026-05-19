defmodule ServidorCentral.Admins do
  @moduledoc """
  Gestión de administradores con autenticación independiente de jugadores.
  Persistencia en `data/admins.json`.
  """

  alias ServidorCentral.{Bitacora, Persistencia}

  @type admin :: %{
          id: String.t(),
          usuario: String.t(),
          password_hash: String.t(),
          creado_en: String.t()
        }

  def listar do
    case cargar_todo() do
      {:ok, %{"admins" => admins}} when is_list(admins) -> admins
      _ -> []
    end
  end

  def buscar_por_usuario(usuario) when is_binary(usuario) do
    listar()
    |> Enum.find(fn
      %{"usuario" => u} -> u == usuario
      %{usuario: u} -> u == usuario
      _ -> false
    end)
  end

  def registrar_admin(usuario, password_plano) when is_binary(usuario) and is_binary(password_plano) do
    solicitud = "registrar_admin"

    cond do
      String.trim(usuario) == "" or String.length(usuario) < 3 ->
        Bitacora.registrar(solicitud, :negado, %{admin_id: usuario, razon: :usuario_invalido})
        {:error, :usuario_invalido}

      String.length(password_plano) < 6 ->
        Bitacora.registrar(solicitud, :negado, %{admin_id: usuario, razon: :password_invalido})
        {:error, :password_invalido}

      buscar_por_usuario(usuario) ->
        Bitacora.registrar(solicitud, :negado, %{admin_id: usuario, razon: :ya_existe})
        {:error, :ya_existe}

      true ->
        hash = Bcrypt.hash_pwd_salt(password_plano)

        nuevo = %{
          "id" => Ecto.UUID.generate(),
          "usuario" => usuario,
          "password_hash" => hash,
          "creado_en" => DateTime.utc_now() |> DateTime.to_string()
        }

        with {:ok, data} <- cargar_todo(),
             admins when is_list(admins) <- Map.get(data, "admins", []),
             :ok <- guardar_todo(%{"admins" => [nuevo | admins]}) do
          Bitacora.registrar(solicitud, :ok, %{admin_id: usuario})
          {:ok, nuevo}
        else
          _ ->
            Bitacora.registrar(solicitud, :negado, %{admin_id: usuario})
            {:error, :no_persistido}
        end
    end
  end

  def autenticar(usuario, password_plano) when is_binary(usuario) and is_binary(password_plano) do
    solicitud = "login_admin"

    case buscar_por_usuario(usuario) do
      nil ->
        Bitacora.registrar(solicitud, :negado, %{admin_id: usuario})
        {:error, :credenciales_invalidas}

      %{"password_hash" => hash} = u ->
        if Bcrypt.verify_pass(password_plano, hash) do
          Bitacora.registrar(solicitud, :ok, %{admin_id: usuario})
          {:ok, u}
        else
          Bitacora.registrar(solicitud, :negado, %{admin_id: usuario})
          {:error, :credenciales_invalidas}
        end

      _ ->
        Bitacora.registrar(solicitud, :negado, %{admin_id: usuario})
        {:error, :credenciales_invalidas}
    end
  end

  defp cargar_todo do
    path = Persistencia.path_admins()
    File.mkdir_p!(Path.dirname(path))

    case File.read(path) do
      {:ok, bin} ->
        case Jason.decode(bin) do
          {:ok, map} when is_map(map) -> {:ok, map}
          _ -> {:ok, %{"admins" => []}}
        end

      {:error, :enoent} ->
        {:ok, %{"admins" => []}}

      {:error, _} ->
        {:ok, %{"admins" => []}}
    end
  end

  defp guardar_todo(%{} = data) do
    path = Persistencia.path_admins()
    File.mkdir_p!(Path.dirname(path))

    with {:ok, json} <- Jason.encode(data) do
      case File.write(path, json) do
        :ok -> :ok
        _ -> :error
      end
    else
      _ -> :error
    end
  end
end
