# lib/chat_distribuido.ex
defmodule ChatDistribuido do
  alias ChatDistribuido.{Cliente, Servidor}

  # Inicia el servidor de chat
  def iniciar_servidor do
    ChatDistribuido.Servidor.iniciar()
  end

  # Inicia un cliente de chat con el nombre de usuario especificado
  def iniciar_cliente(nombre_usuario) do
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

  # Inicia la interfaz interactiva del cliente
  defp iniciar_interfaz_cliente(pid, nombre_usuario) do
    IO.puts("\n¡Bienvenido al chat, #{nombre_usuario}!")
    mostrar_ayuda()
    bucle_interfaz(pid)
  end

  # Bucle principal de la interfaz de comandos del cliente
  defp bucle_interfaz(pid) do
    IO.write("\nComando> ")
    comando = IO.gets("") |> String.trim()

    case procesar_comando(comando, pid) do
      :continuar -> bucle_interfaz(pid)
      :salir -> IO.puts("\n¡Hasta luego!")
    end
  end

  # Procesa los comandos ingresados por el usuario
  defp procesar_comando("/help", _pid) do
    mostrar_ayuda()
    :continuar
  end

  # Lista las salas disponibles
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

  # Crea una nueva sala
  defp procesar_comando("/create " <> nombre_sala, _pid) do
    case GenServer.call({:global, ChatDistribuido.Servidor}, {:crear_sala, nombre_sala}) do
      :ok -> IO.puts("Sala '#{nombre_sala}' creada exitosamente")
      {:error, :ya_existe} -> IO.puts("Error: La sala ya existe")
    end
    :continuar
  end

  # Unirse a una sala existente
  defp procesar_comando("/join " <> nombre_sala, pid) do
    case Cliente.unirse_sala(pid, nombre_sala) do
      :ok -> IO.puts("Te has unido a la sala '#{nombre_sala}'")
      {:error, :ya_existe} -> IO.puts("Error: Ya estás en esta sala")
    end
    :continuar
  end

  # Salir del chat
  defp procesar_comando("/exit", pid) do
    Cliente.salir_sala(pid)
    :salir
  end

  # Enviar un mensaje a la sala actual
  defp procesar_comando(mensaje, pid) do
    Cliente.enviar_mensaje(pid, mensaje)
    :continuar
  end

  # Muestra la ayuda de comandos disponibles
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
