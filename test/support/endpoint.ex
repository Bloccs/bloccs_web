defmodule Bloccs.Web.Test.Router do
  @moduledoc false
  use Phoenix.Router
  import Phoenix.LiveView.Router
  import Bloccs.Web.Router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:protect_from_forgery)
  end

  scope "/" do
    pipe_through(:browser)
    bloccs_dashboard("/bloccs")
  end
end

defmodule Bloccs.Web.Test.Endpoint do
  @moduledoc false
  use Phoenix.Endpoint, otp_app: :bloccs_web

  @session_options [
    store: :cookie,
    key: "_bloccs_web_test",
    signing_salt: "test-salt-1234",
    same_site: "Lax"
  ]

  socket("/live", Phoenix.LiveView.Socket)

  plug(Plug.Session, @session_options)
  plug(Bloccs.Web.Test.Router)
end
