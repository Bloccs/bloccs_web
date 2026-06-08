defmodule Bloccs.Web.Panels.Networks do
  @moduledoc """
  Panel 1 — the overview list of every running network
  (`Bloccs.Introspect.list_networks/0`), each row linking into its topology and
  carrying live stats: a throughput sparkline + rate, error count, and uptime.
  Pure presentation; data (the list plus live `stats`) is loaded by
  `Bloccs.Web.DashboardLive` and passed in.
  """

  use Bloccs.Web, :html

  import Bloccs.Web.Components.Chart

  alias Bloccs.Web.{Format, Paths}

  attr :networks, :list, required: true
  attr :base_path, :string, required: true
  attr :now, :integer, required: true
  attr :stats, :map, default: %{}

  def render(assigns) do
    ~H"""
    <section class="bloccs-networks">
      <header class="bloccs-panel__header">
        <h1>Networks</h1>
        <span class="bloccs-muted">{count_label(@networks)}</span>
      </header>

      <table :if={@networks != []} class="bloccs-table bloccs-net-table">
        <thead>
          <tr>
            <th>Network</th>
            <th class="bloccs-num">Version</th>
            <th>Throughput</th>
            <th class="bloccs-num">Nodes</th>
            <th class="bloccs-num">Edges</th>
            <th class="bloccs-num" title="In-flight request/response calls (Bloccs.call · cast)">
              In-flight
            </th>
            <th class="bloccs-num">Errors</th>
            <th class="bloccs-num">Uptime</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={n <- @networks} class="bloccs-row">
            <td>
              <.link navigate={Paths.topology(@base_path, n.id)} class="bloccs-link bloccs-net-name">
                <span class={["bloccs-dot", rate(@stats, n.id) > 0 && "bloccs-dot--live"]} />
                {n.id}
              </.link>
            </td>
            <td class="bloccs-num bloccs-muted">{n.version}</td>
            <td>
              <span class="bloccs-tp">
                <.sparkline values={series(@stats, n.id)} />
                <span class="bloccs-tp__rate">{Format.rate(rate(@stats, n.id))}</span>
              </span>
            </td>
            <td class="bloccs-num">{n.node_count}</td>
            <td class="bloccs-num">{n.edge_count}</td>
            <td class={["bloccs-num", inflight(@stats, n.id) > 0 && "bloccs-num--live"]}>
              {inflight(@stats, n.id)}
            </td>
            <td class={["bloccs-num", errors(@stats, n.id) > 0 && "bloccs-num--error"]}>
              {errors(@stats, n.id)}
            </td>
            <td class="bloccs-num bloccs-muted">{Format.uptime(n.started_at, @now)}</td>
          </tr>
        </tbody>
      </table>

      <div :if={@networks == []} class="bloccs-empty">
        <p><strong>No running networks.</strong></p>
        <p class="bloccs-muted">
          Start a compiled network (e.g. <code>mix bloccs.run</code>) and it appears here.
          Networks built with bloccs &lt; 0.2 must be recompiled to be discoverable.
        </p>
      </div>
    </section>
    """
  end

  defp rate(stats, id), do: get_in(stats, [id, :rate]) || 0
  defp errors(stats, id), do: get_in(stats, [id, :errors]) || 0
  defp inflight(stats, id), do: get_in(stats, [id, :in_flight]) || 0
  defp series(stats, id), do: get_in(stats, [id, :series]) || []

  defp count_label([_]), do: "1 running"
  defp count_label(list), do: "#{length(list)} running"
end
