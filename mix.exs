defmodule Scrivener.Ecto.Mixfile do
  use Mix.Project

  def project do
    [
      app: :scrivener_ecto,
      version: "2.8.0-dev",
      elixir: "~> 1.3",
      elixirc_paths: elixirc_paths(Mix.env()),
      package: package(),
      description: "Paginate your Ecto queries with Scrivener",
      deps: deps(),
      aliases: aliases(),
      docs: [
        main: "readme",
        extras: [
          "README.md"
        ]
      ]
    ]
  end

  defp aliases do
    [
      "db.reset": [
        "ecto.drop",
        "ecto.create",
        "ecto.migrate"
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:scrivener, "~> 2.4"},
      {:ecto, "~> 3.7"},
      {:ecto_sql, "~> 3.7", only: :test},
      {:dialyxir, "~> 1.0", only: :dev},
      {:earmark, ">= 0.0.0", only: :dev},
      {:ex_doc, "~> 0.23", only: :dev},
      {:postgrex, "~> 0.15.0", only: :test}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp package do
    [
      maintainers: ["Drew Olson"],
      licenses: ["MIT"],
      links: %{"github" => "https://github.com/drewolson/scrivener_ecto"},
      files: [
        "lib/scrivener",
        "mix.exs",
        "README.md"
      ]
    ]
  end
end
