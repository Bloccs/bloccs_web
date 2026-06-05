import Config

# Dev-only asset toolchain. These profiles build the committed bundles in
# priv/static/assets; they are never needed by a host app consuming the package.
config :esbuild,
  version: "0.21.5",
  bloccs_web: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :tailwind,
  version: "3.4.4",
  bloccs_web: [
    args:
      ~w(--config=tailwind.config.js --input=css/app.css --output=../priv/static/assets/app.css --minify),
    cd: Path.expand("../assets", __DIR__)
  ]

import_config "#{config_env()}.exs"
