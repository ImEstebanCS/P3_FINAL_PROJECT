defmodule ChatDistribuido.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    children = [
      {ChatDistribuido.Servidor, []}
    ]

    opts = [strategy: :one_for_one, name: ChatDistribuido.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
