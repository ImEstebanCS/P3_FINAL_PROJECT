defmodule ChatDistribuido.Usuario do
  @moduledoc """
  Módulo que representa a un usuario del chat.
  """

  defstruct [:nombre, :pid]

  @doc """
  Crea una nueva estructura de Usuario.
  """
  def nuevo(nombre, pid) do
    %__MODULE__{
      nombre: nombre,
      pid: pid
    }
  end
end
