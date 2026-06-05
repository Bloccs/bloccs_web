defmodule Bloccs.Web.CoreComponents do
  @moduledoc """
  Small, self-contained UI primitives for the dashboard (status pills, metric
  badges, the Pro lock). Deliberately minimal and dependency-free — the
  dashboard ships its own styling in `priv/static` and never assumes the host's
  component library.
  """

  use Phoenix.Component

  @doc "A coloured status pill for a node/network run state."
  attr :state, :atom, default: :idle
  attr :label, :string, default: nil

  def status_pill(assigns) do
    ~H"""
    <span class={["bloccs-pill", "bloccs-pill--#{@state}"]}>
      {@label || Phoenix.Naming.humanize(@state)}
    </span>
    """
  end

  @doc "A compact metric badge (e.g. throughput, p99, error rate)."
  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :tone, :atom, default: :neutral

  def metric_badge(assigns) do
    ~H"""
    <span class={["bloccs-badge", "bloccs-badge--#{@tone}"]}>
      <span class="bloccs-badge__label">{@label}</span>
      <span class="bloccs-badge__value">{@value}</span>
    </span>
    """
  end

  @doc """
  A "Pro" lock placeholder, rendered where a gated feature would be when the
  resolver hasn't granted it. The free build never shows this (all features on).
  """
  attr :feature, :atom, required: true

  def pro_lock(assigns) do
    ~H"""
    <div class="bloccs-pro-lock" role="note">
      <span class="bloccs-pro-lock__badge">Pro</span>
      <span>{Phoenix.Naming.humanize(@feature)} is available with a bloccs Pro license.</span>
    </div>
    """
  end
end
