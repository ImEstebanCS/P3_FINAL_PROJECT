defmodule ChatDistribuido.Usuario do
  @moduledoc """
  Módulo que representa a un usuario del chat.
  """

  defstruct [:id, :nombre, :pid]

  @doc """
  Crea una nueva estructura de Usuario con un ID único.
  """
  def nuevo(nombre, pid) do
    %__MODULE__{
      id: UUID.uuid4(),
      nombre: nombre,
      pid: pid
    }
  end
end
