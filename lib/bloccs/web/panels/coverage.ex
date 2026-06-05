defmodule Bloccs.Web.Panels.Coverage do
  @moduledoc """
  Panel 4 — structural coverage. Records a run (or loads a `.bloccs-trace`),
  derives the reached obligations with `Bloccs.Web.Coverage`, and overlays them
  on the topology graph (reached nodes/edges lit) alongside a summary bar and the
  list of unreached obligations. Trace export sits behind the `:trace_export`
  feature (the Pro seam) — enabled in the open build.
  """

  use Bloccs.Web, :html

  import Bloccs.Web.Components.Graph

  alias Bloccs.Web.{Access, Coverage}

  attr :network, :any, required: true
  attr :base_path, :string, required: true
  attr :features, :any, required: true
  attr :coverage, :any, default: nil
  attr :recording, :boolean, default: false
  attr :upload, :any, default: nil

  def render(assigns) do
    ~H"""
    <section class="bloccs-coverage">
      <header class="bloccs-panel__header">
        <h1>Coverage</h1>
        <span :if={@coverage} class="bloccs-muted">{source_label(@coverage.source)}</span>
      </header>

      <.controls recording={@recording} upload={@upload} coverage={@coverage} features={@features} />

      <%= if @coverage do %>
        <.summary report={@coverage.report} />
        <.graph
          network={@network}
          states={Coverage.node_states(@network, @coverage.report)}
          reached_edges={Coverage.reached_edges(@coverage.report)}
        />
        <.unreached report={@coverage.report} />
      <% else %>
        <div class="bloccs-empty">
          <p><strong>No coverage yet.</strong></p>
          <p class="bloccs-muted">
            Record a run while messages flow through the network, or load a <code>.bloccs-trace</code>
            file, to see which ports and edges were exercised.
          </p>
        </div>
      <% end %>
    </section>
    """
  end

  attr :recording, :boolean, required: true
  attr :upload, :any, required: true
  attr :coverage, :any, required: true
  attr :features, :any, required: true

  defp controls(assigns) do
    ~H"""
    <div class="bloccs-coverage__controls">
      <button :if={!@recording} class="bloccs-btn" phx-click="coverage_record">
        Record run
      </button>
      <button :if={@recording} class="bloccs-btn bloccs-btn--active" phx-click="coverage_stop">
        ■ Stop &amp; report
      </button>
      <span :if={@recording} class="bloccs-recording">● recording…</span>

      <form
        :if={@upload}
        class="bloccs-coverage__upload"
        phx-change="coverage_validate"
        phx-submit="coverage_load"
      >
        <.live_file_input upload={@upload} />
        <button type="submit" class="bloccs-btn">Load trace</button>
      </form>

      <.export coverage={@coverage} features={@features} />
    </div>
    """
  end

  attr :coverage, :any, required: true
  attr :features, :any, required: true

  defp export(assigns) do
    ~H"""
    <%= cond do %>
      <% is_nil(@coverage) or is_nil(@coverage[:json]) -> %>
        <span></span>
      <% Access.enabled?(:trace_export, @features) -> %>
        <a
          class="bloccs-btn"
          download="trace.bloccs-trace"
          href={"data:application/json;charset=utf-8,#{URI.encode(@coverage.json)}"}
        >
          Export .bloccs-trace
        </a>
      <% true -> %>
        <.pro_lock feature={:trace_export} />
    <% end %>
    """
  end

  attr :report, :map, required: true

  defp summary(assigns) do
    ~H"""
    <div class="bloccs-coverage__summary">
      <div class="bloccs-coverage__bar">
        <div class="bloccs-coverage__fill" style={"width:#{@report.percent}%"}></div>
      </div>
      <div class="bloccs-coverage__stat">
        <strong>{@report.percent}%</strong>
        <span class="bloccs-muted">
          {@report.reached_count} / {@report.total} obligations reached
        </span>
      </div>
    </div>
    """
  end

  attr :report, :map, required: true

  defp unreached(assigns) do
    ~H"""
    <div :if={@report.unreached != []} class="bloccs-coverage__unreached">
      <h2>Unreached ({length(@report.unreached)})</h2>
      <ul>
        <li :for={ob <- @report.unreached} class="bloccs-coverage__ob">
          {label(ob)}
        </li>
      </ul>
    </div>
    <p :if={@report.unreached == []} class="bloccs-coverage__complete">
      ✓ Full structural coverage — every port and edge was exercised.
    </p>
    """
  end

  defp label({:port_in, node, port}), do: "in · #{node}.#{port}"
  defp label({:port_out, node, port}), do: "out · #{node}.#{port}"
  defp label({:edge, {fn_, fp}, {tn, tp}}), do: "edge · #{fn_}.#{fp} → #{tn}.#{tp}"

  defp source_label(:recording), do: "from a recorded run"
  defp source_label(:trace), do: "from a loaded .bloccs-trace"
  defp source_label(_), do: ""
end
