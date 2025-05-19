defmodule ChatDistribuido.Cliente do
  @moduledoc """
  Cliente del chat distribuido que maneja la interfaz de línea de comandos.
  """

  def start do
    IO.puts("Iniciando interfaz de cliente...")
    IO.puts("Bienvenido al Chat Distribuido")
    IO.puts("Por favor, ingresa tu nombre de usuario:")
    nombre = IO.gets("") |> String.trim()

    Process.flag(:trap_exit, true)

    case registrar_usuario(nombre) do
      {:ok, _usuario} ->
        mostrar_comandos()
        # Iniciamos el proceso de entrada en un hilo separado
        input_pid = spawn_link(__MODULE__, :input_loop, [self(), nombre])
        # Iniciamos el proceso principal de mensajes
        message_loop(nombre, input_pid)
      {:error, mensaje} ->
        IO.puts("Error: #{mensaje}")
    end
  end

  # Proceso público para manejar la entrada del usuario
  def input_loop(main_pid, nombre) do
    mensaje = IO.gets("")
    if mensaje do
      mensaje = String.trim(mensaje)
      send(main_pid, {:input, mensaje})
      input_loop(main_pid, nombre)
    end
  end

  defp registrar_usuario(nombre) do
    case ChatDistribuido.Servidor.registrar_usuario(nombre) do
      {:ok, _} = resultado -> resultado
      {:error, _} = error ->
        Process.sleep(1000)
        registrar_usuario(nombre)
      _ ->
        {:error, "Error desconocido al registrar usuario"}
    end
  end

  defp mostrar_comandos do
    IO.puts("\nComandos disponibles:")
    IO.puts("/create nombre_sala - Crear una nueva sala")
    IO.puts("/list - Listar salas disponibles y usuarios conectados")
    IO.puts("/join nombre_sala - Unirse a una sala")
    IO.puts("/history nombre_sala - Ver historial de mensajes de una sala específica")
    IO.puts("/exit - Salir del chat")
    IO.puts("Cualquier otro texto será enviado como mensaje a la sala actual\n")
  end

  defp mostrar_prompt(sala_actual) do
    if sala_actual do
      IO.write("\r[#{sala_actual}]> ")
    else
      IO.write("\r> ")
    end
    IO.write("") # Forzar el flush del buffer
  end

  defp guardar_historial_en_archivo(nombre_sala, mensajes) do
    nombre_archivo = "historial_#{nombre_sala}_#{DateTime.utc_now() |> DateTime.to_unix()}.txt"
    contenido = mensajes
    |> Enum.sort_by(& &1.timestamp)
    |> Enum.map(&ChatDistribuido.Mensaje.formatear(&1))
    |> Enum.join("\n")

    case File.write(nombre_archivo, contenido) do
      :ok ->
        IO.puts("\nHistorial guardado en: #{nombre_archivo}")
      {:error, reason} ->
        IO.puts("\nError al guardar el archivo: #{reason}")
    end
  end

  defp mostrar_historial(nombre_sala, mensajes) do
    IO.puts("\nHistorial de mensajes de la sala '#{nombre_sala}':")
    if Enum.empty?(mensajes) do
      IO.puts("No hay mensajes en esta sala.")
    else
      mensajes
      |> Enum.sort_by(& &1.timestamp)
      |> Enum.each(&IO.puts(ChatDistribuido.Mensaje.formatear(&1)))

      IO.puts("\n¿Deseas guardar el historial en un archivo? (s/n)")
      case IO.gets("") |> String.trim() |> String.downcase() do
        "s" -> guardar_historial_en_archivo(nombre_sala, mensajes)
        _ -> IO.puts("No se guardó el historial.")
      end
    end
    IO.puts("")
  end

  defp message_loop(nombre, input_pid, sala_actual \\ nil) do
    mostrar_prompt(sala_actual)

    receive do
      {:mensaje, mensaje} ->
        # Limpiamos la línea actual
        IO.write("\r\e[K")
        # Mostramos el mensaje
        IO.puts(mensaje)
        # Restauramos el prompt
        mostrar_prompt(sala_actual)
        message_loop(nombre, input_pid, sala_actual)

      {:input, mensaje} ->
        case mensaje do
          "/create " <> nombre_sala ->
            case ChatDistribuido.Servidor.crear_sala(nombre_sala) do
              {:ok, _} -> IO.puts("\nSala '#{nombre_sala}' creada exitosamente")
              {:error, mensaje} -> IO.puts("\nError: #{mensaje}")
            end
            message_loop(nombre, input_pid, sala_actual)

          "/list" ->
            {salas, usuarios} = ChatDistribuido.Servidor.listar_salas_y_usuarios()
            IO.puts("\nSalas disponibles:")
            Enum.each(salas, &IO.puts("- #{&1}"))
            IO.puts("\nUsuarios conectados:")
            Enum.each(usuarios, &IO.puts("- #{&1}"))
            IO.puts("")
            message_loop(nombre, input_pid, sala_actual)

          "/join " <> nombre_sala ->
            case ChatDistribuido.Servidor.unirse_sala(nombre, nombre_sala) do
              :ok ->
                IO.puts("\nTe has unido a la sala '#{nombre_sala}'")
                message_loop(nombre, input_pid, nombre_sala)
              {:error, mensaje} ->
                IO.puts("\nError: #{mensaje}")
                if mensaje == "Usuario no encontrado" do
                  case registrar_usuario(nombre) do
                    {:ok, _} ->
                      case ChatDistribuido.Servidor.unirse_sala(nombre, nombre_sala) do
                        :ok ->
                          IO.puts("\nTe has unido a la sala '#{nombre_sala}'")
                          message_loop(nombre, input_pid, nombre_sala)
                        {:error, nuevo_mensaje} ->
                          IO.puts("\nError: #{nuevo_mensaje}")
                          message_loop(nombre, input_pid, sala_actual)
                      end
                    {:error, error_mensaje} ->
                      IO.puts("\nError al reconectar: #{error_mensaje}")
                      message_loop(nombre, input_pid, sala_actual)
                  end
                else
                  message_loop(nombre, input_pid, sala_actual)
                end
            end

          "/history " <> nombre_sala ->
            case ChatDistribuido.Servidor.obtener_historial(nombre_sala) do
              {:ok, mensajes} ->
                mostrar_historial(nombre_sala, mensajes)
              {:error, mensaje} ->
                IO.puts("\nError: #{mensaje}")
            end
            message_loop(nombre, input_pid, sala_actual)

          "/history" when not is_nil(sala_actual) ->
            case ChatDistribuido.Servidor.obtener_historial(sala_actual) do
              {:ok, mensajes} ->
                mostrar_historial(sala_actual, mensajes)
              {:error, mensaje} ->
                IO.puts("\nError: #{mensaje}")
            end
            message_loop(nombre, input_pid, sala_actual)

          "/exit" when not is_nil(sala_actual) ->
            ChatDistribuido.Servidor.salir_sala(nombre, sala_actual)
            IO.puts("\nHas salido de la sala '#{sala_actual}'")
            message_loop(nombre, input_pid, nil)

          "/exit" when is_nil(sala_actual) ->
            IO.puts("\n¡Hasta luego!")
            Process.exit(input_pid, :normal)
            :ok

          mensaje when not is_nil(sala_actual) ->
            ChatDistribuido.Servidor.enviar_mensaje(nombre, sala_actual, mensaje)
            message_loop(nombre, input_pid, sala_actual)

          _ ->
            IO.puts("\nDebes unirte a una sala primero con /join nombre_sala")
            message_loop(nombre, input_pid, sala_actual)
        end
    end
  end
end
