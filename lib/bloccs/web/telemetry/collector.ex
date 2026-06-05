defmodule Bloccs.Web.Telemetry.Collector do
  @moduledoc """
  The single sink for bloccs telemetry. A `[:bloccs, …]` handler (attached in
  P4) folds events into per-`{network, node}` rolling windows held here, and the
  panels subscribe to `Phoenix.PubSub` broadcasts off this process for their
  live updates. On mount a panel pulls `snapshot/1` for first paint, then
  subscribes — so reconnects never lose state and no database is involved.

  **P0 status:** the process starts and answers `snapshot/1` with an empty frame.
  Event folding and broadcasting land in P4 (`Telemetry.Handler` +
  `Telemetry.Metrics`).
  """

  use GenServer

  @type frame :: %{nodes: %{optional(atom()) => map()}, updated_at: integer() | nil}

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @doc "First-paint snapshot of a network's rolling metrics (empty until P4)."
  @spec snapshot(atom()) :: frame()
  def snapshot(network_id) do
    GenServer.call(__MODULE__, {:snapshot, network_id})
  catch
    :exit, _ -> %{nodes: %{}, updated_at: nil}
  end

  @impl true
  def init(_opts) do
    {:ok, %{networks: %{}}}
  end

  @impl true
  def handle_call({:snapshot, network_id}, _from, state) do
    {:reply, Map.get(state.networks, network_id, %{nodes: %{}, updated_at: nil}), state}
  end
end
