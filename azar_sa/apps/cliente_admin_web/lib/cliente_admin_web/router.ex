defmodule ClienteAdminWeb.Router do
  use ClienteAdminWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {ClienteAdminWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :admin_required do
    plug(ClienteAdminWeb.Plugs.AdminRequired)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", ClienteAdminWeb do
    pipe_through([:browser, :admin_required])

    get("/", PageController, :home)

    get("/sorteos/nuevo", SorteoController, :nuevo)
    post("/sorteos", SorteoController, :crear)
    get("/sorteos/:nombre", SorteoController, :show)
    get("/sorteos/:nombre/editar", SorteoController, :edit)
    put("/sorteos/:nombre", SorteoController, :update)
    post("/sorteos/:nombre/premios", SorteoController, :agregar_premio)
    post("/sorteos/:nombre/premios/:premio_id/eliminar", SorteoController, :eliminar_premio)
    put("/sorteos/:nombre/premios/:premio_id", SorteoController, :editar_premio)
    post("/sorteos/:nombre/ejecutar", SorteoController, :ejecutar)
    post("/sorteos/:nombre/eliminar", SorteoController, :eliminar)

    get("/clientes", PageController, :clientes)
    get("/clientes/:usuario", PageController, :cliente_detalle)
    get("/balance", PageController, :balance)
  end

  scope "/", ClienteAdminWeb do
    pipe_through(:browser)

    get("/login", SessionController, :login)
    post("/login", SessionController, :create_login)
    get("/logout", SessionController, :delete)
  end

  if Application.compile_env(:cliente_admin_web, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through(:browser)

      live_dashboard("/dashboard", metrics: ClienteAdminWeb.Telemetry)
    end
  end
end
