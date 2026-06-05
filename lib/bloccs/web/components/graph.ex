defmodule Bloccs.Web.Components.Graph do
  @moduledoc """
  The shared topology SVG: places one `<.hex_glyph>` per node and one bezier
  `<path>` per edge from a server-computed `Bloccs.Web.Topology.Layout`. Used by
  the topology panel (live node state) and the coverage panel (reached/unreached
  overlay). Pure rendering — no data loading, no layout math.
  """

  use Bloccs.Web, :html

  alias Bloccs.Web.Topology.Layout

  attr :network, :any, required: true
  attr :states, :map, default: %{}
  # nil = no coverage overlay; a MapSet of {from_node, to_node} = reached edges
  attr :reached_edges, :any, default: nil

  def graph(assigns) do
    assigns = assign(assigns, :layout, Layout.compute(assigns.network))

    ~H"""
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
          <path
            :for={e <- @layout.edges}
            class={["bloccs-edge", edge_class(@reached_edges, e)]}
            d={e.path}
            fill="none"
          />
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
    """
  end

  defp edge_class(nil, _edge), do: nil

  defp edge_class(reached, %{from: f, to: t}) do
    if MapSet.member?(reached, {f, t}), do: "bloccs-edge--reached", else: "bloccs-edge--unreached"
  end
end
