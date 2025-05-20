defmodule ChatDistribuido.Application do
  @moduledoc """
  Módulo de arranque y supervisión de la aplicación principal del chat distribuido.
  """
  use Application

  def start(_type, _args) do
    :os.cmd('epmd -daemon')

    children = [
      {Registry, keys: :unique, name: ChatDistribuido.SalaRegistry},
      {ChatDistribuido.Servidor, []}
    ]

    opts = [strategy: :one_for_one, name: ChatDistribuido.Supervisor]

    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        {:ok, pid}
      {:error, _} ->
        Process.sleep(1000)
        Supervisor.start_link(children, opts)
    end
  end

  def stop(_state) do
    :ok
  end
end
