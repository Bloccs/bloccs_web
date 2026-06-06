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

  alias Bloccs.Web.Format

  attr :network, :any, required: true
  attr :base_path, :string, required: true
  attr :states, :map, default: %{}
  attr :frame, :map, default: %{nodes: %{}, updated_at: nil}
  attr :flow, :map, default: %{events: [], series: [], rate: 0}

  def render(assigns) do
    nodes = Map.get(assigns.frame, :nodes, %{})

    assigns =
      assigns
      |> assign(:rates, Map.new(nodes, fn {id, v} -> {id, Map.get(v, :throughput, 0)} end))
      |> assign(:titles, Map.new(nodes, fn {id, v} -> {id, title_for(id, v)} end))
      |> assign(:active_edges, active_edges(assigns.flow))
      |> assign(:live?, assigns.flow.rate > 0)
      |> assign(:summary, summary(nodes))

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

      <div class="bloccs-topo-summary">
        <span><strong>{Format.rate(@summary.total)}</strong> across the network</span>
        <span :if={@summary.busiest}>
          busiest <strong>{@summary.busiest}</strong> ({Format.rate(@summary.busiest_rate)})
        </span>
        <span :if={@summary.slowest}>
          slowest <strong>{@summary.slowest}</strong> (p95 {Format.latency(@summary.slowest_p95)})
        </span>
        <span class={@summary.errors > 0 && "bloccs-num--error"}>
          {@summary.errors} <span class="bloccs-muted">errors</span>
        </span>
      </div>

      <.graph
        network={@network}
        states={@states}
        rates={@rates}
        titles={@titles}
        active_edges={@active_edges}
        link_base={@base_path}
      />

      <.legend network={@network} />
      <p class="bloccs-muted bloccs-hint">
        Nodes colour by live state and show throughput; active edges animate. Hover a node for its
        stats, or click it for its messages.
      </p>
    </section>
    """
  end

  defp title_for(id, v) do
    base = "#{id} · #{Format.rate(v.throughput)} · #{Format.count(v.completed)} done"
    p95 = if v.p95, do: " · p95 #{Format.latency(v.p95)}", else: ""
    errs = if v.errors > 0, do: " · #{v.errors} err", else: ""
    base <> p95 <> errs
  end

  defp summary(nodes) when map_size(nodes) == 0,
    do: %{total: 0, busiest: nil, busiest_rate: 0, slowest: nil, slowest_p95: nil, errors: 0}

  defp summary(nodes) do
    list = Map.to_list(nodes)
    {busiest, b} = Enum.max_by(list, fn {_id, v} -> v.throughput end)
    {slowest, s} = Enum.max_by(list, fn {_id, v} -> v.p95 || 0 end)

    %{
      total: Enum.sum(Enum.map(list, fn {_id, v} -> v.throughput end)),
      busiest: if(b.throughput > 0, do: busiest),
      busiest_rate: b.throughput,
      slowest: if(s.p95, do: slowest),
      slowest_p95: s.p95,
      errors: Enum.sum(Enum.map(list, fn {_id, v} -> v.errors end))
    }
  end

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
