defmodule ChatDistribuido.Sala do
  @moduledoc """
  Módulo que representa una sala de chat.
  """

  use GenServer
  alias ChatDistribuido.{Usuario, Mensaje}

  defstruct [:nombre, :usuarios, :mensajes]

  # Inicia una nueva sala y la registra en el sistema
  def start_link(nombre) do
    GenServer.start_link(__MODULE__, nombre, name: via_tuple(nombre))
  end

  # Permite a un usuario unirse a la sala
  def unirse(nombre_sala, usuario) do
    GenServer.call(via_tuple(nombre_sala), {:unirse, usuario})
  end

  # Permite a un usuario salir de la sala
  def salir(nombre_sala, usuario) do
    GenServer.call(via_tuple(nombre_sala), {:salir, usuario})
  end

  # Envía un mensaje a todos los usuarios de la sala
  def enviar_mensaje(nombre_sala, mensaje) do
    GenServer.cast(via_tuple(nombre_sala), {:mensaje, mensaje})
  end

  # Obtiene la lista de usuarios en la sala
  def obtener_usuarios(nombre_sala) do
    GenServer.call(via_tuple(nombre_sala), :obtener_usuarios)
  end

  # Obtiene el historial de mensajes de la sala
  def obtener_mensajes(nombre_sala) do
    GenServer.call(via_tuple(nombre_sala), :obtener_mensajes)
  end

  # Inicializa una nueva sala con el nombre especificado
  @impl true
  def init(nombre) do
    {:ok, %__MODULE__{nombre: nombre}}
  end

  # Maneja la unión de usuarios a la sala
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

  # Maneja la salida de usuarios de la sala
  @impl true
  def handle_call({:salir, usuario}, _from, estado) do
    nuevo_estado = %{estado | usuarios: Enum.reject(estado.usuarios, &(&1.nombre == usuario.nombre))}
    broadcast_usuarios(nuevo_estado)
    {:reply, :ok, nuevo_estado}
  end

  # Devuelve la lista de usuarios de la sala
  @impl true
  def handle_call(:obtener_usuarios, _from, estado) do
    {:reply, estado.usuarios, estado}
  end

  # Devuelve el historial de mensajes de la sala
  @impl true
  def handle_call(:obtener_mensajes, _from, estado) do
    {:reply, Enum.reverse(estado.mensajes), estado}
  end

  # Procesa el envío de mensajes en la sala
  @impl true
  def handle_cast({:mensaje, mensaje}, estado) do
    nuevo_estado = %{estado | mensajes: [mensaje | estado.mensajes]}
    broadcast_mensaje(mensaje, nuevo_estado)
    {:noreply, nuevo_estado}
  end

  # Obtiene la referencia de la sala en el registro
  defp via_tuple(nombre_sala) do
    {:via, Registry, {ChatDistribuido.SalaRegistry, nombre_sala}}
  end

  # Envía un mensaje a todos los usuarios de la sala
  defp broadcast_mensaje(mensaje, estado) do
    Enum.each(estado.usuarios, fn {_nombre, usuario} ->
      send(usuario.pid, {:mensaje, mensaje})
    end)
  end

  # Notifica a los usuarios sobre cambios en la lista de usuarios
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
