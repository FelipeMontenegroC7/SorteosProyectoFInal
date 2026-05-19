defmodule ClienteAdminWeb.SessionController do
  use ClienteAdminWeb, :controller
  alias ServidorCentral.Admins

  def login(conn, _params) do
    render(conn, :login, error: nil)
  end

  def create_login(conn, %{"usuario" => usuario, "password" => password}) do
    case Admins.autenticar(usuario, password) do
      {:ok, _admin} ->
        conn
        |> put_session(:admin, usuario)
        |> redirect(to: ~p"/")

      {:error, _razon} ->
        conn
        |> put_flash(:error, "Usuario o contraseña incorrectos.")
        |> render(:login, error: true)
    end
  end

  def delete(conn, _params) do
    usuario = get_session(conn, :admin)
    ServidorCentral.Bitacora.registrar("logout_admin", :ok, %{admin_id: usuario})

    conn
    |> clear_session()
    |> redirect(to: ~p"/login")
  end
end
