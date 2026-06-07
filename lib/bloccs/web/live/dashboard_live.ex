defmodule Bloccs.Web.DashboardLive do
  @moduledoc """
  The single LiveView behind every dashboard panel. `live_action` selects the
  panel (`:networks`, `:topology`, `:metrics`, `:coverage`) — the oban_web
  pattern — so navigation never remounts.

  It loads the read-only `Bloccs.Introspect` data each panel needs in
  `handle_params`, resolves the Pro-gating context `on_mount`, and dispatches
  rendering to the per-panel function components in `Bloccs.Web.Panels.*`. Live
  telemetry (P4) is layered on top via PubSub.
  """

  use Bloccs.Web, :live_view

  alias Bloccs.{Introspect, Trace}
  alias Bloccs.Web.{Access, Coverage, Paths}
  alias Bloccs.Web.Panels
  alias Bloccs.Web.Telemetry.Collector

  @pubsub Bloccs.Web.PubSub

  @doc """
  `on_mount` hook installed by `bloccs_dashboard/2`: stash the configured
  resolver, the resolved user/access/features, and the mount base path on the
  socket before any panel renders.
  """
  def on_mount({:resolver, resolver}, _params, session, socket) do
    user = call_resolver(resolver, :resolve_user, [session], nil)
    access = call_resolver(resolver, :resolve_access, [user], :all)
    features = call_resolver(resolver, :resolve_features, [user], :all)

    socket =
      socket
      |> Phoenix.Component.assign(:bloccs_resolver, resolver)
      |> Phoenix.Component.assign(:bloccs_user, user)
      |> Phoenix.Component.assign(:bloccs_access, access)
      |> Phoenix.Component.assign(:bloccs_features, features)
      |> Phoenix.Component.assign(:base_path, session["base_path"] || "/bloccs")

    case access do
      {:forbidden, reason} -> {:halt, redirect_forbidden(socket, reason)}
      _ -> {:cont, socket}
    end
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       page_title: "bloccs",
       network: nil,
       networks: [],
       node_states: %{},
       frame: %{nodes: %{}, updated_at: nil},
       metrics_topic: nil,
       flow: %{events: [], series: [], rate: 0},
       flow_topic: nil,
       flow_filters: %{node: nil, outcome: nil},
       coverage: nil,
       recording: nil,
       net_stats: %{},
       overview_ids: [],
       selected_msg: nil,
       inspect_node: nil,
       flow_paused: false
     )
     # `.bloccs-trace` has no registered MIME type, so accept :any and validate
     # the contents on load instead of by extension.
     |> allow_upload(:trace, accept: :any, max_entries: 1)}
  end

  @impl true
  def handle_info({:bloccs_frame, network, frame}, socket) do
    {:noreply, socket |> put_frame(frame) |> update_overview(network, frame: frame)}
  end

  def handle_info({:bloccs_flow, network, flow}, socket) do
    # Always fold into the overview stats; freeze the live feed when paused so the
    # user can inspect without rows scrolling away.
    socket = update_overview(socket, network, flow: flow)
    socket = if socket.assigns.flow_paused, do: socket, else: assign(socket, :flow, flow)
    {:noreply, socket}
  end

  @impl true
  def handle_event("flow_filter", params, socket) do
    filters = %{node: blank(params["node"]), outcome: blank(params["outcome"])}
    {:noreply, assign(socket, :flow_filters, filters)}
  end

  def handle_event("toggle_pause", _params, socket) do
    {:noreply, assign(socket, :flow_paused, not socket.assigns.flow_paused)}
  end

  def handle_event("close_msg", _params, socket) do
    {:noreply, assign(socket, :selected_msg, nil)}
  end

  def handle_event("inspect_msg", %{"idx" => idx}, socket) do
    events = Panels.Messages.filtered(socket.assigns.flow.events, socket.assigns.flow_filters)
    event = Enum.at(events, String.to_integer(idx))

    selected =
      if event && Panels.Messages.same?(event, socket.assigns.selected_msg), do: nil, else: event

    {:noreply, assign(socket, :selected_msg, selected)}
  end

  @impl true
  def handle_event("coverage_record", _params, %{assigns: %{network: net}} = socket)
      when not is_nil(net) do
    recording = Trace.record(net.id)
    {:noreply, assign(socket, :recording, recording)}
  end

  def handle_event("coverage_stop", _params, %{assigns: %{recording: rec}} = socket)
      when not is_nil(rec) do
    events = Trace.stop(rec)
    {:noreply, socket |> assign(:recording, nil) |> put_coverage(events, :recording)}
  end

  def handle_event("coverage_validate", _params, socket), do: {:noreply, socket}

  def handle_event("coverage_load", _params, socket) do
    case consume_uploaded_entries(socket, :trace, fn %{path: path}, _entry ->
           {:ok, Trace.load(path)}
         end) do
      [{:ok, events}] -> {:noreply, put_coverage(socket, events, :trace)}
      _ -> {:noreply, socket}
    end
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  @impl true
  def terminate(_reason, socket) do
    if rec = socket.assigns[:recording], do: Trace.stop(rec)
    :ok
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply,
     socket
     |> assign(:now, System.monotonic_time(:millisecond))
     |> assign(:page_title, page_title(socket.assigns.live_action, params))
     |> assign(:flow_filters, %{node: blank(params["node"]), outcome: blank(params["outcome"])})
     |> assign(:selected_msg, nil)
     |> assign(:inspect_node, blank(params["node"]))
     |> assign(:flow_paused, false)
     |> load_panel(socket.assigns.live_action, params)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bloccs-dashboard" data-access={inspect(@bloccs_access)}>
      <.panel_nav
        active={@live_action}
        base_path={@base_path}
        network={@network}
        features={@bloccs_features}
      />

      <main class="bloccs-panel">
        <.panel_body {assigns} />
      </main>
    </div>
    """
  end

  # ---- data loading per panel ----

  defp load_panel(socket, :networks, _params) do
    networks = Introspect.list_networks()

    socket
    |> assign(:networks, networks)
    |> assign(:net_stats, Map.new(networks, &{&1.id, net_stat(&1.id)}))
    |> subscribe_overview(networks)
  end

  defp load_panel(socket, action, params)
       when action in [:topology, :messages, :metrics, :coverage] do
    case fetch_network(params["network"]) do
      {:ok, network} ->
        socket
        |> assign(:network, network)
        |> maybe_subscribe(action, network)

      :error ->
        assign(socket, :network, nil)
    end
  end

  # ---- networks overview (live cards) ----

  # Subscribe to every network's flow + metric topics so the overview cards stay
  # live. Re-entrant: unsubscribe the previous set before subscribing the new one.
  defp subscribe_overview(socket, networks) do
    if connected?(socket) do
      ids = Enum.map(networks, & &1.id)
      Enum.each(socket.assigns.overview_ids -- ids, &unsubscribe_overview/1)
      Enum.each(ids -- socket.assigns.overview_ids, &subscribe_one_overview/1)
      assign(socket, :overview_ids, ids)
    else
      socket
    end
  end

  defp subscribe_one_overview(id) do
    Phoenix.PubSub.subscribe(@pubsub, Collector.flow_topic(id))
    Phoenix.PubSub.subscribe(@pubsub, Collector.topic(id))
  end

  defp unsubscribe_overview(id) do
    Phoenix.PubSub.unsubscribe(@pubsub, Collector.flow_topic(id))
    Phoenix.PubSub.unsubscribe(@pubsub, Collector.topic(id))
  end

  defp net_stat(id) do
    frame = Collector.snapshot(id)
    flow = Collector.flow_snapshot(id)
    %{rate: flow.rate, series: series_totals(flow.series), errors: total_errors(frame)}
  end

  defp series_totals(series), do: Enum.map(series, &Map.get(&1, :total, 0))

  defp total_errors(%{nodes: nodes}),
    do: nodes |> Map.values() |> Enum.map(&Map.get(&1, :errors, 0)) |> Enum.sum()

  defp total_errors(_), do: 0

  # Fold a live frame into the overview stats for that network (no-op if the
  # network isn't on the currently-loaded overview).
  defp update_overview(socket, network, change) do
    stats = socket.assigns.net_stats

    case Map.fetch(stats, network) do
      {:ok, cur} ->
        updated =
          case change do
            [flow: flow] -> %{cur | rate: flow.rate, series: series_totals(flow.series)}
            [frame: frame] -> %{cur | errors: total_errors(frame)}
          end

        assign(socket, :net_stats, Map.put(stats, network, updated))

      :error ->
        socket
    end
  end

  # The live topology reads both metric frames (node state + throughput) and the
  # flow snapshot (which edges are active), so it subscribes to both.
  defp maybe_subscribe(socket, :topology, network),
    do: socket |> subscribe_metrics(network) |> subscribe_flow(network)

  defp maybe_subscribe(socket, :metrics, network), do: subscribe_metrics(socket, network)
  defp maybe_subscribe(socket, :messages, network), do: subscribe_flow(socket, network)
  defp maybe_subscribe(socket, _action, _network), do: socket

  # Subscribe to the network's flow frames and prime the first paint.
  defp subscribe_flow(socket, network) do
    if connected?(socket) do
      topic = Collector.flow_topic(network.id)

      if socket.assigns[:flow_topic] != topic do
        if old = socket.assigns[:flow_topic], do: Phoenix.PubSub.unsubscribe(@pubsub, old)
        Phoenix.PubSub.subscribe(@pubsub, topic)
      end

      socket
      |> assign(:flow_topic, topic)
      |> assign(:flow, Collector.flow_snapshot(network.id))
    else
      socket
    end
  end

  # Subscribe to the network's metric frames (idempotently) and prime the first
  # paint from the collector snapshot. No-op until the socket is connected.
  defp subscribe_metrics(socket, network) do
    if connected?(socket) do
      topic = Collector.topic(network.id)

      if socket.assigns[:metrics_topic] != topic do
        if old = socket.assigns[:metrics_topic], do: Phoenix.PubSub.unsubscribe(@pubsub, old)
        Phoenix.PubSub.subscribe(@pubsub, topic)
      end

      socket
      |> assign(:metrics_topic, topic)
      |> put_frame(Collector.snapshot(network.id))
    else
      socket
    end
  end

  defp put_frame(socket, frame) do
    socket
    |> assign(:frame, frame)
    |> assign(:node_states, node_states(frame))
  end

  defp node_states(%{nodes: nodes}), do: Map.new(nodes, fn {id, v} -> {id, v.state} end)
  defp node_states(_), do: %{}

  defp blank(v) when v in [nil, ""], do: nil
  defp blank(v), do: v

  # Build the coverage report from trace events and stash it (plus a re-encoded
  # .bloccs-trace for the gated export).
  defp put_coverage(socket, events, source) do
    network = socket.assigns.network
    report = Coverage.report(network, Trace.reached(events))

    assign(socket, :coverage, %{
      report: report,
      source: source,
      json: encode_trace(events, network.id)
    })
  end

  defp encode_trace(events, network_id) do
    path =
      Path.join(
        System.tmp_dir!(),
        "bloccs-#{network_id}-#{System.unique_integer([:positive])}.bloccs-trace"
      )

    case Trace.dump(events, network_id, path) do
      :ok ->
        json = File.read!(path)
        _ = File.rm(path)
        json

      _ ->
        nil
    end
  end

  defp fetch_network(nil), do: :error

  defp fetch_network(id) when is_binary(id) do
    # A network that was started (so its atom exists) but has since stopped
    # returns `{:error, :not_found}` — collapse it, and an unknown atom, to the
    # one `:error` the caller renders as the not-found panel.
    case Introspect.network(String.to_existing_atom(id)) do
      {:ok, network} -> {:ok, network}
      {:error, :not_found} -> :error
    end
  rescue
    ArgumentError -> :error
  end

  # ---- rendering dispatch ----

  defp panel_body(%{live_action: :networks} = assigns) do
    ~H"""
    <Panels.Networks.render
      networks={@networks}
      base_path={@base_path}
      now={@now}
      stats={@net_stats}
    />
    """
  end

  defp panel_body(%{network: nil} = assigns) do
    ~H"""
    <section class="bloccs-empty">
      <p><strong>Network not found.</strong></p>
      <p class="bloccs-muted">
        It may have stopped. <.link navigate={Paths.networks(@base_path)} class="bloccs-link">
          Back to networks</.link>.
      </p>
    </section>
    """
  end

  defp panel_body(%{live_action: :topology} = assigns) do
    ~H"""
    <Panels.Topology.render
      network={@network}
      base_path={@base_path}
      states={@node_states}
      frame={@frame}
      flow={@flow}
      selected={@inspect_node}
    />
    """
  end

  defp panel_body(%{live_action: :messages} = assigns) do
    ~H"""
    <Panels.Messages.render
      network={@network}
      base_path={@base_path}
      flow={@flow}
      filters={@flow_filters}
      selected={@selected_msg}
      paused={@flow_paused}
    />
    """
  end

  defp panel_body(%{live_action: :metrics} = assigns) do
    ~H"""
    <Panels.Metrics.render network={@network} base_path={@base_path} frame={@frame} />
    """
  end

  defp panel_body(%{live_action: :coverage} = assigns) do
    ~H"""
    <Panels.Coverage.render
      network={@network}
      base_path={@base_path}
      features={@bloccs_features}
      coverage={@coverage}
      recording={@recording != nil}
      upload={@uploads.trace}
    />
    """
  end

  # ---- chrome ----

  attr :active, :atom, required: true
  attr :base_path, :string, required: true
  attr :network, :any, default: nil
  attr :features, :any, required: true

  defp panel_nav(assigns) do
    ~H"""
    <nav class="bloccs-nav">
      <.link navigate={Paths.networks(@base_path)} class="bloccs-brand" aria-label="BloccsWeb">
        <img src={"#{@base_path}/assets/mark.svg"} alt="" class="bloccs-mark" />
        <span class="bloccs-wordmark"><span class="bloccs-wm-thin">Bloccs</span>Web</span>
      </.link>
      <.nav_link
        active={@active}
        action={:networks}
        href={Paths.networks(@base_path)}
        label="Networks"
      />
      <%= if @network do %>
        <span class="bloccs-nav__sep">/</span>
        <span class="bloccs-nav__network">{@network.id}</span>
        <.nav_link
          active={@active}
          action={:topology}
          href={Paths.topology(@base_path, @network.id)}
          label="Topology"
        />
        <.nav_link
          :if={Access.enabled?(:messages, @features)}
          active={@active}
          action={:messages}
          href={Paths.messages(@base_path, @network.id)}
          label="Messages"
        />
        <.nav_link
          :if={Access.enabled?(:metrics, @features)}
          active={@active}
          action={:metrics}
          href={Paths.metrics(@base_path, @network.id)}
          label="Metrics"
        />
        <.nav_link
          :if={Access.enabled?(:coverage, @features)}
          active={@active}
          action={:coverage}
          href={Paths.coverage(@base_path, @network.id)}
          label="Coverage"
        />
      <% end %>
    </nav>
    """
  end

  attr :active, :atom, required: true
  attr :action, :atom, required: true
  attr :href, :string, required: true
  attr :label, :string, required: true

  defp nav_link(assigns) do
    ~H"""
    <.link
      navigate={@href}
      class={["bloccs-nav__link", @active == @action && "bloccs-nav__link--active"]}
    >
      {@label}
    </.link>
    """
  end

  defp page_title(:networks, _), do: "bloccs · networks"
  defp page_title(action, %{"network" => net}), do: "bloccs · #{net} · #{action}"
  defp page_title(action, _), do: "bloccs · #{action}"

  # ---- resolver plumbing ----

  defp call_resolver(resolver, fun, args, default) do
    if function_exported?(resolver, fun, length(args)) do
      apply(resolver, fun, args)
    else
      default
    end
  end

  defp redirect_forbidden(socket, _reason) do
    Phoenix.LiveView.redirect(socket, to: "/")
  end
end
