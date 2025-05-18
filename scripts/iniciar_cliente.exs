# scripts/cliente.exs

# Cargar todos los archivos necesarios
Code.require_file("lib/usuario.ex")
Code.require_file("lib/mensaje.ex")
Code.require_file("lib/sala.ex")
Code.require_file("lib/almacenamiento.ex")
Code.require_file("lib/servidor.ex")
Code.require_file("lib/cliente.ex")
Code.require_file("lib/aplicacion.ex")
Code.require_file("lib/chat_distribuido.ex")

# Obtener el nombre de usuario de los argumentos de línea de comandos
[nombre_usuario | _] = System.argv()

if nombre_usuario do
  # Iniciar el cliente con el nombre de usuario proporcionado
  ChatDistribuido.iniciar_cliente(nombre_usuario)
else
  IO.puts("Error: Debes proporcionar un nombre de usuario.")
  IO.puts("Uso: elixir scripts/cliente.exs nombre_usuario")
end
