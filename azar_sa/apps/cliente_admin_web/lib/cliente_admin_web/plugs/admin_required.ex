defmodule ClienteAdminWeb.Plugs.AdminRequired do
  @moduledoc """
  Plug que requiere un admin autenticado en la sesión.
  Redirige a /login si no hay admin en sesión.
  """
  import Plug.Conn
  import Phoenix.Controller

  alias ServidorCentral.Admins

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_session(conn, :admin) do
      nil ->
        conn
        |> put_flash(:error, "Debes iniciar sesión como administrador.")
        |> redirect(to: "/login")
        |> halt()

      admin_usuario ->
        case Admins.buscar_por_usuario(admin_usuario) do
          nil ->
            conn
            |> clear_session()
            |> put_flash(:error, "Sesión inválida.")
            |> redirect(to: "/login")
            |> halt()

          _ ->
            conn
        end
    end
  end
end
