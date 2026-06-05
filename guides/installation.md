# Installation

bloccs_web mounts into an existing Phoenix application. It ships precompiled
CSS/JS, so you do **not** need Node, esbuild, or Tailwind in your app.

## 1. Add the dependency

```elixir
# mix.exs
def deps do
  [
    {:bloccs, "~> 0.2"},
    {:bloccs_web, "~> 0.1"}
  ]
end
```

```console
$ mix deps.get
```

## 2. Mount the dashboard

```elixir
# lib/my_app_web/router.ex
import Bloccs.Web.Router

scope "/" do
  pipe_through [:browser, :require_admin]
  bloccs_dashboard "/bloccs"
end
```

The dashboard mounts a **single `live_session`** over the panel routes and serves
its own static assets from a dashboard-owned route under the mount path — no
`Plug.Static` configuration in your app.

## 3. Authorize (optional)

The dashboard inherits whatever auth you `pipe_through`. For **per-feature**
authorization — and the open-core / Pro seam — supply a resolver:

```elixir
defmodule MyApp.BloccsResolver do
  @behaviour Bloccs.Web.Resolver

  @impl true
  def resolve_user(session), do: session["current_admin"]

  @impl true
  def resolve_access(nil), do: {:forbidden, :no_user}
  def resolve_access(_admin), do: :all

  @impl true
  def resolve_features(_admin), do: :all
end

bloccs_dashboard "/bloccs", resolver: MyApp.BloccsResolver
```

Each callback is optional and defaults to the open baseline (`Bloccs.Web.Access`):
anonymous user, full access, every feature enabled.

## 4. Make networks discoverable

bloccs_web lists networks via `Bloccs.Discovery`, which a network registers from
its generated supervisor at boot. Networks compiled with **bloccs < 0.2** don't
carry that registration — recompile them after upgrading:

```console
$ mix bloccs.compile my_network
```

## Local development of bloccs_web itself

Before `bloccs 0.2` is published, point the dependency at your local checkout:

```elixir
{:bloccs, path: "../bloccs"}
```

The dev-only asset toolchain lives in `assets/`; rebuild the committed bundles
with `mix assets.build`. CI runs `mix assets.verify` and fails on a stale
`priv/static`.
