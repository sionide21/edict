defmodule Edict.MixProject do
  use Mix.Project

  def project do
    [
      app: :edict,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Edict.Application, []}
    ]
  end

  defp deps do
    [
      {:codex, git: "git@github.com:SalesLoft/codex"},
      {:ranch, "~> 1.6"}
    ]
  end
end
