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

  @typedoc "A normalized flow event (before timestamping)."
  @type event :: %{
          node: atom(),
          out_port: atom() | nil,
          to: endpoint() | nil,
          outcome: outcome(),
          duration_ms: number() | nil,
          reason: term() | nil
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

  # ---- internals ----

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
