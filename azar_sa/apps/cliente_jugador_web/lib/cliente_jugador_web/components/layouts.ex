defmodule ClienteJugadorWeb.Layouts do
  @moduledoc """
  Layouts del panel de jugador. Sidebar fijo a la izquierda con navegación.
  """
  use ClienteJugadorWeb, :html
  use Gettext, backend: ClienteJugadorWeb.Gettext


  alias Phoenix.LiveView.JS

  embed_templates "layouts/*"

  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current scope"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="flex min-h-screen bg-base-200">
      <%!-- Sidebar fijo --%>
      <aside class="hidden lg:flex flex-col w-64 bg-base-100 border-r border-base-300 shadow-lg fixed top-0 left-0 h-full z-40">
        <div class="px-6 py-6 border-b border-base-300">
          <a href={~p"/"} class="flex items-center gap-3">
            <div class="w-10 h-10 rounded-xl bg-gradient-to-br from-success to-info flex items-center justify-center">
              <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 5v2m0 4v2m0 4v2M5 5a2 2 0 00-2 2v3a2 2 0 110 4v3a2 2 0 002 2h14a2 2 0 002-2v-3a2 2 0 110-4V7a2 2 0 00-2-2H5z" />
              </svg>
            </div>
            <div>
              <h1 class="text-lg font-bold tracking-tight text-base-content">HoySiCoronamos S.A.</h1>
              <p class="text-xs text-base-content/50 font-medium">Lotería</p>
            </div>
          </a>
        </div>

        <nav class="flex-1 px-4 py-6 space-y-1 overflow-y-auto">
          <a href={~p"/"} class="flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium text-base-content/80 hover:bg-success/10 hover:text-success transition-all duration-200">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" /></svg>
            Sorteos
          </a>

          <a href={~p"/mis-boletos"} class="flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium text-base-content/80 hover:bg-success/10 hover:text-success transition-all duration-200">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 5v2m0 4v2m0 4v2M5 5a2 2 0 00-2 2v3a2 2 0 110 4v3a2 2 0 002 2h14a2 2 0 002-2v-3a2 2 0 110-4V7a2 2 0 00-2-2H5z" /></svg>
            Mis Boletos
          </a>

          <a href={~p"/historial"} class="flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium text-base-content/80 hover:bg-success/10 hover:text-success transition-all duration-200">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
            Historial
          </a>

          <div class="pt-4 pb-2">
            <p class="px-4 text-xs font-semibold uppercase tracking-wider text-base-content/40">Cuenta</p>
          </div>

          <a href={~p"/balance"} class="flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium text-base-content/80 hover:bg-success/10 hover:text-success transition-all duration-200">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
            Balance
          </a>

          <a href={~p"/recargar"} class="flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium text-base-content/80 hover:bg-success/10 hover:text-success transition-all duration-200">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 9V7a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2m2 4h10a2 2 0 002-2v-6a2 2 0 00-2-2H9a2 2 0 00-2 2v6a2 2 0 002 2zm7-5a2 2 0 11-4 0 2 2 0 014 0z" /></svg>
            Recargar
          </a>
        </nav>

        <div class="px-4 py-4 border-t border-base-300">
          <a href={~p"/logout"} class="flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium text-error/80 hover:bg-error/10 hover:text-error transition-all duration-200">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" /></svg>
            Cerrar Sesión
          </a>
        </div>
      </aside>

      <%!-- Drawer móvil --%>
      <div class="lg:hidden">
        <input id="jugador-drawer" type="checkbox" class="hidden peer" />
        <label for="jugador-drawer" class="fixed top-4 left-4 z-50 btn btn-circle btn-ghost bg-base-100 shadow-lg peer-checked:hidden">
          <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" /></svg>
        </label>

        <div class="fixed inset-0 z-50 hidden peer-checked:flex">
          <label for="jugador-drawer" class="absolute inset-0 bg-black/50"></label>
          <aside class="relative w-64 bg-base-100 shadow-2xl flex flex-col h-full z-10">
            <div class="px-6 py-6 border-b border-base-300 flex items-center justify-between">
              <span class="text-lg font-bold">HoySiCoronamos S.A.</span>
              <label for="jugador-drawer" class="btn btn-ghost btn-sm btn-circle">✕</label>
            </div>
            <nav class="flex-1 px-4 py-6 space-y-1">
              <a href={~p"/"} class="flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium hover:bg-success/10">Sorteos</a>
              <a href={~p"/mis-boletos"} class="flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium hover:bg-success/10">Mis Boletos</a>
              <a href={~p"/historial"} class="flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium hover:bg-success/10">Historial</a>
              <a href={~p"/balance"} class="flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium hover:bg-success/10">Balance</a>
              <a href={~p"/recargar"} class="flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium hover:bg-success/10">Recargar</a>
            </nav>
            <div class="px-4 py-4 border-t border-base-300">
              <a href={~p"/logout"} class="flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium text-error">Cerrar Sesión</a>
            </div>
          </aside>
        </div>
      </div>

      <%!-- Contenido principal --%>
      <main class="flex-1 lg:ml-64 min-h-screen">
        <div class="px-6 py-8 lg:px-10 lg:py-10 max-w-7xl mx-auto space-y-6">
          {render_slot(@inner_block)}
        </div>
      </main>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end
end
