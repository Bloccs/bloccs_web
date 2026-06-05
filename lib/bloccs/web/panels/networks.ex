defmodule Bloccs.Web.Panels.Networks do
  @moduledoc """
  Panel 1 — the list of every running network (`Bloccs.Introspect.list_networks/0`),
  each row linking into its topology. Pure presentation; data is loaded by
  `Bloccs.Web.DashboardLive` and passed in.
  """

  use Bloccs.Web, :html

  alias Bloccs.Web.{Format, Paths}

  attr :networks, :list, required: true
  attr :base_path, :string, required: true
  attr :now, :integer, required: true

  def render(assigns) do
    ~H"""
    <section class="bloccs-networks">
      <header class="bloccs-panel__header">
        <h1>Networks</h1>
        <span class="bloccs-muted">{count_label(@networks)}</span>
      </header>

      <table :if={@networks != []} class="bloccs-table">
        <thead>
          <tr>
            <th>Network</th>
            <th>Version</th>
            <th class="bloccs-num">Nodes</th>
            <th class="bloccs-num">Edges</th>
            <th class="bloccs-num">Uptime</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={n <- @networks} class="bloccs-row">
            <td>
              <.link navigate={Paths.topology(@base_path, n.id)} class="bloccs-link">
                {n.id}
              </.link>
            </td>
            <td class="bloccs-muted">{n.version}</td>
            <td class="bloccs-num">{n.node_count}</td>
            <td class="bloccs-num">{n.edge_count}</td>
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

  defp count_label([_]), do: "1 running"
  defp count_label(list), do: "#{length(list)} running"
end
