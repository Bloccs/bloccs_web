defmodule Bloccs.Web do
  @moduledoc """
  bloccs_web — a self-hosted, real-time dashboard for running
  [bloccs](https://github.com/Bloccs/bloccs) networks.

  Mounted into a host Phoenix app with one router macro (see
  `Bloccs.Web.Router.bloccs_dashboard/2`), it reads the library's read-only
  `Bloccs.Introspect` API plus the `[:bloccs, …]` telemetry stream to show
  network topology in the bloccs hexagon notation, live per-node metrics, and
  coverage — without ever driving the runtime.

  This module also provides the `use Bloccs.Web, :live_view | :html` macros the
  dashboard's own modules use; it is self-contained so it never collides with
  the host's `MyAppWeb`.
  """

  @doc false
  def static_paths, do: ~w(assets fonts images favicon.ico)

  @doc false
  def live_view do
    quote do
      use Phoenix.LiveView, layout: {Bloccs.Web.Layouts, :app}
      unquote(html_helpers())
    end
  end

  @doc false
  def html do
    quote do
      use Phoenix.Component
      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      import Phoenix.HTML
      import Bloccs.Web.CoreComponents
      import Bloccs.Web.HexGlyph

      alias Phoenix.LiveView.JS
    end
  end

  @doc """
  When used, dispatch to the appropriate helper above
  (`use Bloccs.Web, :live_view`).
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
