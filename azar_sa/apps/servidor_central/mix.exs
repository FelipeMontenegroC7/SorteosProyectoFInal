defmodule ServidorCentral.MixProject do
  use Mix.Project

  def project do
    [
      app: :servidor_central,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {ServidorCentral.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
   defp deps do
     [
       {:jason, "~> 1.4"},
       {:ecto, "~> 3.12"},
       {:bcrypt_elixir, "~> 3.0"}
     ]
   end
end
