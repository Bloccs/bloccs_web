defmodule Bloccs.Web.Application do
  @moduledoc """
  The dashboard's own OTP application. Starts a private `Phoenix.PubSub` (so the
  dashboard never has to share the host's) and the telemetry `Collector` that
  folds the `[:bloccs, …]` stream into per-network rolling windows.

  Auto-starts on boot. Opt out (e.g. to supervise it yourself) with:

      config :bloccs_web, auto_start: false
  """

  use Application

  @impl true
  def start(_type, _args) do
    children =
      if Application.get_env(:bloccs_web, :auto_start, true) do
        [
          {Phoenix.PubSub, name: Bloccs.Web.PubSub},
          Bloccs.Web.Telemetry.Collector
        ]
      else
        []
      end

    Supervisor.start_link(children, strategy: :one_for_one, name: Bloccs.Web.Supervisor)
  end
end
