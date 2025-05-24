defmodule ChatDistribuido.Usuario do
  @moduledoc """
  Módulo que representa a un usuario del chat.
  """

  # Módulo que maneja la información y operaciones de los usuarios
  defstruct [:id, :nombre, :pid]

  @doc """
  Crea una nueva estructura de Usuario con un ID único.
  """
  # Crea un nuevo usuario con un ID único y el nombre especificado
  def nuevo(nombre, pid) do
    id = :rand.uniform(9999)  # Genera un ID aleatorio entre 1 y 9999
    %__MODULE__{
      id: id,
      nombre: nombre,
      pid: pid
    }
  end

  @doc """
  Formatea el usuario para mostrar en la lista de usuarios.
  """
  # Formatea la información del usuario para mostrarla en la lista
  def formatear(usuario) do
    "#{usuario.nombre} (ID: #{usuario.id})"
  end
end
