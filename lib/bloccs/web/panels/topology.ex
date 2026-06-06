defmodule Bloccs.Web.Panels.Topology do
  @moduledoc """
  Panel 2 — the network graph drawn in the bloccs hexagon notation, alive.

  The layout is computed server-side (`Bloccs.Web.Topology.Layout`) and rendered
  as a single SVG by `Bloccs.Web.Components.Graph`. On top of the static shape it
  layers live telemetry: each node's glyph colours by its state and shows its
  current throughput; edges that carried a message recently animate; and every
  node links to its own filtered message feed. Data comes from the metrics frame
  (`states`, `rates`) and the flow snapshot (`active_edges`).
  """

  use Bloccs.Web, :html

  import Bloccs.Web.Components.Graph

  attr :network, :any, required: true
  attr :base_path, :string, required: true
  attr :states, :map, default: %{}
  attr :frame, :map, default: %{nodes: %{}, updated_at: nil}
  attr :flow, :map, default: %{events: [], series: [], rate: 0}

  def render(assigns) do
    assigns =
      assigns
      |> assign(:rates, rates(assigns.frame))
      |> assign(:active_edges, active_edges(assigns.flow))
      |> assign(:live?, assigns.flow.rate > 0)

    ~H"""
    <section class="bloccs-topology">
      <header class="bloccs-panel__header">
        <h1>Topology</h1>
        <span class="bloccs-muted">
          <span :if={@live?}><span class="bloccs-live">●</span> {@flow.rate}/s · </span>{length(
            @network.nodes
          )} nodes · {length(@network.edges)} edges
        </span>
      </header>

      <.graph
        network={@network}
        states={@states}
        rates={@rates}
        active_edges={@active_edges}
        link_base={@base_path}
      />

      <.legend network={@network} />
      <p class="bloccs-muted bloccs-hint">
        Nodes colour by live state and show throughput; active edges animate. Click a node for its messages.
      </p>
    </section>
    """
  end

  defp rates(%{nodes: nodes}) when is_map(nodes) do
    Map.new(nodes, fn {id, v} -> {id, Map.get(v, :throughput, 0)} end)
  end

  defp rates(_), do: %{}

  # Edges that carried a message in the recent flow window — {from_node, to_node}.
  defp active_edges(%{events: events}) when is_list(events) do
    for %{node: n, to: {tn, _tp}} <- events, reduce: MapSet.new() do
      acc -> MapSet.put(acc, {n, tn})
    end
  end

  defp active_edges(_), do: MapSet.new()

  attr :network, :any, required: true

  defp legend(assigns) do
    assigns = assign(assigns, :glyphs, distinct_glyphs(assigns.network))

    ~H"""
    <footer class="bloccs-legend">
      <span :for={g <- @glyphs} class="bloccs-legend__item">
        <svg viewBox="-60 -62 120 120" width="22" height="22"><.hex_glyph glyph={g} /></svg>
        {g}
      </span>
    </footer>
    """
  end

  defp distinct_glyphs(network) do
    network.nodes |> Enum.map(& &1.glyph) |> Enum.uniq() |> Enum.sort()
  end
end
