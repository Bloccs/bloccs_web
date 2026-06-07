defmodule Bloccs.Web.Panels.Topology do
  @moduledoc """
  Panel 2 — the network graph drawn in the bloccs hexagon notation, alive, paired
  with an inspector. The live graph (`Bloccs.Web.Components.Graph`) shows node
  state, throughput, and packets moving along active edges. The side panel shows
  the network's setup by default, and a clicked node's primitive details (kind,
  ports, declared effects, concurrency) plus its live metrics. Selection is the
  `?node=` URL param, so it's shareable and back-button friendly.
  """

  use Bloccs.Web, :html

  import Bloccs.Web.Components.Graph

  alias Bloccs.Web.{Format, Paths}

  attr :network, :any, required: true
  attr :base_path, :string, required: true
  attr :states, :map, default: %{}
  attr :frame, :map, default: %{nodes: %{}, updated_at: nil}
  attr :flow, :map, default: %{events: [], series: [], rate: 0}
  attr :selected, :any, default: nil

  def render(assigns) do
    nodes = Map.get(assigns.frame, :nodes, %{})
    selected_node = Enum.find(assigns.network.nodes, &(to_string(&1.id) == assigns.selected))

    assigns =
      assigns
      |> assign(:rates, Map.new(nodes, fn {id, v} -> {id, Map.get(v, :throughput, 0)} end))
      |> assign(:titles, Map.new(nodes, fn {id, v} -> {id, title_for(id, v)} end))
      |> assign(:active_edges, active_edges(assigns.flow))
      |> assign(:live?, assigns.flow.rate > 0)
      |> assign(:selected_node, selected_node)
      |> assign(:topo_path, Paths.topology(assigns.base_path, assigns.network.id))

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

      <div class="bloccs-topo">
        <div class="bloccs-topo__graph">
          <.graph
            network={@network}
            states={@states}
            rates={@rates}
            titles={@titles}
            active_edges={@active_edges}
            link_base={@topo_path}
            selected={@selected_node && @selected_node.id}
          />
          <.legend network={@network} />
        </div>

        <aside class="bloccs-inspect">
          <%= if @selected_node do %>
            <.node_inspect
              node={@selected_node}
              m={Map.get(@frame.nodes, @selected_node.id)}
              base={@base_path}
              network_id={@network.id}
              topo={@topo_path}
            />
          <% else %>
            <.network_inspect network={@network} nodes={@frame.nodes} rate={@flow.rate} />
          <% end %>
        </aside>
      </div>
    </section>
    """
  end

  # ---- inspector: a selected node ----

  attr :node, :map, required: true
  attr :m, :any, default: nil
  attr :base, :string, required: true
  attr :network_id, :any, required: true
  attr :topo, :string, required: true

  defp node_inspect(assigns) do
    ~H"""
    <div class="bloccs-inspect__head">
      <svg viewBox="-60 -62 120 120" width="34" height="34">
        <.hex_glyph glyph={@node.glyph} state={(@m && @m.state) || :idle} />
      </svg>
      <div>
        <div class="bloccs-inspect__title">{@node.id}</div>
        <div class="bloccs-inspect__sub">{@node.kind} · {@node.glyph}</div>
      </div>
      <.link patch={@topo} class="bloccs-inspect__close" title="Back to network">×</.link>
    </div>

    <p :if={@node.doc[:intent]} class="bloccs-inspect__intent">{@node.doc.intent}</p>

    <div class="bloccs-inspect__stats">
      <div><span class="bloccs-muted">throughput</span><b>{Format.rate(@m && @m.throughput)}</b></div>
      <div><span class="bloccs-muted">p50 · p95</span><b>{lat(@m, :p50)} · {lat(@m, :p95)}</b></div>
      <div><span class="bloccs-muted">completed</span><b>{Format.count(@m && @m.completed)}</b></div>
      <div>
        <span class="bloccs-muted">errors</span>
        <b class={@m && @m.errors > 0 && "bloccs-num--error"}>{(@m && @m.errors) || 0}</b>
      </div>
    </div>

    <.section title="In">
      <div :for={p <- @node.ports_in} class="bloccs-port">
        <span class="bloccs-port__name">{p.name}</span>
        <span class="bloccs-port__schema">{p.schema}</span>
      </div>
      <p :if={@node.ports_in == []} class="bloccs-muted">none (entry)</p>
    </.section>

    <.section title="Out">
      <div :for={p <- @node.ports_out} class="bloccs-port">
        <span class="bloccs-port__name">{p.name}</span>
        <span class="bloccs-port__schema">{p.schema}</span>
      </div>
      <p :if={@node.ports_out == []} class="bloccs-muted">none (terminal)</p>
    </.section>

    <.section title="Effects">
      <span :for={fx <- @node.effects} class="bloccs-fx">{fx}</span>
      <span :if={@node.effects == []} class="bloccs-muted">pure — no declared effects</span>
    </.section>

    <div class="bloccs-inspect__foot">
      <span class="bloccs-muted">concurrency {@node.concurrency}</span>
      <.link navigate={Paths.messages(@base, @network_id) <> "?node=#{@node.id}"} class="bloccs-link">
        View messages →
      </.link>
    </div>
    """
  end

  # ---- inspector: the network setup ----

  attr :network, :any, required: true
  attr :nodes, :map, default: %{}
  attr :rate, :integer, default: 0

  defp network_inspect(assigns) do
    assigns =
      assigns
      |> assign(:total, assigns.nodes |> Map.values() |> Enum.map(& &1.throughput) |> Enum.sum())
      |> assign(:errors, assigns.nodes |> Map.values() |> Enum.map(& &1.errors) |> Enum.sum())

    ~H"""
    <div class="bloccs-inspect__head">
      <div>
        <div class="bloccs-inspect__title">{@network.id}</div>
        <div class="bloccs-inspect__sub">v{@network.version}</div>
      </div>
    </div>

    <div class="bloccs-inspect__stats">
      <div><span class="bloccs-muted">throughput</span><b>{Format.rate(@total)}</b></div>
      <div>
        <span class="bloccs-muted">errors</span>
        <b class={@errors > 0 && "bloccs-num--error"}>{@errors}</b>
      </div>
      <div><span class="bloccs-muted">nodes</span><b>{length(@network.nodes)}</b></div>
      <div><span class="bloccs-muted">edges</span><b>{length(@network.edges)}</b></div>
    </div>

    <.section title="Supervision">
      <div class="bloccs-kv">
        <span class="bloccs-muted">strategy</span><code>{@network.supervision[:strategy]}</code>
      </div>
      <div class="bloccs-kv">
        <span class="bloccs-muted">restarts</span>
        <code>{@network.supervision[:max_restarts]} / {@network.supervision[:max_seconds]}s</code>
      </div>
    </.section>

    <.section title="Inputs">
      <div :for={{name, ep} <- Map.to_list(@network.expose.in)} class="bloccs-port">
        <span class="bloccs-port__name">{name}</span>
        <span class="bloccs-port__schema">{endpoint(ep)}</span>
      </div>
      <p :if={@network.expose.in == %{}} class="bloccs-muted">none exposed</p>
    </.section>

    <.section title="Outputs">
      <div :for={{name, ep} <- Map.to_list(@network.expose.out)} class="bloccs-port">
        <span class="bloccs-port__name">{name}</span>
        <span class="bloccs-port__schema">{endpoint(ep)}</span>
      </div>
      <p :if={@network.expose.out == %{}} class="bloccs-muted">none exposed</p>
    </.section>

    <p class="bloccs-muted bloccs-inspect__hint">Click a node to inspect its primitive.</p>
    """
  end

  attr :title, :string, required: true
  slot :inner_block, required: true

  defp section(assigns) do
    ~H"""
    <div class="bloccs-inspect__section">
      <h3>{@title}</h3>
      {render_slot(@inner_block)}
    </div>
    """
  end

  defp lat(nil, _k), do: "—"
  defp lat(m, k), do: Format.latency(Map.get(m, k))

  defp endpoint({n, p}), do: "#{n}.#{p}"
  defp endpoint(other), do: to_string(other)

  defp title_for(id, v) do
    base = "#{id} · #{Format.rate(v.throughput)} · #{Format.count(v.completed)} done"
    p95 = if v.p95, do: " · p95 #{Format.latency(v.p95)}", else: ""
    errs = if v.errors > 0, do: " · #{v.errors} err", else: ""
    base <> p95 <> errs
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
