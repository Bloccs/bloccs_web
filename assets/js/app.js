// bloccs_web dashboard JS — bundled by esbuild into priv/static/assets/app.js.
// Self-contained: brings its own Phoenix + LiveView socket so the host app needs
// no JS wiring.
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import { GraphLayout } from "./hooks/graph_layout"

const csrfToken = document
  .querySelector("meta[name='csrf-token']")
  ?.getAttribute("content")

const hooks = { GraphLayout }

const liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks,
})

liveSocket.connect()
window.liveSocket = liveSocket
