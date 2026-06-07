defmodule Bloccs.Web.Panels.Metrics do
  @moduledoc """
  Panel 3 — live per-node metrics. One row per node from the latest collector
  `frame`: a throughput sparkline + rate, a visual p50/p95 latency bar, completed
  count, and error rate, with a state pill. A totals row sums the network. The
  frame arrives on a 1 Hz PubSub tick handled by `Bloccs.Web.DashboardLive`; idle
  nodes show "—" until traffic flows.
  """

  use Bloccs.Web, :html

  import Bloccs.Web.Components.Chart

  alias Bloccs.Web.Format

  attr :network, :any, required: true
  attr :base_path, :string, required: true
  attr :frame, :map, default: %{nodes: %{}, updated_at: nil}

  def render(assigns) do
    rows = rows(assigns.network, assigns.frame)

    assigns =
      assigns
      |> assign(:rows, rows)
      |> assign(:max_p95, max_of(rows, :p95))
      |> assign(:totals, totals(rows))

    ~H"""
    <section class="bloccs-metrics">
      <header class="bloccs-panel__header">
        <h1>Live metrics</h1>
        <span class="bloccs-muted">{header_note(@frame)}</span>
      </header>

      <table class="bloccs-table bloccs-metrics-table">
        <thead>
          <tr>
            <th>Node</th>
            <th>State</th>
            <th class="bloccs-num">Throughput</th>
            <th>Latency (p50 · p95)</th>
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
            <td class="bloccs-num">
              <span class="bloccs-tp">
                <.sparkline values={series(m)} />
                <span class="bloccs-tp__rate">{Format.rate(m && m.throughput)}</span>
              </span>
            </td>
            <td>
              <%= if m && m.p95 do %>
                <div
                  class="bloccs-lat"
                  title={"p50 #{Format.latency(m.p50)} · p95 #{Format.latency(m.p95)}"}
                >
                  <span class="bloccs-lat__track">
                    <span class="bloccs-lat__fill" style={"width:#{pct(m.p95, @max_p95)}%"}></span>
                    <span class="bloccs-lat__p50" style={"left:#{pct(m.p50, @max_p95)}%"}></span>
                  </span>
                  <span class="bloccs-lat__txt">
                    {Format.latency(m.p50)} · {Format.latency(m.p95)}
                  </span>
                </div>
              <% else %>
                <span class="bloccs-muted">—</span>
              <% end %>
            </td>
            <td class="bloccs-num">{Format.count(m && m.completed)}</td>
            <td class={["bloccs-num", error_class(m)]}>{errors(m)}</td>
          </tr>
        </tbody>
        <tfoot>
          <tr class="bloccs-metrics-total">
            <td>Total</td>
            <td></td>
            <td class="bloccs-num">{Format.rate(@totals.throughput)}</td>
            <td></td>
            <td class="bloccs-num">{Format.count(@totals.completed)}</td>
            <td class={["bloccs-num", @totals.errors > 0 && "bloccs-num--error"]}>
              {@totals.errors}
            </td>
          </tr>
        </tfoot>
      </table>

      <p class="bloccs-muted bloccs-hint">
        Updates live as messages flow through the network (1 Hz). Sparklines cover the last 10s.
      </p>
    </section>
    """
  end

  defp rows(network, frame) do
    Enum.map(network.nodes, fn node -> {node, Map.get(frame.nodes, node.id)} end)
  end

  defp series(nil), do: []
  defp series(m), do: Map.get(m, :series, [])

  defp max_of(rows, key) do
    rows
    |> Enum.map(fn {_n, m} -> (m && Map.get(m, key)) || 0 end)
    |> Enum.max(fn -> 0 end)
    |> max(1)
    |> Kernel.*(1.0)
  end

  defp totals(rows) do
    Enum.reduce(rows, %{throughput: 0.0, completed: 0, errors: 0}, fn {_n, m}, acc ->
      if m do
        %{
          throughput: acc.throughput + m.throughput,
          completed: acc.completed + m.completed,
          errors: acc.errors + m.errors
        }
      else
        acc
      end
    end)
  end

  defp pct(_v, max) when max in [0, 0.0], do: 0
  defp pct(v, max), do: min(100, round(v / max * 100))

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
