defmodule Bloccs.Web.Telemetry.Collector do
  @moduledoc """
  The single sink for bloccs telemetry. Attaches `Bloccs.Web.Telemetry.Handler`
  to the `[:bloccs, …]` stream, folds normalized events into per-network rolling
  windows (`Bloccs.Web.Telemetry.Metrics`, the pure core), and on a 1-second tick
  broadcasts a snapshot frame per network over `Phoenix.PubSub`.

  Panels subscribe to `topic(network)` for live updates and call `snapshot/1`
  on mount for first paint — so reconnects never lose state and no database is
  involved. Folding events into a window keeps per-message telemetry off the
  LiveView; only the coalesced 1 Hz frame crosses PubSub.
  """

  use GenServer

  alias Bloccs.Web.Telemetry.{Handler, Metrics}

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

  @doc "Cast a normalized event in (called by the telemetry handler)."
  @spec record(pid() | atom(), atom(), Metrics.event()) :: :ok
  def record(collector, network, event) do
    GenServer.cast(collector, {:record, network, event})
  end

  @doc "First-paint snapshot for a network (empty frame if unseen)."
  @spec snapshot(atom()) :: frame()
  def snapshot(network) do
    GenServer.call(__MODULE__, {:snapshot, network})
  catch
    :exit, _ -> %{nodes: %{}, updated_at: nil}
  end

  # ---- GenServer ----

  @impl true
  def init(_opts) do
    Handler.attach(@handler_id, self())
    schedule_tick()
    {:ok, %{networks: %{}}}
  end

  @impl true
  def handle_cast({:record, network, event}, state) do
    now = System.monotonic_time(:millisecond)
    metrics = Map.get(state.networks, network, Metrics.new())
    metrics = Metrics.apply(metrics, event, now)
    {:noreply, put_in(state.networks[network], metrics)}
  end

  @impl true
  def handle_call({:snapshot, network}, _from, state) do
    now = System.monotonic_time(:millisecond)

    frame =
      case Map.fetch(state.networks, network) do
        {:ok, metrics} -> Metrics.snapshot(metrics, now)
        :error -> %{nodes: %{}, updated_at: nil}
      end

    {:reply, frame, state}
  end

  @impl true
  def handle_info(:tick, state) do
    now = System.monotonic_time(:millisecond)

    Enum.each(state.networks, fn {network, metrics} ->
      frame = Metrics.snapshot(metrics, now)
      Phoenix.PubSub.broadcast(@pubsub, topic(network), {:bloccs_frame, network, frame})
    end)

    schedule_tick()
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, _state) do
    Handler.detach(@handler_id)
    :ok
  end

  defp schedule_tick, do: Process.send_after(self(), :tick, @tick_ms)
end
