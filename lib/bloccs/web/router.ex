defmodule Bloccs.Web.Router do
  @moduledoc """
  Router helpers for mounting the bloccs dashboard into a host Phoenix app.

  Add one macro call inside a `scope` and pipe it through whatever auth your
  app already uses:

      defmodule MyAppWeb.Router do
        use MyAppWeb, :router
        import Bloccs.Web.Router

        scope "/" do
          pipe_through [:browser, :require_admin]
          bloccs_dashboard "/bloccs"
        end
      end

  The dashboard inherits the host's auth from the pipeline; per-feature
  authorization (the Pro seam) is delegated to a `Bloccs.Web.Resolver`.
  """

  @doc """
  Mount the bloccs dashboard at `path`.

  ## Options

    * `:resolver` — a module implementing `Bloccs.Web.Resolver`, consulted for
      the current user, access level, and enabled features. Defaults to
      `Bloccs.Web.Access` (everything visible — the free baseline).
    * `:as` — the route helper name. Defaults to `:bloccs_dashboard`.
    * `:on_mount` — extra `on_mount` hooks appended to the dashboard's own.

  All four panels live under a single `live_session` so navigating between them
  never triggers a full remount.
  """
  defmacro bloccs_dashboard(path, opts \\ []) do
    quote bind_quoted: binding() do
      resolver = Keyword.get(opts, :resolver, Bloccs.Web.Access)
      as = Keyword.get(opts, :as, :bloccs_dashboard)
      extra_on_mount = List.wrap(Keyword.get(opts, :on_mount, []))

      session_args = %{"resolver" => to_string(resolver), "base_path" => path}

      # The dashboard's own precompiled bundles, served from priv/static so the
      # host needs no Plug.Static config. Inherits the surrounding pipeline.
      forward "#{path}/assets", Bloccs.Web.Assets

      live_session :bloccs_dashboard,
        session: session_args,
        root_layout: {Bloccs.Web.Layouts, :root},
        on_mount: [{Bloccs.Web.DashboardLive, {:resolver, resolver}} | extra_on_mount] do
        # One LiveView, four actions (oban_web style) — no remount on nav.
        live "#{path}", Bloccs.Web.DashboardLive, :networks, as: as
        live "#{path}/networks", Bloccs.Web.DashboardLive, :networks, as: as
        live "#{path}/networks/:network", Bloccs.Web.DashboardLive, :topology, as: as
        live "#{path}/networks/:network/metrics", Bloccs.Web.DashboardLive, :metrics, as: as
        live "#{path}/networks/:network/coverage", Bloccs.Web.DashboardLive, :coverage, as: as
      end
    end
  end
end
