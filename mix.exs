defmodule ChatDistribuido.MixProject do
  use Mix.Project

  def project do
    [
      app: :chat_distribuido,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {ChatDistribuido.Application, []}
    ]
  end

  defp deps do
    [
      {:uuid, "~> 1.1"}
    ]
  end
end
