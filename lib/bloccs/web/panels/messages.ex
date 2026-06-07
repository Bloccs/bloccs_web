defmodule Bloccs.Web.Panels.Messages do
  @moduledoc """
  Panel 5 — packages moving through the network. A live throughput chart over the
  per-second `Bloccs.Web.Telemetry.Flow` buckets, plus a scrolling feed of recent
  message events: each edge a message crossed (`from.port → to.port`), its
  outcome, the emitting node's latency, and — when `Bloccs.Inspect` capture is
  enabled (bloccs 0.3+) — a bounded, redacted snapshot of the payload.

  Click a row to inspect it: the full payload plus the hop it took, highlighted on
  a mini-topology. Filterable by node and outcome.
  """

  use Bloccs.Web, :html

  import Bloccs.Web.Components.{Chart, Graph}

  alias Bloccs.Web.Format

  attr :network, :any, required: true
  attr :base_path, :string, required: true
  attr :flow, :map, default: %{events: [], series: [], rate: 0}
  attr :filters, :map, default: %{node: nil, outcome: nil}
  attr :selected, :any, default: nil
  attr :paused, :boolean, default: false

  def render(assigns) do
    events = filtered(assigns.flow.events, assigns.filters)

    assigns =
      assigns
      |> assign(:events, events)
      |> assign(:any_payload, Enum.any?(events, & &1[:payload]))
      |> assign(
        :sel_idx,
        assigns.selected && Enum.find_index(events, &same?(&1, assigns.selected))
      )

    ~H"""
    <section class="bloccs-messages">
      <header class="bloccs-panel__header">
        <h1>Messages</h1>
        <div class="bloccs-msg-live">
          <span :if={not @paused} class="bloccs-muted">
            <span class="bloccs-live">●</span> live · {@flow.rate}/s
          </span>
          <span :if={@paused} class="bloccs-paused">⏸ paused</span>
          <button type="button" class="bloccs-btn bloccs-btn--sm" phx-click="toggle_pause">
            {if @paused, do: "▶ Resume", else: "⏸ Pause"}
          </button>
        </div>
      </header>

      <.throughput series={@flow.series} />

      <div class="bloccs-msg-filters">
        <form phx-change="flow_filter">
          <select name="node" class="bloccs-select">
            <option value="" selected={@filters.node in [nil, ""]}>all nodes</option>
            <option :for={n <- node_ids(@network)} value={n} selected={to_string(n) == @filters.node}>
              {n}
            </option>
          </select>
          <select name="outcome" class="bloccs-select">
            <option value="" selected={@filters.outcome in [nil, ""]}>all outcomes</option>
            <option :for={o <- ~w(ok failed dropped)} value={o} selected={o == @filters.outcome}>
              {o}
            </option>
          </select>
        </form>
        <span class="bloccs-muted">{length(@events)} shown</span>
      </div>

      <table class="bloccs-table bloccs-feed">
        <thead>
          <tr>
            <th>Time</th>
            <th>From → To</th>
            <th>Payload</th>
            <th>Outcome</th>
            <th class="bloccs-num">Latency</th>
          </tr>
        </thead>
        <tbody>
          <%= for {e, idx} <- Enum.with_index(@events) do %>
            <tr
              class={["bloccs-row", "bloccs-feed__row", same?(e, @selected) && "is-selected"]}
              phx-click="inspect_msg"
              phx-value-idx={idx}
            >
              <td class="bloccs-feed__time">{time(e.at)}</td>
              <td class="bloccs-feed__edge">{edge(e)}</td>
              <td class="bloccs-feed__payload" title={payload_full(e)}>{payload(e)}</td>
              <td><.status_pill state={pill(e.outcome)} label={Atom.to_string(e.outcome)} /></td>
              <td class="bloccs-num">{Format.latency(e.duration_ms)}</td>
            </tr>
          <% end %>
        </tbody>
      </table>

      <p :if={@events == []} class="bloccs-empty">
        <strong>No messages yet.</strong>
        <span class="bloccs-muted">Send traffic through the network and it appears here live.</span>
      </p>

      <p :if={@events != [] and not @any_payload} class="bloccs-muted bloccs-hint">
        Payload contents are hidden. Enable capture with
        <code>config :bloccs, :inspect, enabled: true</code>
        (bloccs 0.3+).
      </p>

      <%!-- message inspector: a right-side drawer, so the live feed never pushes it --%>
      <div :if={@selected} class="bloccs-drawer-scrim" phx-click="close_msg" />
      <aside :if={@selected} class="bloccs-drawer" phx-window-keydown="msg_key">
        <header class="bloccs-drawer__head">
          <div class="bloccs-drawer__heading">
            <div class="bloccs-drawer__title">{edge(@selected)}</div>
            <div class="bloccs-drawer__sub">
              <.status_pill
                state={pill(@selected.outcome)}
                label={Atom.to_string(@selected.outcome)}
              />
              <span class="bloccs-muted">{Format.latency(@selected.duration_ms)}</span>
            </div>
          </div>
          <button type="button" class="bloccs-drawer__x" phx-click="close_msg" title="Close (Esc)">
            ×
          </button>
        </header>

        <div class="bloccs-drawer__body">
          <div class="bloccs-drawer__section">
            <h3>Details</h3>
            <div class="bloccs-kv">
              <span class="bloccs-muted">from</span><code>{from_label(@selected)}</code>
            </div>
            <div class="bloccs-kv">
              <span class="bloccs-muted">to</span><code>{to_label(@selected)}</code>
            </div>
            <div class="bloccs-kv">
              <span class="bloccs-muted">outcome</span><code>{@selected.outcome}</code>
            </div>
            <div class="bloccs-kv">
              <span class="bloccs-muted">latency</span>
              <code>{Format.latency(@selected.duration_ms)}</code>
            </div>
            <div class="bloccs-kv">
              <span class="bloccs-muted">at</span><code>{time(@selected.at)}</code>
            </div>
          </div>

          <div class="bloccs-drawer__section">
            <h3>Payload</h3>
            <pre class="bloccs-detail__payload">{payload_full(@selected) || "(payload capture disabled — config :bloccs, :inspect, enabled: true)"}</pre>
          </div>

          <div class="bloccs-drawer__section">
            <h3>Path</h3>
            <div class="bloccs-drawer__graph">
              <.graph
                network={@network}
                states={hop_states(@selected)}
                active_edges={hop_edge(@selected)}
                labels={false}
              />
            </div>
          </div>
        </div>

        <footer class="bloccs-drawer__nav">
          <button
            type="button"
            class="bloccs-btn bloccs-drawer__navbtn"
            phx-click="msg_nav"
            phx-value-dir="prev"
            disabled={@sel_idx in [nil, 0]}
          >
            ← Prev
          </button>
          <button
            type="button"
            class="bloccs-btn bloccs-drawer__navbtn"
            phx-click="msg_nav"
            phx-value-dir="next"
            disabled={@sel_idx == nil or @sel_idx >= length(@events) - 1}
          >
            Next →
          </button>
        </footer>
      </aside>
    </section>
    """
  end

  @doc "Filter flow events by node and outcome (used by the panel and the live view)."
  def filtered(events, %{node: node, outcome: outcome}) do
    events
    |> reject_blank(:node, node, fn e, v -> to_string(e.node) == v end)
    |> reject_blank(:outcome, outcome, fn e, v -> outcome_class(e.outcome) == v end)
  end

  def filtered(events, _), do: events

  @doc "Whether a flow event is the currently-selected one (stable across live updates)."
  def same?(_e, nil), do: false

  def same?(e, s),
    do: e.at == s.at and e.node == s.node and e.out_port == s.out_port

  defp reject_blank(events, _key, v, _match) when v in [nil, ""], do: events
  defp reject_blank(events, _key, v, match), do: Enum.filter(events, &match.(&1, v))

  defp outcome_class(:ok), do: "ok"
  defp outcome_class(o) when o in [:dropped, :skipped], do: "dropped"
  defp outcome_class(_), do: "failed"

  defp node_ids(%{nodes: nodes}), do: nodes |> Enum.map(& &1.id) |> Enum.sort()

  defp payload(%{payload: p}) when is_binary(p), do: strip_map(p)
  defp payload(_), do: "—"

  defp payload_full(%{payload: p}) when is_binary(p), do: p
  defp payload_full(_), do: nil

  defp strip_map("%{" <> rest = full) do
    if String.ends_with?(rest, "}"), do: binary_part(rest, 0, byte_size(rest) - 1), else: full
  end

  defp strip_map(other), do: other

  # Highlight the from/to nodes of this hop on the mini-topology.
  defp hop_states(%{node: n, to: {tn, _tp}}), do: %{n => :running, tn => :running}
  defp hop_states(%{node: n}), do: %{n => :running}

  defp hop_edge(%{node: n, to: {tn, _tp}}), do: MapSet.new([{n, tn}])
  defp hop_edge(_), do: MapSet.new()

  defp edge(%{out_port: nil, node: node}), do: "#{node}"
  defp edge(%{node: node, out_port: port, to: nil}), do: "#{node}.#{port} → ·"
  defp edge(%{node: node, out_port: port, to: {tn, tp}}), do: "#{node}.#{port} → #{tn}.#{tp}"

  defp from_label(%{node: n, out_port: nil}), do: "#{n}"
  defp from_label(%{node: n, out_port: p}), do: "#{n}.#{p}"

  defp to_label(%{to: {tn, tp}}), do: "#{tn}.#{tp}"
  defp to_label(_), do: "·"

  defp pill(:ok), do: :ok
  defp pill(o) when o in [:dropped, :skipped], do: :idle
  defp pill(_), do: :failed

  defp time(ms) do
    ms
    |> DateTime.from_unix!(:millisecond)
    |> Calendar.strftime("%H:%M:%S")
    |> Kernel.<>("." <> (ms |> rem(1000) |> Integer.to_string() |> String.pad_leading(3, "0")))
  end
end
