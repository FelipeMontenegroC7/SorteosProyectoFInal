defmodule ClienteJugadorWeb.Router do
  use ClienteJugadorWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {ClienteJugadorWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :jugador_required do
    plug(ClienteJugadorWeb.Plugs.JugadorRequired)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", ClienteJugadorWeb do
    pipe_through(:browser)

    get("/", PageController, :home)
    get("/login", SessionController, :login)
    post("/login", SessionController, :create)
    get("/registro", SessionController, :registro)
    post("/registro", SessionController, :do_registro)
    get("/logout", SessionController, :delete)
  end

  scope "/", ClienteJugadorWeb do
    pipe_through([:browser, :jugador_required])

    get("/sorteos/:nombre", PageController, :sorteo)
    post("/sorteos/:nombre/comprar", PageController, :comprar)
    post("/sorteos/:nombre/comprar-especifica", PageController, :comprar_especifica)
    post("/sorteos/:nombre/comprar-completo", PageController, :comprar_completo)
    get("/mis-boletos", PageController, :mis_boletos)
    post("/mis-boletos/:venta_id/devolver", PageController, :devolver)
    get("/historial", PageController, :historial)
    get("/recargar", PageController, :recargar)
    post("/recargar", PageController, :do_recargar)
    get("/balance", PageController, :balance)
  end

  if Application.compile_env(:cliente_jugador_web, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through(:browser)

      live_dashboard("/dashboard", metrics: ClienteJugadorWeb.Telemetry)
    end
  end
end
