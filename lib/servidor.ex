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
    try do
      GenServer.call({:global, __MODULE__}, {:registrar_usuario, nombre, self()})
    catch
      :exit, {:noproc, _} ->
        {:error, "No se pudo conectar con el servidor"}
      :exit, _ ->
        Process.sleep(1000)
        registrar_usuario(nombre)
    end
  end

  def crear_sala(nombre_sala) do
    try do
      GenServer.call({:global, __MODULE__}, {:crear_sala, nombre_sala})
    catch
      :exit, _ -> {:error, "Error al crear la sala"}
    end
  end

  def unirse_sala(nombre_usuario, nombre_sala) do
    try do
      GenServer.call({:global, __MODULE__}, {:unirse_sala, nombre_usuario, nombre_sala})
    catch
      :exit, _ -> {:error, "Error al unirse a la sala"}
    end
  end

  def enviar_mensaje(nombre_usuario, nombre_sala, contenido) do
    try do
      GenServer.cast({:global, __MODULE__}, {:mensaje, nombre_usuario, nombre_sala, contenido})
    catch
      :exit, _ -> {:error, "Error al enviar mensaje"}
    end
  end

  def listar_salas_y_usuarios do
    try do
      GenServer.call({:global, __MODULE__}, :listar_salas_y_usuarios)
    catch
      :exit, _ -> {[], []}
    end
  end

  def obtener_historial(nombre_sala) do
    try do
      GenServer.call({:global, __MODULE__}, {:historial, nombre_sala})
    catch
      :exit, _ -> {:error, "Error al obtener historial"}
    end
  end

  def salir_sala(nombre_usuario, nombre_sala) do
    try do
      GenServer.call({:global, __MODULE__}, {:salir_sala, nombre_usuario, nombre_sala})
    catch
      :exit, _ -> {:error, "Error al salir de la sala"}
    end
  end

  def desconectar_usuario(nombre_usuario) do
    try do
      GenServer.call({:global, __MODULE__}, {:desconectar_usuario, nombre_usuario})
    catch
      :exit, _ -> {:error, "Error al desconectar usuario"}
    end
  end

  # Callbacks del Servidor
  @impl true
  def init(_opts) do
    Process.flag(:trap_exit, true)
    {:ok, %{usuarios: %{}, salas: %{}}}
  end

  @impl true
  def handle_call({:registrar_usuario, nombre, pid}, _from, estado) do
    try do
      Process.monitor(pid)
      if Map.has_key?(estado.usuarios, nombre) do
        usuario_existente = Map.get(estado.usuarios, nombre)
        if usuario_existente.pid != pid do
          # Si el usuario existe pero con un PID diferente, actualizamos su PID
          usuario = Usuario.nuevo(nombre, pid)
          nuevo_estado = %{estado | usuarios: Map.put(estado.usuarios, nombre, usuario)}
          {:reply, {:ok, usuario}, nuevo_estado}
        else
          {:reply, {:ok, usuario_existente}, estado}
        end
      else
        usuario = Usuario.nuevo(nombre, pid)
        nuevo_estado = %{estado | usuarios: Map.put(estado.usuarios, nombre, usuario)}
        {:reply, {:ok, usuario}, nuevo_estado}
      end
    catch
      kind, reason ->
        IO.puts("Error al registrar usuario: #{inspect(reason)}")
        {:reply, {:error, "Error interno del servidor"}, estado}
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, reason}, estado) do
    IO.puts("[DEBUG] handle_info(:DOWN) ejecutado. PID: #{inspect(pid)}, reason: #{inspect(reason)}")
    try do
      # Encontrar el usuario que se desconectó
      {nombre, _usuario} = Enum.find(estado.usuarios, fn {_nombre, usuario} ->
        usuario.pid == pid
      end) || {nil, nil}

      if nombre do
        # Eliminar al usuario de la lista de usuarios conectados
        usuarios_actualizados = Map.delete(estado.usuarios, nombre)

        # Eliminar al usuario de todas las salas
        salas_actualizadas = Map.new(estado.salas, fn {nombre_sala, sala} ->
          if Sala.usuario_en_sala?(sala, nombre) do
            sala_actualizada = Sala.eliminar_usuario(sala, Map.get(estado.usuarios, nombre))
            broadcast_mensaje(sala_actualizada, "#{nombre} se ha desconectado")
            {nombre_sala, sala_actualizada}
          else
            {nombre_sala, sala}
          end
        end)

        # Notificar a otros usuarios sobre la desconexión
        broadcast_sistema("El usuario #{nombre} se ha desconectado")

        {:noreply, %{estado | usuarios: usuarios_actualizados, salas: salas_actualizadas}}
      else
        IO.puts("[DEBUG] No se encontró usuario para el PID desconectado")
        {:noreply, estado}
      end
    catch
      kind, reason ->
        IO.puts("Error al manejar desconexión: #{inspect(reason)}")
        {:noreply, estado}
    end
  end

  @impl true
  def terminate(_reason, _estado) do
    :ok
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
  def handle_call(:listar_salas_y_usuarios, _from, estado) do
    salas = Map.keys(estado.salas)
    usuarios = Map.values(estado.usuarios)
    {:reply, {salas, usuarios}, estado}
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
  def handle_call({:desconectar_usuario, nombre_usuario}, _from, estado) do
    case Map.fetch(estado.usuarios, nombre_usuario) do
      {:ok, usuario} ->
        # Eliminar al usuario de todas las salas
        salas_actualizadas = Map.new(estado.salas, fn {nombre_sala, sala} ->
          if Sala.usuario_en_sala?(sala, nombre_usuario) do
            sala_actualizada = Sala.eliminar_usuario(sala, usuario)
            broadcast_mensaje(sala_actualizada, "#{nombre_usuario} se ha desconectado")
            {nombre_sala, sala_actualizada}
          else
            {nombre_sala, sala}
          end
        end)

        # Eliminar al usuario de la lista de usuarios
        usuarios_actualizados = Map.delete(estado.usuarios, nombre_usuario)

        # Notificar a otros usuarios sobre la desconexión
        broadcast_sistema("El usuario #{nombre_usuario} se ha desconectado")

        {:reply, :ok, %{estado | usuarios: usuarios_actualizados, salas: salas_actualizadas}}
      :error ->
        {:reply, {:error, "Usuario no encontrado"}, estado}
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
      if usuario.pid do
        try do
          # Intentar enviar directamente primero
          send(usuario.pid, {:mensaje, mensaje})
        catch
          _kind, _reason ->
            # Si falla, intentar a través de RPC
            :rpc.call(node(usuario.pid), Process, :send, [usuario.pid, {:mensaje, mensaje}])
        end
      end
    end)
  end

  # Función para enviar mensajes del sistema
  defp broadcast_sistema(mensaje) do
    IO.puts("[SISTEMA] #{mensaje}")
  end
end
