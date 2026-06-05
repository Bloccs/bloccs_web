# Changelog

All notable changes to `bloccs_web` are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Messages panel** — a live view of packages moving through a network. A
  server-rendered throughput chart over per-second buckets plus a scrolling feed
  of recent edge traversals (`from.port → to.port`), each with its outcome and
  the emitting node's latency, filterable by node and outcome. Built from the
  `[:bloccs, :emit]` + node telemetry: emits are correlated with their node's
  `:stop` in a per-process buffer in `Bloccs.Web.Telemetry.Handler`, folded by
  `Bloccs.Web.Telemetry.Flow`, and broadcast on `bloccs:flow:<net>`. Flow
  metadata only — payload contents are a future opt-in bloccs capability.
- **P2–P5 — the four live panels.** All read the v0.2.0 introspection API and the
  `[:bloccs, …]` telemetry stream; observe-only.
  - **Networks** — every running network with version, node/edge counts, and
    uptime (`Bloccs.Introspect.list_networks/0`), each row linking into topology.
  - **Topology** — the network DAG drawn in the bloccs hexagon notation, computed
    by a pure server-side layered layout (`Bloccs.Web.Topology.Layout`) and
    rendered as one SVG (`Bloccs.Web.Components.Graph`). Node state lights up live.
  - **Live metrics** — per-node throughput, p50/p95 latency, completed, and error
    rate on a 1 Hz rolling window. A telemetry handler folds the bloccs node
    events into `Bloccs.Web.Telemetry.Metrics` (pure core) in a single
    `Collector`, which broadcasts coalesced frames over PubSub; the topology
    glyphs light from the same frames.
  - **Coverage** — structural coverage (`Bloccs.Web.Coverage`) from a recorded run
    or a loaded `.bloccs-trace`: a summary bar, the reached/unreached overlay on
    the graph, and the unreached-obligation list. Trace export is gated by the
    `:trace_export` feature (the Pro seam) — available in the open build.
- **P0 — package skeleton and mount.** The dashboard mounts into a host Phoenix
  app and renders its empty shell:
  - `Bloccs.Web.Router.bloccs_dashboard/2` — the one-line router macro; a single
    `live_session` over the four panel routes (networks, topology, metrics,
    coverage), inheriting host auth from the surrounding pipeline.
  - `Bloccs.Web.Resolver` behaviour + `Bloccs.Web.Access` default resolver — the
    Pro-gating seam (`resolve_user/resolve_access/resolve_features` +
    `enabled?/2`). The free baseline enables every feature.
  - `Bloccs.Web.DashboardLive` — the single LiveView (one `live_action` per
    panel); P0 ships the chrome and empty panel bodies.
  - `Bloccs.Web.HexGlyph` — the bloccs hexagon notation as inline SVG, keyed by
    the atoms `Bloccs.Introspect.glyph/1` returns; live state is a CSS class.
  - `Bloccs.Web.Application` + `Bloccs.Web.Telemetry.Collector` — auto-starting
    OTP app with a private PubSub and the (P4) metrics collector, currently a
    no-op snapshot source.
  - Precompiled-asset packaging (the oban_web model): `assets/` is dev-only and
    excluded from the Hex package; the committed `priv/static/assets` bundles
    ship in the release.

> **Note:** requires `bloccs ~> 0.2`. Before that is on Hex, develop locally with
> a path override (`{:bloccs, path: "../bloccs"}`).
