defmodule ServidorCentral.Usuarios do
  @moduledoc """
  Gestión de usuarios (jugadores) con créditos y persistencia en `data/usuarios.json`.

  Reglas:
  - Cada jugador inicia con 0 créditos.
  - El campo `documento` es la llave primaria (único e irrepetible).
  - Solo el ServidorCentral modifica el archivo.
  """

  alias ServidorCentral.{Bitacora, Persistencia}

  @type usuario :: %{
          id: String.t(),
          usuario: String.t(),
          nombre: String.t(),
          apellido: String.t(),
          documento: String.t(),
          password_hash: String.t(),
          creditos: non_neg_integer(),
          ingresado: non_neg_integer(),
          gastado: non_neg_integer(),
          creado_en: String.t()
        }

  def listar do
    case cargar_todo() do
      {:ok, %{"usuarios" => usuarios}} when is_list(usuarios) -> usuarios
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

  def buscar_por_documento(documento) when is_binary(documento) do
    listar()
    |> Enum.find(fn
      %{"documento" => d} -> d == documento
      _ -> false
    end)
  end

  def registrar_usuario(usuario, password_plano, nombre, apellido, documento)
      when is_binary(usuario) and is_binary(password_plano) and
           is_binary(nombre) and is_binary(apellido) and is_binary(documento) do
    solicitud = "registrar_usuario"

    cond do
      String.trim(usuario) == "" or String.length(usuario) < 3 ->
        Bitacora.registrar(solicitud, :negado, %{jugador_id: usuario, razon: :usuario_invalido})
        {:error, :usuario_invalido}

      String.length(password_plano) < 6 ->
        Bitacora.registrar(solicitud, :negado, %{jugador_id: usuario, razon: :password_invalido})
        {:error, :password_invalido}

      String.trim(nombre) == "" or String.trim(apellido) == "" ->
        Bitacora.registrar(solicitud, :negado, %{jugador_id: usuario, razon: :nombre_invalido})
        {:error, :nombre_invalido}

      String.trim(documento) == "" or String.length(documento) < 5 ->
        Bitacora.registrar(solicitud, :negado, %{jugador_id: usuario, razon: :documento_invalido})
        {:error, :documento_invalido}

      buscar_por_documento(documento) ->
        Bitacora.registrar(solicitud, :negado, %{jugador_id: usuario, razon: :documento_ya_existe})
        {:error, :documento_ya_existe}

      buscar_por_usuario(usuario) ->
        Bitacora.registrar(solicitud, :negado, %{jugador_id: usuario, razon: :ya_existe})
        {:error, :ya_existe}

      true ->
        hash = Bcrypt.hash_pwd_salt(password_plano)

        nuevo = %{
          "id" => Ecto.UUID.generate(),
          "usuario" => usuario,
          "nombre" => String.trim(nombre),
          "apellido" => String.trim(apellido),
          "documento" => String.trim(documento),
          "password_hash" => hash,
          "creditos" => 0,
          "ingresado" => 0,
          "gastado" => 0,
          "creado_en" => DateTime.utc_now() |> DateTime.to_string()
        }

        with {:ok, data} <- cargar_todo(),
             usuarios when is_list(usuarios) <- Map.get(data, "usuarios", []),
             :ok <- guardar_todo(%{"usuarios" => [nuevo | usuarios]}) do
          Bitacora.registrar(solicitud, :ok, %{jugador_id: usuario, documento: documento})
          {:ok, nuevo}
        else
          _ ->
            Bitacora.registrar(solicitud, :negado, %{jugador_id: usuario})
            {:error, :no_persistido}
        end
    end
  end

  def autenticar(usuario, password_plano) when is_binary(usuario) and is_binary(password_plano) do
    solicitud = "login_jugador"

    case buscar_por_usuario(usuario) do
      nil ->
        Bitacora.registrar(solicitud, :negado, %{jugador_id: usuario})
        {:error, :credenciales_invalidas}

      %{"password_hash" => hash} = u ->
        if Bcrypt.verify_pass(password_plano, hash) do
          Bitacora.registrar(solicitud, :ok, %{jugador_id: usuario})
          {:ok, u}
        else
          Bitacora.registrar(solicitud, :negado, %{jugador_id: usuario})
          {:error, :credenciales_invalidas}
        end

      _ ->
        Bitacora.registrar(solicitud, :negado, %{jugador_id: usuario})
        {:error, :credenciales_invalidas}
    end
  end

  def saldo(usuario) when is_binary(usuario) do
    case buscar_por_usuario(usuario) do
      %{"creditos" => c} when is_integer(c) -> {:ok, c}
      _ -> {:error, :no_existe}
    end
  end

  def recargar_creditos(usuario, monto) when is_binary(usuario) and is_integer(monto) do
    solicitud = "recargar_creditos"

    with true <- monto > 0 or {:error, :monto_invalido},
         {:ok, data} <- cargar_todo(),
         %{"usuarios" => usuarios} <- data,
         {:ok, nuevos} <- actualizar_lista(usuarios, usuario, fn u ->
           creditos = Map.get(u, "creditos", 0) + monto
           ingresado = Map.get(u, "ingresado", 0) + monto
           Map.merge(u, %{"creditos" => creditos, "ingresado" => ingresado})
         end),
         :ok <- guardar_todo(%{"usuarios" => nuevos}) do
      Bitacora.registrar(solicitud, :ok, %{jugador_id: usuario, monto: monto})
      :ok
    else
      _ ->
        Bitacora.registrar(solicitud, :negado, %{jugador_id: usuario, monto: monto})
        {:error, :no_pudo_recargar}
    end
  end

  def debitar(usuario, monto) when is_binary(usuario) and is_integer(monto) do
    solicitud = "debitar_creditos"

    with true <- monto > 0 or {:error, :monto_invalido},
         {:ok, data} <- cargar_todo(),
         %{"usuarios" => usuarios} <- data,
         {:ok, nuevos} <- actualizar_lista(usuarios, usuario, fn u ->
           creditos = Map.get(u, "creditos", 0)

           if creditos >= monto do
             gastado = Map.get(u, "gastado", 0) + monto
             Map.merge(u, %{"creditos" => creditos - monto, "gastado" => gastado})
           else
             :sin_fondos
           end
         end),
         :ok <- guardar_todo(%{"usuarios" => nuevos}) do
      Bitacora.registrar(solicitud, :ok, %{jugador_id: usuario, monto: monto})
      :ok
    else
      {:error, :no_existe} ->
        Bitacora.registrar(solicitud, :negado, %{jugador_id: usuario, razon: :no_existe})
        {:error, :no_existe}

      {:error, :sin_fondos} ->
        Bitacora.registrar(solicitud, :negado, %{jugador_id: usuario, razon: :sin_fondos})
        {:error, :sin_fondos}

      _ ->
        Bitacora.registrar(solicitud, :negado, %{jugador_id: usuario})
        {:error, :no_pudo_debitar}
    end
  end

  defp actualizar_lista(usuarios, usuario, fun) when is_list(usuarios) do
    case Enum.split_with(usuarios, fn u -> Map.get(u, "usuario") != usuario end) do
      {antes, [u | despues]} ->
        case fun.(u) do
          :sin_fondos -> {:error, :sin_fondos}
          nuevo when is_map(nuevo) -> {:ok, antes ++ [nuevo] ++ despues}
        end

      {_antes, []} ->
        {:error, :no_existe}
    end
  end

  defp cargar_todo do
    path = Persistencia.path_usuarios()
    File.mkdir_p!(Path.dirname(path))

    case File.read(path) do
      {:ok, bin} ->
        case Jason.decode(bin) do
          {:ok, map} when is_map(map) -> {:ok, map}
          _ -> {:ok, %{"usuarios" => []}}
        end

      {:error, _} ->
        {:ok, %{"usuarios" => []}}
    end
  end

  defp guardar_todo(%{} = data) do
    path = Persistencia.path_usuarios()
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
