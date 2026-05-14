defmodule Spex.MixProject do
  use Mix.Project

  @source_url "https://github.com/maxpohlmann/spex"

  def project do
    meta_tests? = System.get_env("META_TESTS") == "true"

    [
      app: :spex,
      version: "0.1.0",
      elixirc_paths: elixirc_paths(Mix.env()),
      test_paths: test_paths(meta_tests?),
      config_path: config_path(meta_tests?),
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      description: description(),
      package: package(),
      dialyzer: dialyzer(),
      source_url: @source_url
    ]
  end

  def application do
    [
      mod: {Spex.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test_support"]
  defp elixirc_paths(_), do: ["lib"]

  defp test_paths(true = _meta_tests?), do: ["test_meta"]
  defp test_paths(false), do: ["test"]

  defp config_path(true = _meta_tests?), do: "config/test_meta.exs"
  defp config_path(false), do: "config/test.exs"

  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40", only: [:dev, :test], runtime: false},
      {:rustler, "~> 0.37.3", runtime: false}
    ]
  end

  defp docs do
    [
      extras: [
        "README.md"
      ],
      main: "readme"
    ]
  end

  defp description do
    "A tool to check the correctness of implementations against specifications. It provides " <>
      "ways to (1) specify specifications, (2) derive implementation models, and (3) check " <>
      "these against each other w.r.t. behavioural equivalence."
  end

  defp package do
    [
      name: "lts_spex",
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url
      }
    ]
  end

  defp dialyzer do
    [
      plt_add_apps: [:ex_unit, :mix]
    ]
  end

  def cli do
    [
      preferred_envs: [
        spex: :test
      ]
    ]
  end
end
