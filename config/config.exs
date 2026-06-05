import Config

# Asset toolchain (esbuild + tailwind) is configured per-env in dev.exs, since
# both are dev-only deps — configuring them here would warn in test/prod.

import_config "#{config_env()}.exs"
