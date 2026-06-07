defmodule Bloccs.Web.Telemetry.Flow do
  @moduledoc """
  The pure core behind the Messages panel: a bounded record of messages moving
  through a network. Each event is one edge traversal (a `[:bloccs, :emit]`
  correlated with the emitting node's outcome and latency) or a failure/drop.

  Keeps a ring of the most recent events for the activity feed and per-second
  buckets for the throughput chart. Like the rest of the collector core it owns
  no clock — `now` (ms) is passed in — so it is deterministically testable.
  """

  @max_recent 100
  @bucket_window 60
  @keep_seconds 90

  @type endpoint :: {atom(), atom()}
  @type outcome :: :ok | :failed | :dropped | :skipped | :retry | :dispatch_error

  @typedoc """
  A normalized flow event (before timestamping). `msg_id` / `parents` /
  `trace_id` are the emitted message's `Bloccs.Lineage` (bloccs 0.5+): `msg_id`
  is this message, `parents` the input id(s) that caused it (many on a fan-in),
  `trace_id` the root correlation. They let one message be tracked across hops.
  """
  @type event :: %{
          node: atom(),
          out_port: atom() | nil,
          to: endpoint() | nil,
          outcome: outcome(),
          duration_ms: number() | nil,
          reason: term() | nil,
          payload: String.t() | nil,
          msg_id: pos_integer() | nil,
          parents: [pos_integer()],
          trace_id: pos_integer() | nil
        }

  @type t :: %{recent: [map()], buckets: %{integer() => map()}}

  @spec new() :: t()
  def new, do: %{recent: [], buckets: %{}}

  @spec record(t(), event(), integer()) :: t()
  def record(state, event, now) do
    sec = div(now, 1000)
    cls = classify(event.outcome)

    bucket =
      state.buckets
      |> Map.get(sec, %{ok: 0, failed: 0, dropped: 0, other: 0})
      |> Map.update!(cls, &(&1 + 1))

    %{
      state
      | recent: [Map.put(event, :at, now) | state.recent] |> Enum.take(@max_recent),
        buckets: state.buckets |> Map.put(sec, bucket) |> prune(sec)
    }
  end

  @doc """
  A snapshot for the panel: the recent events (newest first), a per-second
  series for the chart, and the current rate (events in the last full second).
  """
  @spec snapshot(t(), integer()) :: %{events: [map()], series: [map()], rate: non_neg_integer()}
  def snapshot(state, now) do
    cur = div(now, 1000)

    series =
      for s <- (cur - @bucket_window + 1)..cur do
        b = Map.get(state.buckets, s, %{ok: 0, failed: 0, dropped: 0, other: 0})
        %{ok: b.ok, failed: b.failed, dropped: b.dropped, other: b.other, total: total(b)}
      end

    %{
      events: state.recent,
      series: series,
      rate: state.buckets |> Map.get(cur - 1, %{}) |> total()
    }
  end

  @doc """
  The lineage **journey** of `msg_id`: every recorded event in its connected
  causal component — ancestors (via `parents`) and descendants (events that list
  it as a parent), transitively — ordered oldest-first. Branches and merges to
  match the topology, so a fan-in (batch/join) journey includes all the inputs
  that were combined. Bounded by what is still in the recent ring.
  """
  @spec journey([map()], pos_integer() | nil) :: [map()]
  def journey(_events, nil), do: []

  def journey(events, msg_id) do
    ids = connected_ids(events, msg_id)

    events
    |> Enum.filter(&(&1[:msg_id] in ids))
    # `msg_id` is monotonic with actual emit creation, so it orders hops causally
    # regardless of when each was recorded (an aggregate node's emit is flushed
    # late, so its `at` lags). Events without an id sort last, by `at`.
    |> Enum.sort_by(&{is_nil(&1[:msg_id]), &1[:msg_id] || 0, &1.at})
  end

  # ---- internals ----

  # The set of msg_ids reachable from `start` along parent/child lineage edges.
  defp connected_ids(events, start) do
    {up, down} =
      Enum.reduce(events, {%{}, %{}}, fn e, {up, down} ->
        mid = e[:msg_id]
        ps = e[:parents] || []

        up =
          if mid,
            do: Map.update(up, mid, MapSet.new(ps), &MapSet.union(&1, MapSet.new(ps))),
            else: up

        down =
          if mid,
            do:
              Enum.reduce(
                ps,
                down,
                &Map.update(&2, &1, MapSet.new([mid]), fn s -> MapSet.put(s, mid) end)
              ),
            else: down

        {up, down}
      end)

    bfs([start], MapSet.new([start]), up, down)
  end

  defp bfs([], seen, _up, _down), do: seen

  defp bfs([n | rest], seen, up, down) do
    neighbors = MapSet.union(Map.get(up, n, MapSet.new()), Map.get(down, n, MapSet.new()))
    fresh = MapSet.difference(neighbors, seen)
    bfs(rest ++ MapSet.to_list(fresh), MapSet.union(seen, fresh), up, down)
  end

  defp classify(:ok), do: :ok
  defp classify(:failed), do: :failed
  defp classify(:dispatch_error), do: :failed
  defp classify(:dropped), do: :dropped
  defp classify(:skipped), do: :dropped
  defp classify(_), do: :other

  defp total(b),
    do:
      Map.get(b, :ok, 0) + Map.get(b, :failed, 0) + Map.get(b, :dropped, 0) +
        Map.get(b, :other, 0)

  defp prune(buckets, cur), do: Map.reject(buckets, fn {s, _} -> s < cur - @keep_seconds end)
end
