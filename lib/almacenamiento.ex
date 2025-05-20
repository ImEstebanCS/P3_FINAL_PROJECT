defmodule ChatDistribuido.Almacenamiento do
  # Módulo que maneja el almacenamiento global del chat.
  use GenServer

  # Inicia el proceso de almacenamiento global
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  # Crea una nueva sala de chat
  def crear_sala(nombre) do
    GenServer.call(__MODULE__, {:crear_sala, nombre})
  end

  # Devuelve la lista de nombres de todas las salas
  def obtener_salas() do
    GenServer.call(__MODULE__, :obtener_salas)
  end

  @impl true
  # Inicializa el estado con un mapa vacío de salas
  def init(_) do
    {:ok, %{salas: {}}}
  end

  @impl true
  # Maneja la creación de una sala: si no existe, la crea y la registra
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
  # Devuelve la lista de nombres de salas almacenadas
  def handle_call(:obtener_salas, _from, estado) do
    {:reply, Map.keys(estado.salas), estado}
  end
end
