defmodule ChatDistribuido.Almacenamiento do
  @moduledoc """
  Módulo que maneja el almacenamiento global del chat.
  """

  use GenServer

  # API Cliente
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def crear_sala(nombre) do
    GenServer.call(__MODULE__, {:crear_sala, nombre})
  end

  def obtener_salas() do
    GenServer.call(__MODULE__, :obtener_salas)
  end

  # Callbacks del GenServer
  @impl true
  def init(_) do
    {:ok, %{salas: %{}}}
  end

  @impl true
  def handle_call({:crear_sala, nombre}, _from, estado) do
    case Map.has_key?(estado.salas, nombre) do
      true ->
        {:reply, {:error, :ya_existe}, estado}
      false ->
        {:ok, _pid} = ChatDistribuido.Sala.start_link(nombre)
        nuevo_estado = put_in(estado.salas[nombre], true)
        {:reply, :ok, nuevo_estado}
    end
  end

  @impl true
  def handle_call(:obtener_salas, _from, estado) do
    {:reply, Map.keys(estado.salas), estado}
  end
end
