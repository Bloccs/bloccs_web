defmodule Bloccs.Web.Panels.Topology do
  @moduledoc """
  Panel 2 — the network graph drawn in the bloccs hexagon notation. The layout
  is computed server-side (`Bloccs.Web.Topology.Layout`) and rendered as a single
  SVG: one `<.hex_glyph>` per node, one cubic-bezier `<path>` per edge. Live node
  state (`states[node_id]`) is an assign-driven CSS class on each glyph — no
  client animation. P4 feeds `states`; in P3 every node is `:idle`.
  """

  use Bloccs.Web, :html

  alias Bloccs.Web.Topology.Layout

  attr :network, :any, required: true
  attr :base_path, :string, required: true
  attr :states, :map, default: %{}

  def render(assigns) do
    assigns = assign(assigns, :layout, Layout.compute(assigns.network))

    ~H"""
    <section class="bloccs-topology">
      <header class="bloccs-panel__header">
        <h1>Topology</h1>
        <span class="bloccs-muted">
          {length(@layout.nodes)} nodes · {length(@layout.edges)} edges
        </span>
      </header>

      <div class="bloccs-graph" id={"graph-#{@network.id}"}>
        <svg
          class="bloccs-graph__svg"
          viewBox={"0 0 #{@layout.width} #{@layout.height}"}
          width={@layout.width}
          height={@layout.height}
          role="img"
          aria-label={"Topology of #{@network.id}"}
        >
          <g class="bloccs-graph__edges">
            <path :for={e <- @layout.edges} class="bloccs-edge" d={e.path} fill="none" />
          </g>
          <g class="bloccs-graph__nodes">
            <g :for={n <- @layout.nodes} class="bloccs-graph__node">
              <.hex_glyph
                glyph={n.glyph}
                state={Map.get(@states, n.id, :idle)}
                label={n.label}
                x={n.x}
                y={n.y}
              />
              <text class="bloccs-graph__label" x={n.x} y={n.y + 74} text-anchor="middle">
                {n.label}
              </text>
            </g>
          </g>
        </svg>
      </div>

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
