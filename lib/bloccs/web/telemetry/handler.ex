defmodule Bloccs.Web.Telemetry.Handler do
  @moduledoc """
  Attaches to the `[:bloccs, :node, …]` telemetry events and forwards a
  normalized event to the `Bloccs.Web.Telemetry.Collector`. Runs in the emitting
  (Broadway) process, so it does the minimum — normalize and cast — and never
  blocks the pipeline.
  """

  alias Bloccs.Web.Telemetry.Collector

  @events [
    [:bloccs, :node, :start],
    [:bloccs, :node, :stop],
    [:bloccs, :node, :exception],
    [:bloccs, :node, :retry],
    [:bloccs, :node, :skipped],
    [:bloccs, :node, :dropped],
    [:bloccs, :node, :dispatch_error]
  ]

  @doc "Attach this handler, forwarding to `collector`. Idempotent per id."
  @spec attach(atom(), pid() | atom()) :: :ok | {:error, :already_exists}
  def attach(id, collector) do
    :telemetry.attach_many(id, @events, &__MODULE__.handle/4, %{collector: collector})
  end

  @spec detach(atom()) :: :ok | {:error, :not_found}
  def detach(id), do: :telemetry.detach(id)

  @doc false
  def handle([:bloccs, :node, kind], measurements, metadata, %{collector: collector}) do
    with network when not is_nil(network) <- metadata[:network],
         node when not is_nil(node) <- metadata[:node] do
      Collector.record(collector, network, normalize(kind, measurements, metadata))
    else
      _ -> :ok
    end
  end

  defp normalize(:start, _measurements, meta), do: {:start, meta.node}

  defp normalize(:stop, measurements, meta) do
    {:stop, meta.node, duration_ms(measurements), meta[:outcome] || :ok}
  end

  defp normalize(:exception, _measurements, meta), do: {:exception, meta.node}
  defp normalize(kind, _measurements, meta), do: {:event, meta.node, kind}

  defp duration_ms(%{duration: native}) do
    System.convert_time_unit(native, :native, :microsecond) / 1000
  end

  defp duration_ms(_), do: 0.0
end
