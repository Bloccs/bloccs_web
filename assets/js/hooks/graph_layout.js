// GraphLayout — computes node coordinates and edge waypoints for the topology
// panel with dagre, then pushes them back to the server, which renders the SVG.
//
// P0: a stub that emits the contract (a `layout` event with positioned nodes and
// edges) from the data attributes the server provides. The dagre dependency and
// real layout land in P3 (topology panel). Kept thin on purpose — the dashboard
// graph is read-only, so there is no client-side animation framework.
export const GraphLayout = {
  mounted() {
    this.computeAndPush()
  },

  updated() {
    this.computeAndPush()
  },

  computeAndPush() {
    const spec = this.parseSpec()
    if (!spec) return
    // P3: run dagre over spec.nodes/spec.edges to produce coords + waypoints.
    this.pushEvent("layout", { nodes: spec.nodes, edges: spec.edges })
  },

  parseSpec() {
    try {
      return JSON.parse(this.el.dataset.graph || "null")
    } catch (_e) {
      return null
    }
  },
}
