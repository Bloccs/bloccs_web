import Config

# A headless endpoint for Phoenix.LiveViewTest. `server: false` — tests dispatch
# through the router via Plug, no HTTP listener.
config :bloccs_web, Bloccs.Web.Test.Endpoint,
  url: [host: "localhost"],
  secret_key_base: String.duplicate("bloccs", 12),
  live_view: [signing_salt: "test-salt-1234"],
  pubsub_server: Bloccs.Web.PubSub,
  server: false

config :logger, level: :warning
config :phoenix, :plug_init_mode, :runtime
