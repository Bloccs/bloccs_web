defmodule Bloccs.Web.Components.Graph do
  @moduledoc """
  The shared topology SVG: places one `<.hex_glyph>` per node and one bezier
  `<path>` per edge from a server-computed `Bloccs.Web.Topology.Layout`. Used by
  the topology panel (live node state + activity) and the coverage panel
  (reached/unreached overlay). Pure rendering — no data loading, no layout math.

  Live extras (all optional, off by default so the coverage panel is unchanged):

    * `states` — `%{node_id => :idle|:running|:ok|:failed}` drives the glyph colour
    * `rates` — `%{node_id => events/sec}` shown under the label when > 0
    * `active_edges` — a `MapSet` of `{from, to}` that have recent flow; those
      edges animate (marching dashes)
    * `link_base` — when set, each node links to that node's filtered messages
  """

  use Bloccs.Web, :html

  alias Bloccs.Web.Paths
  alias Bloccs.Web.Topology.Layout

  attr :network, :any, required: true
  attr :states, :map, default: %{}
  attr :rates, :map, default: %{}
  attr :active_edges, :any, default: nil
  attr :link_base, :string, default: nil
  # false hides labels/rates (for compact thumbnails)
  attr :labels, :boolean, default: true
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
            class={["bloccs-edge", edge_class(@reached_edges, e), active_class(@active_edges, e)]}
            d={e.path}
            fill="none"
          />
        </g>
        <g class="bloccs-graph__nodes">
          <g :for={n <- @layout.nodes} class="bloccs-graph__node">
            <%= if @link_base do %>
              <.link navigate={Paths.messages(@link_base, @network.id) <> "?node=#{n.id}"}>
                <.node_cell
                  n={n}
                  state={Map.get(@states, n.id, :idle)}
                  rate={Map.get(@rates, n.id)}
                  labels={@labels}
                />
              </.link>
            <% else %>
              <.node_cell
                n={n}
                state={Map.get(@states, n.id, :idle)}
                rate={Map.get(@rates, n.id)}
                labels={@labels}
              />
            <% end %>
          </g>
        </g>
      </svg>
    </div>
    """
  end

  attr :n, :map, required: true
  attr :state, :atom, default: :idle
  attr :rate, :any, default: nil
  attr :labels, :boolean, default: true

  defp node_cell(assigns) do
    ~H"""
    <.hex_glyph glyph={@n.glyph} state={@state} label={@n.label} x={@n.x} y={@n.y} />
    <text :if={@labels} class="bloccs-graph__label" x={@n.x} y={@n.y + 70} text-anchor="middle">
      {@n.label}
    </text>
    <text
      :if={@labels && @rate && @rate > 0}
      class="bloccs-graph__rate"
      x={@n.x}
      y={@n.y + 88}
      text-anchor="middle"
    >
      {rate_label(@rate)}/s
    </text>
    """
  end

  defp rate_label(r) when r >= 10, do: round(r)
  defp rate_label(r), do: Float.round(r / 1, 1)

  defp edge_class(nil, _edge), do: nil

  defp edge_class(reached, %{from: f, to: t}) do
    if MapSet.member?(reached, {f, t}), do: "bloccs-edge--reached", else: "bloccs-edge--unreached"
  end

  defp active_class(nil, _edge), do: nil

  defp active_class(active, %{from: f, to: t}) do
    if MapSet.member?(active, {f, t}), do: "bloccs-edge--active", else: nil
  end
end
