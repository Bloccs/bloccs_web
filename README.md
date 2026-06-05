# bloccs_web

A self-hosted, real-time **dashboard for [bloccs](https://github.com/Bloccs/bloccs)**
— mount it into your Phoenix app and watch your running networks: topology in the
bloccs hexagon notation, live per-node metrics, and coverage. Modeled on
`oban_web`: a separate package, mounted with one router macro, shipping
precompiled assets (no Node build in your app).

> **Experimental.** bloccs_web tracks the bloccs library closely and its API may
> change between minor versions while both are pre-1.0.

It is **observe-only** — the dashboard reads the library's `Bloccs.Introspect`
API and the `[:bloccs, …]` telemetry stream; it never drives the runtime.

## Install

```elixir
# mix.exs
def deps do
  [
    {:bloccs, "~> 0.2"},
    {:bloccs_web, "~> 0.1"}
  ]
end
```

## Mount

```elixir
# lib/my_app_web/router.ex
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  import Bloccs.Web.Router

  scope "/" do
    pipe_through [:browser, :require_admin]   # your existing auth
    bloccs_dashboard "/bloccs"
  end
end
```

Visit `/bloccs`. The dashboard inherits auth from the pipeline you pipe it
through. See [the installation guide](guides/installation.md) for the resolver
(per-feature authorization) and asset details.

## The four panels

1. **Networks** — every running network, with node/edge counts and uptime.
2. **Topology** — the network graph drawn in the bloccs hexagon notation, node
   state lighting up live.
3. **Metrics** — per-node throughput, latency, error rate, and queue
   back-pressure, on a rolling window.
4. **Coverage** — which ports and edges a run actually exercised, plus a
   `.bloccs-trace` viewer.

## License & Pro

bloccs_web is **MIT-licensed and free**. Some advanced features may later be
offered under a bloccs Pro license; the dashboard ships the gating *seam* (a
`Bloccs.Web.Resolver`) but no license logic — in the open build every feature is
on.

## Status

This is the **P0 skeleton**: the package mounts and renders its shell. The panels
are wired up across subsequent phases (see `CHANGELOG.md`).
