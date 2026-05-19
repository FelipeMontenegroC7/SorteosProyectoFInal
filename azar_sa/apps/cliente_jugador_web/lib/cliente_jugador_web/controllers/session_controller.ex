defmodule ClienteJugadorWeb.SessionController do
  use ClienteJugadorWeb, :controller
  alias ServidorCentral.Usuarios

  def login(conn, _params) do
    render(conn, :login, error: nil)
  end

  def create(conn, %{"usuario" => usuario, "password" => password}) do
    case Usuarios.autenticar(usuario, password) do
      {:ok, _user} ->
        conn
        |> put_session(:jugador, usuario)
        |> redirect(to: "/")

      {:error, _razon} ->
        conn
        |> put_flash(:error, "Usuario o contraseña incorrectos.")
        |> render(:login, error: true)
    end
  end

  def registro(conn, _params) do
    render(conn, :registro, error: nil, changes: %{})
  end

  def do_registro(conn, %{
    "usuario" => usuario,
    "password" => password,
    "password_confirmation" => password_conf,
    "nombre" => nombre,
    "apellido" => apellido,
    "documento" => documento
  }) do
    if password != password_conf do
      conn
      |> put_flash(:error, "Las contraseñas no coinciden.")
      |> render(:registro, error: true, changes: %{"usuario" => usuario, "nombre" => nombre, "apellido" => apellido, "documento" => documento})
    else
      case Usuarios.registrar_usuario(usuario, password, nombre, apellido, documento) do
        {:ok, _user} ->
          conn
          |> put_flash(:info, "Cuenta creada. Inicia sesión.")
          |> redirect(to: "/login")

        {:error, :usuario_invalido} ->
          conn
          |> put_flash(:error, "Usuario inválido (mínimo 3 caracteres).")
          |> render(:registro, error: true, changes: %{"usuario" => usuario, "nombre" => nombre, "apellido" => apellido, "documento" => documento})

        {:error, :password_invalido} ->
          conn
          |> put_flash(:error, "Contraseña muy corta (mínimo 6 caracteres).")
          |> render(:registro, error: true, changes: %{"usuario" => usuario, "nombre" => nombre, "apellido" => apellido, "documento" => documento})

        {:error, :nombre_invalido} ->
          conn
          |> put_flash(:error, "Nombre y apellido son obligatorios.")
          |> render(:registro, error: true, changes: %{"usuario" => usuario, "nombre" => nombre, "apellido" => apellido, "documento" => documento})

        {:error, :documento_invalido} ->
          conn
          |> put_flash(:error, "Documento inválido (mínimo 5 caracteres).")
          |> render(:registro, error: true, changes: %{"usuario" => usuario, "nombre" => nombre, "apellido" => apellido, "documento" => documento})

        {:error, :documento_ya_existe} ->
          conn
          |> put_flash(:error, "Ya existe una cuenta con ese documento.")
          |> render(:registro, error: true, changes: %{"usuario" => usuario, "nombre" => nombre, "apellido" => apellido, "documento" => documento})

        {:error, :ya_existe} ->
          conn
          |> put_flash(:error, "El usuario ya existe.")
          |> render(:registro, error: true, changes: %{"usuario" => usuario, "nombre" => nombre, "apellido" => apellido, "documento" => documento})

        _ ->
          conn
          |> put_flash(:error, "Error al crear cuenta.")
          |> render(:registro, error: true, changes: %{})
      end
    end
  end

  def delete(conn, _params) do
    usuario = get_session(conn, :jugador)
    ServidorCentral.Bitacora.registrar("logout_jugador", :ok, %{jugador_id: usuario})

    conn
    |> clear_session()
    |> redirect(to: "/")
  end
end
