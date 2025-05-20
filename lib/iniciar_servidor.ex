defmodule ChatDistribuido.IniciarServidor do
  @moduledoc """
  Módulo para iniciar el servidor del chat distribuido.
  """

  def start do
    # Configurar el nombre del nodo con la IP específica
    nombre_nodo = :"servidor@ 192.168.1.4"

    # Iniciar el nodo distribuido
    Node.start(nombre_nodo)

    # Establecer la cookie para autenticación entre nodos
    Node.set_cookie(:chat_secreto)

    IO.puts("Servidor iniciado en #{nombre_nodo}")
    IO.puts("Cookie establecida: #{Node.get_cookie()}")
    IO.puts("\nIniciando interfaz de cliente...")

    # Iniciar el cliente en el mismo nodo del servidor
    ChatDistribuido.Cliente.start()
  end
end
