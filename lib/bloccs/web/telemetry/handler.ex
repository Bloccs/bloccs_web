defmodule Bloccs.Web.Telemetry.Handler do
  @moduledoc """
  Attaches to the `[:bloccs, …]` telemetry events and forwards normalized data to
  the `Bloccs.Web.Telemetry.Collector`. Runs in the emitting (Broadway) process,
  so it does the minimum — normalize and cast — and never blocks the pipeline.

  It feeds two views:

    * **Metrics** — per-node rolling windows from `:start` / `:stop` / …
    * **Flow** — one event per message that crosses an edge. A node's `[:bloccs,
      :emit]` events (the edges it fired) are buffered in the process dictionary
      and flushed on `:stop` / `:exception`, paired with the node's outcome and
      latency. The handler runs in the node's process and a Broadway processor
      handles one message at a time, so the per-process buffer is race-free.
  """

  alias Bloccs.Web.Telemetry.Collector

  @buf :bloccs_flow_buf

  @events [
    [:bloccs, :node, :start],
    [:bloccs, :node, :stop],
    [:bloccs, :node, :exception],
    [:bloccs, :node, :retry],
    [:bloccs, :node, :skipped],
    [:bloccs, :node, :dropped],
    [:bloccs, :node, :dispatch_error],
    [:bloccs, :emit]
  ]

  @doc "Attach this handler, forwarding to `collector`. Idempotent per id."
  @spec attach(atom(), pid() | atom()) :: :ok | {:error, :already_exists}
  def attach(id, collector) do
    :telemetry.attach_many(id, @events, &__MODULE__.handle/4, %{collector: collector})
  end

  @spec detach(atom()) :: :ok | {:error, :not_found}
  def detach(id), do: :telemetry.detach(id)

  @doc false
  # An emit is one edge firing: stash it in the current message's buffer.
  def handle([:bloccs, :emit], _measurements, metadata, _config) do
    case Process.get(@buf) do
      %{emits: emits} = buf ->
        Process.put(@buf, %{
          buf
          | emits: [{metadata[:from_port], metadata[:targets] || []} | emits]
        })

      _ ->
        :ok
    end

    :ok
  end

  def handle([:bloccs, :node, kind], measurements, metadata, %{collector: collector}) do
    with network when not is_nil(network) <- metadata[:network],
         node when not is_nil(node) <- metadata[:node] do
      Collector.record(collector, network, normalize(kind, measurements, metadata))
      flow(kind, measurements, metadata, collector, network)
    else
      _ -> :ok
    end
  end

  # ---- metrics normalization ----

  defp normalize(:start, _measurements, meta), do: {:start, meta.node}

  defp normalize(:stop, measurements, meta) do
    {:stop, meta.node, duration_ms(measurements), meta[:outcome] || :ok}
  end

  defp normalize(:exception, _measurements, meta), do: {:exception, meta.node}
  defp normalize(kind, _measurements, meta), do: {:event, meta.node, kind}

  # ---- flow correlation ----

  defp flow(:start, _measurements, meta, _collector, _network) do
    Process.put(@buf, %{node: meta.node, emits: []})
    :ok
  end

  defp flow(:stop, measurements, meta, collector, network) do
    flush(collector, network, meta.node, meta[:outcome] || :ok, duration_ms(measurements), nil)
  end

  defp flow(:exception, measurements, meta, collector, network) do
    flush(collector, network, meta.node, :failed, duration_ms(measurements), meta[:reason])
  end

  defp flow(kind, _measurements, meta, collector, network)
       when kind in [:dropped, :skipped, :retry, :dispatch_error] do
    Collector.record_flow(collector, network, %{
      node: meta.node,
      out_port: nil,
      to: nil,
      outcome: kind,
      duration_ms: nil,
      reason: nil
    })
  end

  defp flush(collector, network, node, outcome, duration, reason) do
    emits =
      case Process.get(@buf) do
        %{node: ^node, emits: emits} -> Enum.reverse(emits)
        _ -> []
      end

    Process.delete(@buf)

    for {port, targets} <- normalize_emits(emits), target <- targets_or_nil(targets) do
      Collector.record_flow(collector, network, %{
        node: node,
        out_port: port,
        to: target,
        outcome: outcome,
        duration_ms: duration,
        reason: reason
      })
    end

    :ok
  end

  # A node that emitted nothing (failed/dropped before emit, or terminal) still
  # produces one row so the failure is visible.
  defp normalize_emits([]), do: [{nil, []}]
  defp normalize_emits(emits), do: emits

  defp targets_or_nil([]), do: [nil]
  defp targets_or_nil(targets), do: targets

  defp duration_ms(%{duration: native}) do
    System.convert_time_unit(native, :native, :microsecond) / 1000
  end

  defp duration_ms(_), do: nil
end
