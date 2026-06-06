defmodule Bloccs.Web.Resolver do
  @moduledoc """
  The integration seam between the dashboard and the host application: who is
  looking, what they may see, and which features are enabled.

  A host provides a module implementing this behaviour and passes it to
  `bloccs_dashboard/2` via `:resolver`. Every callback has a default (see
  `Bloccs.Web.Access`), so the simplest mount needs no resolver at all.

  ## The Pro seam

  `c:resolve_features/1` is how the open-core / Pro split is expressed without
  any LiveView change: the free build returns every feature, a future licensed
  build returns a subset, and panels gate themselves with
  `Bloccs.Web.Access.enabled?/2`. The dashboard ships **only the seam** — no
  license logic.
  """

  @typedoc "An opaque user term resolved from the connection (whatever the host uses)."
  @type user :: term()

  @typedoc """
  A coarse access level for the session. The dashboard is observe-only, so the
  meaningful distinction is full access vs. forbidden.
  """
  @type access :: :all | {:forbidden, reason :: term()}

  @typedoc "A feature flag the dashboard consults before rendering gated UI."
  @type feature :: atom()

  @doc "Resolve the current user from the Plug session map. Defaults to `nil`."
  @callback resolve_user(session :: map()) :: user()

  @doc "Resolve the access level for a user. Defaults to `:all`."
  @callback resolve_access(user()) :: access()

  @doc """
  Resolve the set of enabled features for a user. Defaults to `:all` (every
  feature on — the free baseline). A licensed build returns an explicit list.
  """
  @callback resolve_features(user()) :: :all | [feature()]

  @optional_callbacks resolve_user: 1, resolve_access: 1, resolve_features: 1
end
