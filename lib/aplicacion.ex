defmodule ChatDistribuido.Aplicacion do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {ChatDistribuido.Servidor, []}
    ]

    opts = [strategy: :one_for_one, name: ChatDistribuido.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
