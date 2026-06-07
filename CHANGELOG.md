# Changelog

All notable changes to `bloccs_web` are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-06-07

Now requires `bloccs ~> 0.5` (per-message lineage + the introspect
contract/config fields the panels render).

### Added

- **Live topology map.** The Topology panel animates packets moving along active
  edges, with a summary strip and per-node hover stats. Clicking a node opens an
  inspector showing its primitive (kind, ports with schemas, effects), live
  metrics, and the **code** that implements it — `pure_core` / `effect_shell`
  refs plus retry / idempotency / batch / join / rate / delay policy (from
  `Bloccs.Introspect` contract/config, bloccs 0.4+).
- **Message journey.** Selecting a message in the Messages panel opens a
  right-side drawer that tracks it across the network via `bloccs` 0.5 lineage:
  the full path highlighted on a mini-graph, the ordered list of hops it took
  (branching/merging through split, batch, and join), and per-hop detail +
  payload. Prev/Next (and ↑/↓) walk the message's hops; the journey is
  snapshotted at selection so it never drifts as the live feed scrolls.
- **Network overview cards** on the Networks panel — per-network sparkline,
  rate, and error count.
- **Richer Metrics panel** and a Sentry-style per-second **throughput volume
  chart** (failures stacked) on Messages, with a **pause** control to freeze the
  live feed for inspection.
- **BloccsWeb brand** — the real bloccs mark + wordmark in the nav, and a palette
  aligned to bloccs.io.

### Changed

- Requires `bloccs ~> 0.5` (was `~> 0.3`).

### Fixed

- Topology inspector no longer crashes selecting a `join`/`batch`/`rate` node
  (read `Bloccs.Manifest.*` primitive structs with `Map.get/2`, not `Access`).
- Aggregate nodes' emits (e.g. a join's output) now appear in the Messages feed,
  so a fan-in journey is complete.
- Node labels are no longer clipped in the topology / coverage graph.

## [0.1.0] - 2026-06-06

First release. A self-hosted, observe-only Phoenix LiveView dashboard for running
bloccs networks, mounted into a host app with one router macro (the oban_web
model). Requires `bloccs ~> 0.3`.

### Added

- **Message payloads in the Messages feed.** When `Bloccs.Inspect` capture is
  enabled (bloccs 0.3+), the feed shows a bounded, redacted snapshot of each
  message's payload in a new column, read from the `:payload` key on the
  `[:bloccs, :emit]` telemetry. A hint appears when capture is off.
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
- **Licensed under Apache License 2.0**, matching the `bloccs` library (adds an
  explicit patent grant).

[0.2.0]: https://github.com/Bloccs/bloccs_web/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/Bloccs/bloccs_web/releases/tag/v0.1.0
