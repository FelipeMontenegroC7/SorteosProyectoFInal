defmodule ClienteJugadorWeb.Plugs.JugadorRequired do
  @moduledoc """
  Plug que requiere un jugador autenticado en la sesión.
  Redirige a /login si no hay jugador en sesión.
  """
  import Plug.Conn
  import Phoenix.Controller

  alias ServidorCentral.Usuarios

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_session(conn, :jugador) do
      nil ->
        conn
        |> put_flash(:error, "Debes iniciar sesión como jugador.")
        |> redirect(to: "/login")
        |> halt()

      jugador ->
        case Usuarios.buscar_por_usuario(jugador) do
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
