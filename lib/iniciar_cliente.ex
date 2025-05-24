defmodule ChatDistribuido.IniciarCliente do
  @moduledoc """
  Módulo para iniciar un cliente del chat distribuido.
  """

  def start do
    # Obtener la IP local del cliente
    {:ok, interfaces} = :inet.getif()
    {ip, _, _} = hd(interfaces)
    ip_string = ip |> Tuple.to_list() |> Enum.join(".")

    # Configurar el nombre del nodo cliente
    nombre_nodo = :"cliente_#{:rand.uniform(1000)}@#{ip_string}"

    # Iniciar el nodo distribuido
    Node.start(nombre_nodo)

    # Establecer la cookie para autenticación entre nodos
    Node.set_cookie(:chat_secreto)

    # Intentar conectar con el servidor
    servidor = :"servidor@172.20.10.7"

    case Node.connect(servidor) do
      true ->
        IO.puts("Cliente iniciado en #{nombre_nodo}")
        IO.puts("Conectado al servidor: #{servidor}")
        ChatDistribuido.Cliente.start()
      false ->
        IO.puts("Error: No se pudo conectar al servidor #{servidor}")
        IO.puts("Asegúrate de que el servidor esté en ejecución y la IP sea correcta.")
    end
  end
end
