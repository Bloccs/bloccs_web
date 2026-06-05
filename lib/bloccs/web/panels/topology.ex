defmodule Bloccs.Web.Panels.Topology do
  @moduledoc """
  Panel 2 — the network graph drawn in the bloccs hexagon notation. The layout
  is computed server-side (`Bloccs.Web.Topology.Layout`) and rendered as a single
  SVG: one `<.hex_glyph>` per node, one cubic-bezier `<path>` per edge. Live node
  state (`states[node_id]`) is an assign-driven CSS class on each glyph — no
  client animation. P4 feeds `states`; in P3 every node is `:idle`.
  """

  use Bloccs.Web, :html

  import Bloccs.Web.Components.Graph

  attr :network, :any, required: true
  attr :base_path, :string, required: true
  attr :states, :map, default: %{}

  def render(assigns) do
    ~H"""
    <section class="bloccs-topology">
      <header class="bloccs-panel__header">
        <h1>Topology</h1>
        <span class="bloccs-muted">
          {length(@network.nodes)} nodes · {length(@network.edges)} edges
        </span>
      </header>

      <.graph network={@network} states={@states} />

      <.legend network={@network} />
    </section>
    """
  end

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
