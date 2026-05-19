defmodule ServidorCentral.Application do
  @moduledoc false

  use Application

  alias ServidorCentral.{GestorSorteos, Seeds}

  @impl true
  def start(_type, _args) do
    children = [
      GestorSorteos
    ]

    opts = [strategy: :one_for_one, name: ServidorCentral.Supervisor]
    {:ok, sup} = Supervisor.start_link(children, opts)
    GestorSorteos.preload_desde_disco()

    # Inicializar datos de ejemplo
    Seeds.run()

    {:ok, sup}
  end
end
