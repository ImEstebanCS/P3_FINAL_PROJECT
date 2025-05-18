defmodule ChatDistribuido.Cliente do
  @moduledoc """
  Cliente del chat distribuido que maneja la interfaz de línea de comandos.
  """

  def start do
    IO.puts("Bienvenido al Chat Distribuido")
    IO.puts("Por favor, ingresa tu nombre de usuario:")
    nombre = IO.gets("") |> String.trim()

    Process.flag(:trap_exit, true)

    case registrar_usuario(nombre) do
      {:ok, _usuario} ->
        mostrar_comandos()
        loop(nombre)
      {:error, mensaje} ->
        IO.puts("Error: #{mensaje}")
    end
  end

  defp registrar_usuario(nombre) do
    case ChatDistribuido.Servidor.registrar_usuario(nombre) do
      {:ok, _} = resultado ->
        resultado
      {:error, _} = error ->
        # Esperar un momento y reintentar
        Process.sleep(1000)
        registrar_usuario(nombre)
      _ ->
        {:error, "Error desconocido al registrar usuario"}
    end
  end

  defp mostrar_comandos do
    IO.puts("\nComandos disponibles:")
    IO.puts("/create nombre_sala - Crear una nueva sala")
    IO.puts("/list - Listar salas disponibles")
    IO.puts("/join nombre_sala - Unirse a una sala")
    IO.puts("/history nombre_sala - Ver historial de la sala")
    IO.puts("/exit - Salir del chat")
    IO.puts("Cualquier otro texto será enviado como mensaje a la sala actual\n")
  end

  defp loop(nombre, sala_actual \\ nil) do
    # Asegurarse de que el proceso actual puede recibir mensajes
    Process.flag(:trap_exit, true)

    receive do
      {:mensaje, mensaje} ->
        IO.puts("\n#{mensaje}")
        loop(nombre, sala_actual)
    after
      0 ->
        mensaje = IO.gets("") |> String.trim()

        case mensaje do
          "/create " <> nombre_sala ->
            case ChatDistribuido.Servidor.crear_sala(nombre_sala) do
              {:ok, _} -> IO.puts("Sala '#{nombre_sala}' creada exitosamente")
              {:error, mensaje} -> IO.puts("Error: #{mensaje}")
            end
            loop(nombre, sala_actual)

          "/list" ->
            salas = ChatDistribuido.Servidor.listar_salas()
            IO.puts("\nSalas disponibles:")
            Enum.each(salas, &IO.puts("- #{&1}"))
            IO.puts("")
            loop(nombre, sala_actual)

          "/join " <> nombre_sala ->
            case ChatDistribuido.Servidor.unirse_sala(nombre, nombre_sala) do
              :ok ->
                IO.puts("Te has unido a la sala '#{nombre_sala}'")
                loop(nombre, nombre_sala)
              {:error, mensaje} ->
                IO.puts("Error: #{mensaje}")
                # Reintentar registro si el error es de usuario no encontrado
                if mensaje == "Usuario no encontrado" do
                  case registrar_usuario(nombre) do
                    {:ok, _} ->
                      case ChatDistribuido.Servidor.unirse_sala(nombre, nombre_sala) do
                        :ok ->
                          IO.puts("Te has unido a la sala '#{nombre_sala}'")
                          loop(nombre, nombre_sala)
                        {:error, nuevo_mensaje} ->
                          IO.puts("Error: #{nuevo_mensaje}")
                          loop(nombre, sala_actual)
                      end
                    {:error, error_mensaje} ->
                      IO.puts("Error al reconectar: #{error_mensaje}")
                      loop(nombre, sala_actual)
                  end
                else
                  loop(nombre, sala_actual)
                end
            end

          "/history" when not is_nil(sala_actual) ->
            case ChatDistribuido.Servidor.obtener_historial(sala_actual) do
              {:ok, mensajes} ->
                IO.puts("\nHistorial de mensajes:")
                Enum.each(mensajes, &IO.puts(&1))
                IO.puts("")
              {:error, mensaje} ->
                IO.puts("Error: #{mensaje}")
            end
            loop(nombre, sala_actual)

          "/exit" when not is_nil(sala_actual) ->
            ChatDistribuido.Servidor.salir_sala(nombre, sala_actual)
            IO.puts("Has salido de la sala '#{sala_actual}'")
            loop(nombre, nil)

          "/exit" when is_nil(sala_actual) ->
            IO.puts("¡Hasta luego!")
            :ok

          mensaje when not is_nil(sala_actual) ->
            ChatDistribuido.Servidor.enviar_mensaje(nombre, sala_actual, mensaje)
            loop(nombre, sala_actual)

          _ ->
            IO.puts("Debes unirte a una sala primero con /join nombre_sala")
            loop(nombre, sala_actual)
        end
    end
  end
end
