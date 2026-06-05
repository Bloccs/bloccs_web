defmodule Bloccs.Web.DashboardLive do
  @moduledoc """
  The single LiveView behind every dashboard panel. `live_action` selects the
  panel (`:networks`, `:topology`, `:metrics`, `:coverage`) — the oban_web
  pattern — so navigation never remounts.

  **P0 status:** this is the empty shell. It resolves the user/access/features
  through the configured `Bloccs.Web.Resolver`, renders the chrome and an empty
  panel body, and is the seam each later phase (P2–P5) fills in. No data is read
  from the runtime yet.
  """

  use Bloccs.Web, :live_view

  alias Bloccs.Web.Access

  @doc """
  `on_mount` hook installed by `bloccs_dashboard/2`: stash the configured
  resolver and the resolved user/access/features on the socket before the panel
  mounts, so every panel sees the same Pro-gating context.
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

    case access do
      {:forbidden, reason} -> {:halt, redirect_forbidden(socket, reason)}
      _ -> {:cont, socket}
    end
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "bloccs")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply,
     socket
     |> assign(:network_id, params["network"])
     |> assign(:page_title, page_title(socket.assigns.live_action, params))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bloccs-dashboard" data-access={inspect(@bloccs_access)}>
      <.panel_nav active={@live_action} network_id={@network_id} features={@bloccs_features} />

      <main class="bloccs-panel">
        <.panel_body
          action={@live_action}
          network_id={@network_id}
          features={@bloccs_features}
        />
      </main>
    </div>
    """
  end

  # ---- chrome (function components; panel bodies land in P2–P5) ----

  attr :active, :atom, required: true
  attr :network_id, :string, default: nil
  attr :features, :any, required: true

  defp panel_nav(assigns) do
    ~H"""
    <nav class="bloccs-nav">
      <span class="bloccs-brand">bloccs</span>
      <.nav_link active={@active} action={:networks} label="Networks" />
      <.nav_link :if={@network_id} active={@active} action={:topology} label="Topology" />
      <.nav_link
        :if={@network_id and Access.enabled?(:metrics, @features)}
        active={@active}
        action={:metrics}
        label="Metrics"
      />
      <.nav_link
        :if={@network_id and Access.enabled?(:coverage, @features)}
        active={@active}
        action={:coverage}
        label="Coverage"
      />
    </nav>
    """
  end

  attr :active, :atom, required: true
  attr :action, :atom, required: true
  attr :label, :string, required: true

  defp nav_link(assigns) do
    ~H"""
    <span class={["bloccs-nav__link", @active == @action && "bloccs-nav__link--active"]}>
      {@label}
    </span>
    """
  end

  attr :action, :atom, required: true
  attr :network_id, :string, default: nil
  attr :features, :any, required: true

  defp panel_body(assigns) do
    ~H"""
    <section class="bloccs-empty">
      <p>
        <strong>{panel_title(@action)}</strong> — coming online.
        This panel is the P0 shell; data wiring lands in a later phase.
      </p>
    </section>
    """
  end

  defp panel_title(:networks), do: "Networks"
  defp panel_title(:topology), do: "Topology"
  defp panel_title(:metrics), do: "Live metrics"
  defp panel_title(:coverage), do: "Coverage"

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
