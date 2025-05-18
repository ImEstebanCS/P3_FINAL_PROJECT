# lib/chat_distribuido.ex
defmodule ChatDistribuido do
  @moduledoc """
  Módulo principal que coordina el sistema de chat distribuido.
  """

  alias ChatDistribuido.{Cliente, Servidor}

  @doc """
  Inicia el servidor de chat.
  """
  def iniciar_servidor do
    ChatDistribuido.Servidor.iniciar()
  end

  @doc """
  Inicia un cliente de chat con el nombre de usuario especificado.
  """
  def iniciar_cliente(nombre_usuario) do
    # Conectar al nodo servidor
    Node.start(:"cliente_#{nombre_usuario}@192.168.1.4")
    Node.set_cookie(:micookie)
    Node.connect(:"chat_server@192.168.1.4")

    case Cliente.start_link(nombre_usuario) do
      {:ok, pid} ->
        iniciar_interfaz_cliente(pid, nombre_usuario)
      {:error, reason} ->
        IO.puts("Error al iniciar cliente: #{inspect(reason)}")
    end
  end

  # Funciones privadas
  defp iniciar_interfaz_cliente(pid, nombre_usuario) do
    IO.puts("\n¡Bienvenido al chat, #{nombre_usuario}!")
    mostrar_ayuda()
    bucle_interfaz(pid)
  end

  defp bucle_interfaz(pid) do
    IO.write("\nComando> ")
    comando = IO.gets("") |> String.trim()

    case procesar_comando(comando, pid) do
      :continuar -> bucle_interfaz(pid)
      :salir -> IO.puts("\n¡Hasta luego!")
    end
  end

  defp procesar_comando("/help", _pid) do
    mostrar_ayuda()
    :continuar
  end

  defp procesar_comando("/list", _pid) do
    case GenServer.call({:global, ChatDistribuido.Servidor}, :obtener_salas) do
      [] ->
        IO.puts("No hay salas disponibles")
      salas ->
        IO.puts("\nSalas disponibles:")
        Enum.each(salas, &IO.puts("  - #{&1}"))
    end
    :continuar
  end

  defp procesar_comando("/create " <> nombre_sala, _pid) do
    case GenServer.call({:global, ChatDistribuido.Servidor}, {:crear_sala, nombre_sala}) do
      :ok -> IO.puts("Sala '#{nombre_sala}' creada exitosamente")
      {:error, :ya_existe} -> IO.puts("Error: La sala ya existe")
    end
    :continuar
  end

  defp procesar_comando("/join " <> nombre_sala, pid) do
    case Cliente.unirse_sala(pid, nombre_sala) do
      :ok -> IO.puts("Te has unido a la sala '#{nombre_sala}'")
      {:error, :ya_existe} -> IO.puts("Error: Ya estás en esta sala")
    end
    :continuar
  end

  defp procesar_comando("/exit", pid) do
    Cliente.salir_sala(pid)
    :salir
  end

  defp procesar_comando(mensaje, pid) do
    Cliente.enviar_mensaje(pid, mensaje)
    :continuar
  end

  defp mostrar_ayuda do
    IO.puts("""

    Comandos disponibles:
      /help           - Muestra esta ayuda
      /list          - Lista las salas disponibles
      /create SALA   - Crea una nueva sala
      /join SALA     - Une a una sala existente
      /exit          - Sale del chat

    Para enviar un mensaje, simplemente escríbelo y presiona Enter
    """)
  end
end
