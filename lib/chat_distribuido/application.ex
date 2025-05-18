defmodule ChatDistribuido.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    # Asegurarse de que epmd está corriendo
    :os.cmd('epmd -daemon')

    children = [
      # Agregar el Registry para las salas
      {Registry, keys: :unique, name: ChatDistribuido.SalaRegistry},
      # Supervisor para el servidor
      {ChatDistribuido.Servidor, []}
    ]

    opts = [strategy: :one_for_one, name: ChatDistribuido.Supervisor]

    # Iniciar el supervisor con reinicio automático
    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        {:ok, pid}
      {:error, _} ->
        # Si falla, esperar un momento y reintentar
        Process.sleep(1000)
        Supervisor.start_link(children, opts)
    end
  end

  def stop(_state) do
    :ok
  end
end
