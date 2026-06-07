defmodule Bloccs.Web.Telemetry.Metrics do
  @moduledoc """
  The pure functional core of the metrics collector: folds normalized bloccs
  telemetry into per-node rolling windows and renders a snapshot. No processes,
  no clock of its own — `now` (monotonic ms) is always passed in, so the whole
  thing is deterministically testable with synthetic events.

  Normalized events (produced by `Bloccs.Web.Telemetry.Handler`):

    * `{:start, node}` — a message entered the node
    * `{:stop, node, duration_ms, :ok | :failed}` — it finished
    * `{:exception, node}` — it raised
    * `{:event, node, kind}` — retry / skipped / dropped / dispatch_error

  A node's `state` (`:idle | :running | :ok | :failed`) drives the topology
  glyph; the windowed stats drive the metrics panel.
  """

  @window_ms 10_000
  @max_samples 500

  @type node_state :: %{
          completed: non_neg_integer(),
          errors: non_neg_integer(),
          events: non_neg_integer(),
          samples: [{integer(), number()}],
          state: :idle | :running | :ok | :failed,
          last_at: integer() | nil
        }
  @type t :: %{optional(atom()) => node_state()}

  @type event ::
          {:start, atom()}
          | {:stop, atom(), number(), :ok | :failed}
          | {:exception, atom()}
          | {:event, atom(), atom()}

  @type node_view :: %{
          state: atom(),
          completed: non_neg_integer(),
          errors: non_neg_integer(),
          error_rate: float(),
          throughput: float(),
          p50: number() | nil,
          p95: number() | nil
        }

  @spec new() :: t()
  def new, do: %{}

  @spec apply(t(), event(), integer()) :: t()
  def apply(nodes, {:start, node}, now) do
    update(nodes, node, now, &%{&1 | state: :running})
  end

  def apply(nodes, {:stop, node, duration_ms, outcome}, now) do
    update(nodes, node, now, fn m ->
      %{
        m
        | completed: m.completed + 1,
          errors: m.errors + if(outcome == :failed, do: 1, else: 0),
          state: if(outcome == :failed, do: :failed, else: :ok),
          samples: add_sample(m.samples, {now, duration_ms})
      }
    end)
  end

  def apply(nodes, {:exception, node}, now) do
    update(nodes, node, now, fn m ->
      %{m | completed: m.completed + 1, errors: m.errors + 1, state: :failed}
    end)
  end

  def apply(nodes, {:event, node, _kind}, now) do
    update(nodes, node, now, &%{&1 | events: &1.events + 1})
  end

  def apply(nodes, _unknown, _now), do: nodes

  @doc "Render a `{node => view}` snapshot, pruning samples older than the window."
  @spec snapshot(t(), integer()) :: %{nodes: %{atom() => node_view()}, updated_at: integer()}
  def snapshot(nodes, now) do
    views =
      Map.new(nodes, fn {id, m} ->
        recent = prune(m.samples, now)
        durations = Enum.map(recent, &elem(&1, 1))

        {id,
         %{
           state: decayed_state(m, now),
           completed: m.completed,
           errors: m.errors,
           error_rate: ratio(m.errors, m.completed),
           throughput: length(recent) / (@window_ms / 1000),
           p50: percentile(durations, 0.5),
           p95: percentile(durations, 0.95),
           series: series(recent, now)
         }}
      end)

    %{nodes: views, updated_at: now}
  end

  # ---- internals ----

  defp blank, do: %{completed: 0, errors: 0, events: 0, samples: [], state: :idle, last_at: nil}

  defp update(nodes, node, now, fun) do
    m = Map.get(nodes, node, blank())
    Map.put(nodes, node, fun.(%{m | last_at: now}))
  end

  defp add_sample(samples, sample) do
    [sample | samples] |> Enum.take(@max_samples)
  end

  defp prune(samples, now) do
    Enum.filter(samples, fn {t, _} -> now - t <= @window_ms end)
  end

  # Per-second completion counts across the window (oldest → newest), for a tiny
  # throughput sparkline on the metrics panel.
  @buckets div(@window_ms, 1000)
  defp series(samples, now) do
    start = now - @window_ms

    counts =
      Enum.reduce(samples, %{}, fn {t, _}, acc ->
        sec = div(t - start, 1000)
        if sec >= 0 and sec < @buckets, do: Map.update(acc, sec, 1, &(&1 + 1)), else: acc
      end)

    for s <- 0..(@buckets - 1), do: Map.get(counts, s, 0)
  end

  # A node that finished a while ago settles back to :idle so the graph doesn't
  # stay lit forever; a failure stays visible for the window.
  defp decayed_state(%{state: :failed} = m, now) do
    if stale?(m, now), do: :idle, else: :failed
  end

  defp decayed_state(%{state: :ok} = m, now) do
    if stale?(m, now), do: :idle, else: :ok
  end

  defp decayed_state(%{state: state}, _now), do: state

  defp stale?(%{last_at: nil}, _now), do: true
  defp stale?(%{last_at: at}, now), do: now - at > @window_ms

  defp ratio(_n, 0), do: 0.0
  defp ratio(n, d), do: n / d

  defp percentile([], _q), do: nil

  defp percentile(values, q) do
    sorted = Enum.sort(values)
    idx = max(0, round(q * (length(sorted) - 1)))
    Enum.at(sorted, idx)
  end
end
