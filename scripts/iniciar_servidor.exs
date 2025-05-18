# scripts/servidor.exs

# Cargar todos los archivos necesarios
Code.require_file("lib/usuario.ex")
Code.require_file("lib/mensaje.ex")
Code.require_file("lib/sala.ex")
Code.require_file("lib/servidor.ex")
Code.require_file("lib/cliente.ex")
Code.require_file("lib/chat_distribuido.ex")

# Iniciar la aplicación Mix
Mix.start()

# Iniciar el servidor
ChatDistribuido.iniciar_servidor()

# Mantener el script ejecutándose
IO.puts("\n===== SERVIDOR DE CHAT =====")
IO.puts("Servidor ejecutándose en: #{Node.self()}")
IO.puts("Presiona Ctrl+C dos veces para detener")
IO.puts("=============================\n")

:timer.sleep(:infinity)
