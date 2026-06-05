defmodule Bloccs.Web.Access do
  @moduledoc """
  The default `Bloccs.Web.Resolver` — the free, open baseline.

  Every user is anonymous, has full read access, and sees every feature. This
  is also the central place panels ask "is this feature on?" via `enabled?/2`,
  so a future licensed resolver only has to narrow `resolve_features/1` while the
  LiveView code stays unchanged.
  """

  @behaviour Bloccs.Web.Resolver

  @typedoc "Features the dashboard knows how to gate. All on in the free build."
  @type feature :: :networks | :topology | :metrics | :coverage | :trace_export

  @all_features ~w(networks topology metrics coverage trace_export)a

  @impl true
  def resolve_user(_session), do: nil

  @impl true
  def resolve_access(_user), do: :all

  @impl true
  def resolve_features(_user), do: :all

  @doc "Every feature the dashboard defines (the upper bound a resolver may grant)."
  @spec all_features() :: [feature()]
  def all_features, do: @all_features

  @doc """
  Whether `feature` is enabled given a resolved feature set.

  `:all` (the free baseline) enables everything; a list enables only its
  members. Panels call this and render a "Pro" lock when it returns `false`.
  """
  @spec enabled?(feature(), :all | [feature()]) :: boolean()
  def enabled?(_feature, :all), do: true
  def enabled?(feature, features) when is_list(features), do: feature in features
end
