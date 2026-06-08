defmodule Bloccs.Web.Panels.Topology do
  @moduledoc """
  Panel 2 — the live network graph paired with an inspector.

  The graph (`Bloccs.Web.Components.Graph`) shows node state, throughput, and
  packets moving along active edges. The side panel inspects either the whole
  network (setup + live totals) or a clicked node — its primitive (kind, ports,
  effects), live metrics, and the **code** that implements it (the author's
  `pure_core` / `effect_shell` plus any retry/idempotency/window policy). The
  contract fields are read defensively, so this works against any `bloccs` that
  predates them. Selection is the `?node=` URL param (shareable).
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

        <aside class="bloccs-ins">
          <%= if @selected_node do %>
            <.node_inspect
              node={@selected_node}
              m={Map.get(@frame.nodes, @selected_node.id)}
              base={@base_path}
              network_id={@network.id}
              topo={@topo_path}
            />
          <% else %>
            <.network_inspect network={@network} nodes={@frame.nodes} />
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
    assigns =
      assigns
      |> assign(:contract, Map.get(assigns.node, :contract))
      |> assign(:config, Map.get(assigns.node, :config, %{}))

    ~H"""
    <header class="bloccs-ins__head">
      <span class={["bloccs-ins__glyph", "hex-glyph--#{(@m && @m.state) || :idle}"]}>
        <svg viewBox="-60 -62 120 120" width="40" height="40">
          <.hex_glyph glyph={@node.glyph} state={(@m && @m.state) || :idle} />
        </svg>
      </span>
      <div class="bloccs-ins__id">
        <div class="bloccs-ins__name">
          {@node.id}
          <span
            :if={@node[:reply]}
            class="bloccs-chip bloccs-chip--reply"
            title="Replies to Bloccs.call/4 · cast/4"
          >
            reply
          </span>
        </div>
        <div class="bloccs-ins__kind">{@node.kind} · {@node.glyph}</div>
      </div>
      <.link patch={@topo} class="bloccs-ins__x" title="Back to network">×</.link>
    </header>

    <p :if={@node.doc[:intent]} class="bloccs-ins__intent">{@node.doc.intent}</p>

    <div class="bloccs-ins__tiles">
      <.tile label="throughput" value={Format.rate(@m && @m.throughput)} />
      <.tile label="p95" value={lat(@m, :p95)} />
      <.tile label="completed" value={Format.count(@m && @m.completed)} />
      <.tile label="errors" value={(@m && @m.errors) || 0} bad={@m && @m.errors > 0} />
    </div>

    <.section title="Ports">
      <div class="bloccs-ports">
        <div :for={p <- @node.ports_in} class="bloccs-portrow">
          <span class="bloccs-portrow__dir">in</span>
          <span class="bloccs-portrow__name">{p.name}</span>
          <span class="bloccs-chip">{p.schema}</span>
        </div>
        <div :for={p <- @node.ports_out} class="bloccs-portrow">
          <span class="bloccs-portrow__dir bloccs-portrow__dir--out">out</span>
          <span class="bloccs-portrow__name">{p.name}</span>
          <span class="bloccs-chip">{p.schema}</span>
        </div>
      </div>
    </.section>

    <.section title="Effects">
      <div :for={fx <- @node.effects} class="bloccs-fxrow">
        <span class="bloccs-chip bloccs-chip--fx">{fx}</span>
        <span :for={scope <- effect_scopes(@node, fx)} class="bloccs-chip bloccs-chip--scope">
          {scope}
        </span>
      </div>
      <span :if={@node.effects == []} class="bloccs-muted bloccs-ins__pure">
        pure — no declared effects
      </span>
    </.section>

    <.section :if={@contract} title="Code">
      <.coderef label="pure core" ref={@contract[:pure_core]} />
      <.coderef label="effect shell" ref={@contract[:effect_shell]} />
      <div :if={@contract[:timeout_ms]} class="bloccs-kv">
        <span class="bloccs-muted">timeout</span><code>{@contract.timeout_ms}ms</code>
      </div>
      <div :if={@contract[:retry]} class="bloccs-kv">
        <span class="bloccs-muted">retry</span><code>{retry(@contract.retry)}</code>
      </div>
      <div :if={@contract[:idempotency]} class="bloccs-kv">
        <span class="bloccs-muted">idempotency</span><code>key: {@contract.idempotency[:key]}</code>
      </div>
      <div :for={{label, val} <- prim_config(@config)} class="bloccs-kv">
        <span class="bloccs-muted">{label}</span><code>{val}</code>
      </div>
    </.section>

    <div class="bloccs-ins__foot">
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

  defp network_inspect(assigns) do
    assigns =
      assigns
      |> assign(:total, assigns.nodes |> Map.values() |> Enum.map(& &1.throughput) |> Enum.sum())
      |> assign(:errors, assigns.nodes |> Map.values() |> Enum.map(& &1.errors) |> Enum.sum())

    ~H"""
    <header class="bloccs-ins__head">
      <div class="bloccs-ins__id">
        <div class="bloccs-ins__name">{@network.id}</div>
        <div class="bloccs-ins__kind">v{@network.version}</div>
      </div>
    </header>

    <div class="bloccs-ins__tiles">
      <.tile label="throughput" value={Format.rate(@total)} />
      <.tile label="errors" value={@errors} bad={@errors > 0} />
      <.tile label="nodes" value={length(@network.nodes)} />
      <.tile label="edges" value={length(@network.edges)} />
    </div>

    <.section title="Supervision">
      <div class="bloccs-kv">
        <span class="bloccs-muted">strategy</span><code>{@network.supervision[:strategy]}</code>
      </div>
      <div class="bloccs-kv">
        <span class="bloccs-muted">restart limit</span>
        <code>{@network.supervision[:max_restarts]} / {@network.supervision[:max_seconds]}s</code>
      </div>
    </.section>

    <.section title="Inputs">
      <div :for={{name, ep} <- Map.to_list(@network.expose.in)} class="bloccs-portrow">
        <span class="bloccs-portrow__name">{name}</span>
        <span class="bloccs-chip">{endpoint(ep)}</span>
      </div>
      <p :if={@network.expose.in == %{}} class="bloccs-muted">none exposed</p>
    </.section>

    <.section title="Outputs">
      <div :for={{name, ep} <- Map.to_list(@network.expose.out)} class="bloccs-portrow">
        <span class="bloccs-portrow__name">{name}</span>
        <span class="bloccs-chip">{endpoint(ep)}</span>
      </div>
      <p :if={@network.expose.out == %{}} class="bloccs-muted">none exposed</p>
    </.section>

    <p class="bloccs-muted bloccs-ins__hint">Click a node to inspect its primitive and code.</p>
    """
  end

  # ---- small building blocks ----

  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :bad, :any, default: false

  defp tile(assigns) do
    ~H"""
    <div class="bloccs-tile">
      <div class={["bloccs-tile__v", @bad && "bloccs-num--error"]}>{@value}</div>
      <div class="bloccs-tile__l">{@label}</div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :ref, :any, default: nil

  defp coderef(assigns) do
    ~H"""
    <div :if={@ref} class="bloccs-coderef">
      <div class="bloccs-coderef__l">{@label}</div>
      <code class="bloccs-coderef__v">{@ref}</code>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :rest, :global
  slot :inner_block, required: true

  defp section(assigns) do
    ~H"""
    <div class="bloccs-ins__section" {@rest}>
      <h3>{@title}</h3>
      {render_slot(@inner_block)}
    </div>
    """
  end

  defp retry(r) when is_map(r) do
    parts = ["#{r[:strategy]}", "max #{r[:max]}"]
    parts = if r[:base_ms], do: parts ++ ["base #{r[:base_ms]}ms"], else: parts
    Enum.join(parts, ", ")
  end

  defp retry(_), do: "—"

  @doc """
  The declared scopes/detail for one effect axis, from the node view's
  `effect_detail` (bloccs ≥ 0.8). `db` → its `"table:action"` scopes (read /
  insert / update / delete); `http` → allowed hosts + methods; `time`/`random`
  → their mode. Empty for older introspect views (graceful: just the axis chip).
  """
  def effect_scopes(node, axis) do
    case node |> Map.get(:effect_detail, %{}) |> Map.get(axis) do
      %{allow: allow, methods: methods} -> List.wrap(allow) ++ List.wrap(methods)
      %{allow: allow} -> List.wrap(allow)
      mode when is_binary(mode) -> [mode]
      _ -> []
    end
  end

  @doc """
  Human one-liners for whichever primitive blocks a node declares (`batch`,
  `join`, `rate`, `delay`). Values may be `Bloccs.Manifest.*` structs, which do
  not implement `Access`, so they're read with `Map.get/2`, not bracket syntax.
  """
  def prim_config(config) when is_map(config) do
    []
    |> add_if(config[:batch], "batch", fn b ->
      "size #{Map.get(b, :size)} · #{Map.get(b, :timeout_ms)}ms"
    end)
    |> add_if(config[:join], "join", fn j ->
      "on #{Map.get(j, :on)} · #{Map.get(j, :timeout_ms)}ms"
    end)
    |> add_if(config[:rate], "rate", fn r ->
      "#{Map.get(r, :allowed)} / #{Map.get(r, :interval_ms)}ms"
    end)
    |> add_if(config[:delay_ms], "delay", fn ms -> "#{ms}ms" end)
  end

  def prim_config(_), do: []

  defp add_if(acc, nil, _label, _fmt), do: acc
  defp add_if(acc, val, label, fmt), do: acc ++ [{label, fmt.(val)}]

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
