defmodule ChatDistribuido.Servidor do
  @moduledoc """
  Servidor principal del chat distribuido.
  """
  use GenServer
  alias ChatDistribuido.{Usuario, Sala, Mensaje}

  # Cliente API
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: {:global, __MODULE__})
  end

  def registrar_usuario(nombre) do
    GenServer.call({:global, __MODULE__}, {:registrar_usuario, nombre, self()})
  end

  def crear_sala(nombre_sala) do
    GenServer.call({:global, __MODULE__}, {:crear_sala, nombre_sala})
  end

  def unirse_sala(nombre_usuario, nombre_sala) do
    GenServer.call({:global, __MODULE__}, {:unirse_sala, nombre_usuario, nombre_sala})
  end

  def enviar_mensaje(nombre_usuario, nombre_sala, contenido) do
    GenServer.cast({:global, __MODULE__}, {:mensaje, nombre_usuario, nombre_sala, contenido})
  end

  def listar_salas do
    GenServer.call({:global, __MODULE__}, :listar_salas)
  end

  def obtener_historial(nombre_sala) do
    GenServer.call({:global, __MODULE__}, {:historial, nombre_sala})
  end

  def salir_sala(nombre_usuario, nombre_sala) do
    GenServer.call({:global, __MODULE__}, {:salir_sala, nombre_usuario, nombre_sala})
  end

  # Callbacks del Servidor
  @impl true
  def init(_opts) do
    {:ok, %{usuarios: %{}, salas: %{}}}
  end

  @impl true
  def handle_call({:registrar_usuario, nombre, pid}, _from, estado) do
    if Map.has_key?(estado.usuarios, nombre) do
      {:reply, {:error, "Usuario ya existe"}, estado}
    else
      usuario = Usuario.nuevo(nombre, pid)
      nuevo_estado = %{estado | usuarios: Map.put(estado.usuarios, nombre, usuario)}
      {:reply, {:ok, usuario}, nuevo_estado}
    end
  end

  @impl true
  def handle_call({:crear_sala, nombre_sala}, _from, estado) do
    if Map.has_key?(estado.salas, nombre_sala) do
      {:reply, {:error, "Sala ya existe"}, estado}
    else
      sala = Sala.nueva(nombre_sala)
      nuevo_estado = %{estado | salas: Map.put(estado.salas, nombre_sala, sala)}
      {:reply, {:ok, sala}, nuevo_estado}
    end
  end

  @impl true
  def handle_call({:unirse_sala, nombre_usuario, nombre_sala}, _from, estado) do
    with {:ok, usuario} <- obtener_usuario(estado, nombre_usuario),
         {:ok, sala} <- obtener_sala(estado, nombre_sala),
         {:ok, sala_actualizada} <- Sala.agregar_usuario(sala, usuario) do
      nuevo_estado = %{estado | salas: Map.put(estado.salas, nombre_sala, sala_actualizada)}
      broadcast_mensaje(sala_actualizada, "#{nombre_usuario} se ha unido a la sala")
      {:reply, :ok, nuevo_estado}
    else
      error -> {:reply, error, estado}
    end
  end

  @impl true
  def handle_call(:listar_salas, _from, estado) do
    salas = Map.keys(estado.salas)
    {:reply, salas, estado}
  end

  @impl true
  def handle_call({:historial, nombre_sala}, _from, estado) do
    case obtener_sala(estado, nombre_sala) do
      {:ok, sala} -> {:reply, {:ok, Sala.obtener_historial(sala)}, estado}
      error -> {:reply, error, estado}
    end
  end

  @impl true
  def handle_call({:salir_sala, nombre_usuario, nombre_sala}, _from, estado) do
    with {:ok, usuario} <- obtener_usuario(estado, nombre_usuario),
         {:ok, sala} <- obtener_sala(estado, nombre_sala) do
      sala_actualizada = Sala.eliminar_usuario(sala, usuario)
      nuevo_estado = %{estado | salas: Map.put(estado.salas, nombre_sala, sala_actualizada)}
      broadcast_mensaje(sala_actualizada, "#{nombre_usuario} ha salido de la sala")
      {:reply, :ok, nuevo_estado}
    else
      error -> {:reply, error, estado}
    end
  end

  @impl true
  def handle_cast({:mensaje, nombre_usuario, nombre_sala, contenido}, estado) do
    with {:ok, usuario} <- obtener_usuario(estado, nombre_usuario),
         {:ok, sala} <- obtener_sala(estado, nombre_sala) do
      mensaje = Mensaje.nuevo(contenido, usuario, nombre_sala)
      sala_actualizada = Sala.agregar_mensaje(sala, mensaje)
      nuevo_estado = %{estado | salas: Map.put(estado.salas, nombre_sala, sala_actualizada)}
      broadcast_mensaje(sala_actualizada, Mensaje.formatear(mensaje))
      {:noreply, nuevo_estado}
    else
      _error -> {:noreply, estado}
    end
  end

  # Funciones privadas
  defp obtener_usuario(estado, nombre) do
    case Map.fetch(estado.usuarios, nombre) do
      {:ok, usuario} -> {:ok, usuario}
      :error -> {:error, "Usuario no encontrado"}
    end
  end

  defp obtener_sala(estado, nombre) do
    case Map.fetch(estado.salas, nombre) do
      {:ok, sala} -> {:ok, sala}
      :error -> {:error, "Sala no encontrada"}
    end
  end

  defp broadcast_mensaje(sala, mensaje) do
    Enum.each(sala.usuarios, fn usuario ->
      send(usuario.pid, {:mensaje, mensaje})
    end)
  end
end
