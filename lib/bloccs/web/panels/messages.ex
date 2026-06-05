defmodule Bloccs.Web.Panels.Messages do
  @moduledoc """
  Panel 5 — packages moving through the network. A live throughput chart over the
  per-second `Bloccs.Web.Telemetry.Flow` buckets, plus a scrolling feed of recent
  message events: each edge a message crossed (`from.port → to.port`), its
  outcome, the emitting node's latency, and — when `Bloccs.Inspect` capture is
  enabled (bloccs 0.3+) — a bounded, redacted snapshot of the payload.
  Filterable by node and outcome.
  """

  use Bloccs.Web, :html

  import Bloccs.Web.Components.Chart

  alias Bloccs.Web.Format

  attr :network, :any, required: true
  attr :base_path, :string, required: true
  attr :flow, :map, default: %{events: [], series: [], rate: 0}
  attr :filters, :map, default: %{node: nil, outcome: nil}

  def render(assigns) do
    events = filter(assigns.flow.events, assigns.filters)

    assigns =
      assigns
      |> assign(:events, events)
      |> assign(:any_payload, Enum.any?(events, & &1[:payload]))

    ~H"""
    <section class="bloccs-messages">
      <header class="bloccs-panel__header">
        <h1>Messages</h1>
        <span class="bloccs-muted">
          <span class="bloccs-live">●</span> live · {@flow.rate}/s
        </span>
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
          <tr :for={e <- @events} class="bloccs-row">
            <td class="bloccs-feed__time">{time(e.at)}</td>
            <td class="bloccs-feed__edge">{edge(e)}</td>
            <td class="bloccs-feed__payload">{payload(e)}</td>
            <td><.status_pill state={pill(e.outcome)} label={Atom.to_string(e.outcome)} /></td>
            <td class="bloccs-num">{Format.latency(e.duration_ms)}</td>
          </tr>
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
    </section>
    """
  end

  defp filter(events, %{node: node, outcome: outcome}) do
    events
    |> reject_blank(:node, node, fn e, v -> to_string(e.node) == v end)
    |> reject_blank(:outcome, outcome, fn e, v -> outcome_class(e.outcome) == v end)
  end

  defp reject_blank(events, _key, v, _match) when v in [nil, ""], do: events
  defp reject_blank(events, _key, v, match), do: Enum.filter(events, &match.(&1, v))

  defp outcome_class(:ok), do: "ok"
  defp outcome_class(o) when o in [:dropped, :skipped], do: "dropped"
  defp outcome_class(_), do: "failed"

  defp node_ids(%{nodes: nodes}), do: nodes |> Enum.map(& &1.id) |> Enum.sort()

  defp payload(%{payload: p}) when is_binary(p), do: p
  defp payload(_), do: "—"

  defp edge(%{out_port: nil, node: node}), do: "#{node}"
  defp edge(%{node: node, out_port: port, to: nil}), do: "#{node}.#{port} → ·"
  defp edge(%{node: node, out_port: port, to: {tn, tp}}), do: "#{node}.#{port} → #{tn}.#{tp}"

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
