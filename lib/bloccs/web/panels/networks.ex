defmodule Bloccs.Web.Panels.Networks do
  @moduledoc """
  Panel 1 — the overview: a card per running network
  (`Bloccs.Introspect.list_networks/0`), each with a live mini-topology
  thumbnail, current throughput, error count, and uptime, linking into its
  topology. Pure presentation; data (the network list, per-network graphs, and
  live `stats`) is loaded by `Bloccs.Web.DashboardLive` and passed in.
  """

  use Bloccs.Web, :html

  import Bloccs.Web.Components.Graph

  alias Bloccs.Web.{Format, Paths}

  attr :networks, :list, required: true
  attr :base_path, :string, required: true
  attr :now, :integer, required: true
  attr :graphs, :map, default: %{}
  attr :stats, :map, default: %{}

  def render(assigns) do
    ~H"""
    <section class="bloccs-networks">
      <header class="bloccs-panel__header">
        <h1>Networks</h1>
        <span class="bloccs-muted">{count_label(@networks)}</span>
      </header>

      <div :if={@networks != []} class="bloccs-cards">
        <.link
          :for={n <- @networks}
          navigate={Paths.topology(@base_path, n.id)}
          class="bloccs-card"
        >
          <div class="bloccs-card__head">
            <span>
              <span class="bloccs-card__name">{n.id}</span>
              <span class="bloccs-card__version bloccs-muted">v{n.version}</span>
            </span>
            <span class="bloccs-card__rate">
              <span :if={rate(@stats, n.id) > 0} class="bloccs-live">●</span>
              {Format.rate(rate(@stats, n.id))}
            </span>
          </div>

          <div class="bloccs-card__thumb">
            <.graph
              :if={@graphs[n.id]}
              network={@graphs[n.id]}
              states={states(@stats, n.id)}
              labels={false}
            />
          </div>

          <div class="bloccs-card__stats">
            <span>{n.node_count} <span class="bloccs-muted">nodes</span></span>
            <span>{n.edge_count} <span class="bloccs-muted">edges</span></span>
            <span class={[errors(@stats, n.id) > 0 && "bloccs-num--error"]}>
              {errors(@stats, n.id)} <span class="bloccs-muted">errors</span>
            </span>
            <span class="bloccs-card__uptime bloccs-muted">{Format.uptime(n.started_at, @now)}</span>
          </div>
        </.link>
      </div>

      <div :if={@networks == []} class="bloccs-empty">
        <p><strong>No running networks.</strong></p>
        <p class="bloccs-muted">
          Start a compiled network (e.g. <code>mix bloccs.run</code>) and it appears here.
          Networks built with bloccs &lt; 0.2 must be recompiled to be discoverable.
        </p>
      </div>
    </section>
    """
  end

  defp rate(stats, id), do: get_in(stats, [id, :rate]) || 0
  defp errors(stats, id), do: get_in(stats, [id, :errors]) || 0
  defp states(stats, id), do: get_in(stats, [id, :states]) || %{}

  defp count_label([_]), do: "1 running"
  defp count_label(list), do: "#{length(list)} running"
end
