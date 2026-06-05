defmodule Bloccs.Web.Panels.Metrics do
  @moduledoc """
  Panel 3 — live per-node metrics. Renders one row per node from the latest
  collector `frame` (throughput, p50/p95 latency, completed, error rate) with a
  state pill. The frame arrives on a 1 Hz PubSub tick handled by
  `Bloccs.Web.DashboardLive`; idle nodes show "—" until traffic flows.
  """

  use Bloccs.Web, :html

  alias Bloccs.Web.Format

  attr :network, :any, required: true
  attr :base_path, :string, required: true
  attr :frame, :map, default: %{nodes: %{}, updated_at: nil}

  def render(assigns) do
    assigns = assign(assigns, :rows, rows(assigns.network, assigns.frame))

    ~H"""
    <section class="bloccs-metrics">
      <header class="bloccs-panel__header">
        <h1>Live metrics</h1>
        <span class="bloccs-muted">{header_note(@frame)}</span>
      </header>

      <table class="bloccs-table">
        <thead>
          <tr>
            <th>Node</th>
            <th>State</th>
            <th class="bloccs-num">Throughput</th>
            <th class="bloccs-num">p50</th>
            <th class="bloccs-num">p95</th>
            <th class="bloccs-num">Completed</th>
            <th class="bloccs-num">Errors</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={{node, m} <- @rows} class="bloccs-row">
            <td>
              <span class="bloccs-node-id">
                <svg viewBox="-60 -62 120 120" width="20" height="20" class="bloccs-node-id__glyph">
                  <.hex_glyph glyph={node.glyph} state={state(m)} />
                </svg>
                {node.id}
              </span>
            </td>
            <td><.status_pill state={state(m)} /></td>
            <td class="bloccs-num">{Format.rate(m && m.throughput)}</td>
            <td class="bloccs-num">{Format.latency(m && m.p50)}</td>
            <td class="bloccs-num">{Format.latency(m && m.p95)}</td>
            <td class="bloccs-num">{Format.count(m && m.completed)}</td>
            <td class={["bloccs-num", error_class(m)]}>{errors(m)}</td>
          </tr>
        </tbody>
      </table>

      <p class="bloccs-muted bloccs-hint">
        Updates live as messages flow through the network (1 Hz). Idle nodes show "—".
      </p>
    </section>
    """
  end

  defp rows(network, frame) do
    Enum.map(network.nodes, fn node -> {node, Map.get(frame.nodes, node.id)} end)
  end

  defp state(nil), do: :idle
  defp state(%{state: state}), do: state

  defp errors(nil), do: "—"
  defp errors(%{errors: 0}), do: "0"
  defp errors(%{errors: n, completed: c}), do: "#{n} (#{Format.percent(safe_rate(n, c))})"

  defp error_class(%{errors: n}) when n > 0, do: "bloccs-num--error"
  defp error_class(_), do: nil

  defp safe_rate(_n, 0), do: 0.0
  defp safe_rate(n, c), do: n / c

  defp header_note(%{updated_at: nil}), do: "waiting for traffic"
  defp header_note(%{nodes: nodes}) when map_size(nodes) == 0, do: "waiting for traffic"
  defp header_note(_), do: "live"
end
