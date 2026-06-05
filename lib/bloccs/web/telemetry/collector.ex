defmodule Bloccs.Web.Telemetry.Collector do
  @moduledoc """
  The single sink for bloccs telemetry. Attaches `Bloccs.Web.Telemetry.Handler`
  to the `[:bloccs, …]` stream and folds it into two per-network views:

    * **metrics** — `Bloccs.Web.Telemetry.Metrics` rolling windows (Metrics panel)
    * **flow** — `Bloccs.Web.Telemetry.Flow`, recent edge traversals + per-second
      throughput buckets (Messages panel)

  On a 1-second tick it broadcasts a snapshot of each over `Phoenix.PubSub`
  (`topic/1` for metrics, `flow_topic/1` for flow). Panels subscribe for live
  updates and call `snapshot/1` / `flow_snapshot/1` on mount for first paint.
  """

  use GenServer

  alias Bloccs.Web.Telemetry.{Flow, Handler, Metrics}

  @pubsub Bloccs.Web.PubSub
  @tick_ms 1_000
  @handler_id :bloccs_web_collector

  @type frame :: %{nodes: map(), updated_at: integer() | nil}

  # ---- public API ----

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @doc "PubSub topic carrying a network's metric frames."
  @spec topic(atom()) :: String.t()
  def topic(network), do: "bloccs:metrics:#{network}"

  @doc "PubSub topic carrying a network's flow frames."
  @spec flow_topic(atom()) :: String.t()
  def flow_topic(network), do: "bloccs:flow:#{network}"

  @doc "Cast a normalized metrics event in (called by the telemetry handler)."
  @spec record(pid() | atom(), atom(), Metrics.event()) :: :ok
  def record(collector, network, event), do: GenServer.cast(collector, {:record, network, event})

  @doc "Cast a flow event in (called by the telemetry handler)."
  @spec record_flow(pid() | atom(), atom(), Flow.event()) :: :ok
  def record_flow(collector, network, event),
    do: GenServer.cast(collector, {:flow, network, event})

  @doc "First-paint metrics snapshot for a network (empty frame if unseen)."
  @spec snapshot(atom()) :: frame()
  def snapshot(network) do
    GenServer.call(__MODULE__, {:snapshot, network})
  catch
    :exit, _ -> %{nodes: %{}, updated_at: nil}
  end

  @doc "First-paint flow snapshot for a network."
  @spec flow_snapshot(atom()) :: %{events: list(), series: list(), rate: non_neg_integer()}
  def flow_snapshot(network) do
    GenServer.call(__MODULE__, {:flow_snapshot, network})
  catch
    :exit, _ -> %{events: [], series: [], rate: 0}
  end

  # ---- GenServer ----

  @impl true
  def init(_opts) do
    Handler.attach(@handler_id, self())
    schedule_tick()
    {:ok, %{metrics: %{}, flow: %{}}}
  end

  @impl true
  def handle_cast({:record, network, event}, state) do
    now = System.monotonic_time(:millisecond)
    metrics = state.metrics |> Map.get(network, Metrics.new()) |> Metrics.apply(event, now)
    {:noreply, put_in(state.metrics[network], metrics)}
  end

  def handle_cast({:flow, network, event}, state) do
    now = System.system_time(:millisecond)
    flow = state.flow |> Map.get(network, Flow.new()) |> Flow.record(event, now)
    {:noreply, put_in(state.flow[network], flow)}
  end

  @impl true
  def handle_call({:snapshot, network}, _from, state) do
    now = System.monotonic_time(:millisecond)

    frame =
      case Map.fetch(state.metrics, network) do
        {:ok, metrics} -> Metrics.snapshot(metrics, now)
        :error -> %{nodes: %{}, updated_at: nil}
      end

    {:reply, frame, state}
  end

  def handle_call({:flow_snapshot, network}, _from, state) do
    {:reply, flow_frame(state, network), state}
  end

  @impl true
  def handle_info(:tick, state) do
    metrics_now = System.monotonic_time(:millisecond)

    Enum.each(state.metrics, fn {network, metrics} ->
      frame = Metrics.snapshot(metrics, metrics_now)
      Phoenix.PubSub.broadcast(@pubsub, topic(network), {:bloccs_frame, network, frame})
    end)

    Enum.each(state.flow, fn {network, _flow} ->
      Phoenix.PubSub.broadcast(
        @pubsub,
        flow_topic(network),
        {:bloccs_flow, network, flow_frame(state, network)}
      )
    end)

    schedule_tick()
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, _state) do
    Handler.detach(@handler_id)
    :ok
  end

  defp flow_frame(state, network) do
    now = System.system_time(:millisecond)

    case Map.fetch(state.flow, network) do
      {:ok, flow} -> Flow.snapshot(flow, now)
      :error -> %{events: [], series: [], rate: 0}
    end
  end

  defp schedule_tick, do: Process.send_after(self(), :tick, @tick_ms)
end
