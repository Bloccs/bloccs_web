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

  alias Bloccs.Introspect
  alias Bloccs.Web.{Access, Paths}
  alias Bloccs.Web.Panels

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
     assign(socket,
       page_title: "bloccs",
       network: nil,
       networks: [],
       node_states: %{},
       frame: %{nodes: %{}, updated_at: nil},
       coverage: nil
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply,
     socket
     |> assign(:now, System.monotonic_time(:millisecond))
     |> assign(:page_title, page_title(socket.assigns.live_action, params))
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
    assign(socket, :networks, Introspect.list_networks())
  end

  defp load_panel(socket, action, params) when action in [:topology, :metrics, :coverage] do
    case fetch_network(params["network"]) do
      {:ok, network} -> assign(socket, :network, network)
      :error -> assign(socket, :network, nil)
    end
  end

  defp fetch_network(nil), do: :error

  defp fetch_network(id) when is_binary(id) do
    Introspect.network(String.to_existing_atom(id))
  rescue
    ArgumentError -> :error
  end

  # ---- rendering dispatch ----

  defp panel_body(%{live_action: :networks} = assigns) do
    ~H"""
    <Panels.Networks.render networks={@networks} base_path={@base_path} now={@now} />
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
    <Panels.Topology.render network={@network} base_path={@base_path} states={@node_states} />
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
      <.link navigate={Paths.networks(@base_path)} class="bloccs-brand">bloccs</.link>
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
