defmodule ChatDistribuido.Mensaje do
  @moduledoc """
  Módulo que representa un mensaje en el chat.
  """

  defstruct [:contenido, :remitente, :timestamp, :sala]

  @doc """
  Crea un nuevo mensaje.
  """
  def nuevo(contenido, remitente, sala) do
    %__MODULE__{
      contenido: contenido,
      remitente: remitente,
      sala: sala,
      timestamp: :os.system_time(:millisecond)
    }
  end

  @doc """
  Formatea el mensaje para mostrar en consola.
  """
  def formatear(mensaje) do
    fecha = DateTime.from_unix!(mensaje.timestamp, :millisecond)
    "[#{fecha.hour}:#{fecha.minute}] #{mensaje.remitente.nombre}: #{mensaje.contenido}"
  end
end
