defmodule ChatDistribuido.Aplicacion do
  # Módulo de arranque y supervisión para el servidor del chat distribuido.
  use Application

  # Inicia el supervisor principal del servidor
  @impl true
  def start(_type, _args) do
    children = [
      {ChatDistribuido.Servidor, []}
    ]

    opts = [strategy: :one_for_one, name: ChatDistribuido.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
