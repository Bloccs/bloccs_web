defmodule Bloccs.Web.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/Bloccs/bloccs_web"

  def project do
    [
      app: :bloccs_web,
      version: @version,
      elixir: "~> 1.16",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      package: package(),
      description:
        "A self-hosted, real-time dashboard for running bloccs networks — " <>
          "topology, live per-node metrics, and coverage, mounted into your Phoenix app.",
      name: "bloccs_web",
      source_url: @source_url,
      homepage_url: @source_url,
      docs: docs(),
      preferred_cli_env: [check: :test, "assets.verify": :dev]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Bloccs.Web.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # The library being observed. Needs the `:payload` emit metadata from
      # bloccs 0.3.0 (Bloccs.Inspect). For local dev against an unreleased bloccs,
      # override with a path dep: {:bloccs, path: "../bloccs"}
      {:bloccs, "~> 0.3"},
      {:phoenix, "~> 1.7"},
      {:phoenix_live_view, "~> 1.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_pubsub, "~> 2.1"},
      {:telemetry, "~> 1.2"},
      {:jason, "~> 1.4"},
      # dev/test only — never shipped in the package (see `files:` below)
      {:esbuild, "~> 0.8", only: :dev, runtime: false},
      {:tailwind, "~> 0.2", only: :dev, runtime: false},
      # HTTP server for the local `mix dev` harness only.
      {:bandit, "~> 1.5", only: :dev},
      {:floki, ">= 0.36.0", only: :test},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  # Precompiled assets ship in `priv/static`; the `assets/` source tree and the
  # dummy test host are excluded from the Hex package (the oban_web model — no
  # consumer Node build).
  defp package do
    [
      licenses: ["Apache-2.0"],
      maintainers: ["Allan MacGregor"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md",
        "bloccs" => "https://github.com/Bloccs/bloccs"
      },
      files: ~w(lib priv guides mix.exs README.md LICENSE NOTICE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      extras: ["README.md", "guides/installation.md", "CHANGELOG.md"]
    ]
  end

  defp aliases do
    [
      # Release gate, parity with app/bloccs: format + warnings-as-errors + tests.
      check: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "test"
      ],
      # Run the local dashboard harness: `mix dev` → http://localhost:4000/bloccs
      dev: ["run dev.exs"],
      # Rebuild the committed asset bundles from the dev-only `assets/` tree.
      "assets.build": [
        "tailwind bloccs_web",
        "esbuild bloccs_web"
      ],
      "assets.verify": [
        "assets.build",
        # Releases fail on a stale bundle — CI runs this and diffs priv/static.
        fn _ ->
          Mix.shell().info("rebuilt priv/static — `git diff --exit-code priv/static` in CI")
        end
      ]
    ]
  end
end
