# Runnable dev harness for the bloccs dashboard.
#
#     mix dev      # then open http://localhost:4000/bloccs
#
# Boots a standalone Phoenix endpoint with the dashboard mounted, compiles and
# starts a sample `orders` network, and drives a trickle of traffic so the live
# metrics and topology light up. Not shipped in the Hex package (see `files:`).

require Logger
Logger.configure(level: :info)

port = String.to_integer(System.get_env("PORT", "4000"))

bind_ip =
  case System.get_env("BIND", "0.0.0.0") |> String.split(".") |> Enum.map(&String.to_integer/1) do
    [a, b, c, d] -> {a, b, c, d}
    _ -> {0, 0, 0, 0}
  end

Application.put_env(:bloccs_web, BloccsWebDev.Endpoint,
  url: [host: "localhost"],
  # Bind all interfaces (not just 127.0.0.1) so the port is reachable when the
  # server runs in a VM/container and the browser is on the host. Override the
  # bind address with BIND=127.0.0.1 if you want loopback-only.
  http: [ip: bind_ip, port: port],
  adapter: Bandit.PhoenixAdapter,
  server: true,
  check_origin: false,
  debug_errors: true,
  code_reloader: false,
  secret_key_base: String.duplicate("bloccs-dev", 7),
  live_view: [signing_salt: "bloccs-dev-salt-01"],
  pubsub_server: Bloccs.Web.PubSub
)

defmodule BloccsWebDev.PageController do
  use Phoenix.Controller, formats: [:html]
  def index(conn, _params), do: redirect(conn, to: "/bloccs")
end

defmodule BloccsWebDev.Router do
  use Phoenix.Router
  import Phoenix.LiveView.Router
  import Bloccs.Web.Router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_secure_browser_headers)
  end

  scope "/" do
    pipe_through(:browser)
    get("/", BloccsWebDev.PageController, :index)
    bloccs_dashboard("/bloccs")
  end
end

defmodule BloccsWebDev.Endpoint do
  use Phoenix.Endpoint, otp_app: :bloccs_web

  @session_options [store: :cookie, key: "_bloccs_web_dev", signing_salt: "bloccs-dev-salt-01"]

  socket("/live", Phoenix.LiveView.Socket)

  plug(Plug.Session, @session_options)
  plug(BloccsWebDev.Router)
end

# --- sample network ---------------------------------------------------------

Code.require_file("dev/nodes.ex")
:ok = BloccsWebDev.Schemas.register()

network_path = "dev/fixtures/networks/orders.bloccs"
{:ok, network} = Bloccs.Parser.parse_network(network_path)
:ok = Bloccs.Validator.validate_network(network)
{:ok, orders_sup} = Bloccs.Compiler.compile_and_load(network)

{:ok, _} =
  Supervisor.start_link(
    [BloccsWebDev.Endpoint, orders_sup],
    strategy: :one_for_one
  )

# --- traffic generator ------------------------------------------------------
# A trickle of orders so the metrics and topology animate. Mostly "known" types
# (routed to fulfill → archive); a few "legacy" ones fall through to deadletter.

ingest = Bloccs.Router.producer_name(:orders, :ingest, :request)
types = ~w(retail wholesale subscription retail retail legacy)

spawn(fn ->
  Stream.iterate(1, &(&1 + 1))
  |> Enum.each(fn i ->
    payload = %{id: "ord-#{i}", type: Enum.random(types), amount: Enum.random(10..500)}
    Bloccs.Producer.push(ingest, payload, %{})
    Process.sleep(Enum.random(400..900))
  end)
end)

IO.puts("""

  ┌────────────────────────────────────────────────────────────┐
  │  bloccs dashboard is up                                     │
  │  →  http://localhost:#{port}/bloccs                              │
  │                                                            │
  │  A sample `orders` network is live with a trickle of       │
  │  traffic. Wait for THIS message before opening the browser │
  │  (the first run compiles deps and can take a minute).      │
  │  Set PORT=… if #{port} is busy.  Ctrl+C twice to stop.       │
  └────────────────────────────────────────────────────────────┘
""")
