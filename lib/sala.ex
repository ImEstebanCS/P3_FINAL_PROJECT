defmodule ChatDistribuido.Sala do
  @moduledoc """
  Módulo que representa una sala de chat.
  """

  use GenServer
  alias ChatDistribuido.{Usuario, Mensaje}

  defstruct [:nombre, :usuarios, :mensajes]

  # API Cliente
  def start_link(nombre) do
    GenServer.start_link(__MODULE__, nombre, name: via_tuple(nombre))
  end

  def unirse(nombre_sala, usuario) do
    GenServer.call(via_tuple(nombre_sala), {:unirse, usuario})
  end

  def salir(nombre_sala, usuario) do
    GenServer.call(via_tuple(nombre_sala), {:salir, usuario})
  end

  def enviar_mensaje(nombre_sala, mensaje) do
    GenServer.cast(via_tuple(nombre_sala), {:mensaje, mensaje})
  end

  def obtener_usuarios(nombre_sala) do
    GenServer.call(via_tuple(nombre_sala), :obtener_usuarios)
  end

  def obtener_mensajes(nombre_sala) do
    GenServer.call(via_tuple(nombre_sala), :obtener_mensajes)
  end

  # Callbacks del GenServer
  @impl true
  def init(nombre) do
    {:ok, %__MODULE__{nombre: nombre}}
  end

  @impl true
  def handle_call({:unirse, usuario}, _from, estado) do
    if usuario in estado.usuarios do
      {:reply, {:error, :ya_existe}, estado}
    else
      nuevo_estado = %{estado | usuarios: [usuario | estado.usuarios]}
      broadcast_usuarios(nuevo_estado)
      {:reply, :ok, nuevo_estado}
    end
  end

  @impl true
  def handle_call({:salir, usuario}, _from, estado) do
    nuevo_estado = %{estado | usuarios: Enum.reject(estado.usuarios, &(&1.nombre == usuario.nombre))}
    broadcast_usuarios(nuevo_estado)
    {:reply, :ok, nuevo_estado}
  end

  @impl true
  def handle_call(:obtener_usuarios, _from, estado) do
    {:reply, estado.usuarios, estado}
  end

  @impl true
  def handle_call(:obtener_mensajes, _from, estado) do
    {:reply, Enum.reverse(estado.mensajes), estado}
  end

  @impl true
  def handle_cast({:mensaje, mensaje}, estado) do
    nuevo_estado = %{estado | mensajes: [mensaje | estado.mensajes]}
    broadcast_mensaje(mensaje, nuevo_estado)
    {:noreply, nuevo_estado}
  end

  # Funciones privadas
  defp via_tuple(nombre_sala) do
    {:via, Registry, {ChatDistribuido.SalaRegistry, nombre_sala}}
  end

  defp broadcast_mensaje(mensaje, estado) do
    Enum.each(estado.usuarios, fn {_nombre, usuario} ->
      send(usuario.pid, {:mensaje, mensaje})
    end)
  end

  defp broadcast_usuarios(estado) do
    usuarios = Enum.reverse(estado.usuarios)
    Enum.each(estado.usuarios, fn {_nombre, usuario} ->
      send(usuario.pid, {:usuarios_actualizados, usuarios})
    end)
  end

  @doc """
  Crea una nueva sala de chat.
  """
  def nueva(nombre) do
    %__MODULE__{
      nombre: nombre,
      usuarios: [],
      mensajes: []
    }
  end

  @doc """
  Agrega un usuario a la sala.
  """
  def agregar_usuario(sala, usuario) do
    if usuario in sala.usuarios do
      {:error, "Usuario ya está en la sala"}
    else
      {:ok, %{sala | usuarios: [usuario | sala.usuarios]}}
    end
  end

  @doc """
  Elimina un usuario de la sala.
  """
  def eliminar_usuario(sala, usuario) do
    %{sala | usuarios: Enum.reject(sala.usuarios, &(&1.nombre == usuario.nombre))}
  end

  @doc """
  Agrega un mensaje al historial de la sala.
  """
  def agregar_mensaje(sala, mensaje) do
    %{sala | mensajes: [mensaje | sala.mensajes]}
  end

  @doc """
  Obtiene el historial de mensajes de la sala.
  """
  def obtener_historial(sala) do
    Enum.reverse(sala.mensajes)
  end

  @doc """
  Verifica si un usuario está en la sala.
  """
  def usuario_en_sala?(sala, nombre_usuario) do
    Enum.any?(sala.usuarios, fn usuario -> usuario.nombre == nombre_usuario end)
  end
end
