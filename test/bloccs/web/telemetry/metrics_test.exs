defmodule Bloccs.Web.Telemetry.MetricsTest do
  use ExUnit.Case, async: true

  alias Bloccs.Web.Telemetry.Metrics

  test "folds start/stop into a per-node window with throughput and latency" do
    state =
      Metrics.new()
      |> Metrics.apply({:start, :a}, 0)
      |> Metrics.apply({:stop, :a, 4.0, :ok}, 10)
      |> Metrics.apply({:stop, :a, 6.0, :ok}, 20)

    %{nodes: %{a: a}} = Metrics.snapshot(state, 25)

    assert a.state == :ok
    assert a.completed == 2
    assert a.errors == 0
    assert a.p50 in [4.0, 6.0]
    assert a.p95 == 6.0
    assert a.throughput > 0.0
  end

  test "marks a node failed on a failed stop and tracks error rate" do
    state =
      Metrics.new()
      |> Metrics.apply({:stop, :b, 1.0, :ok}, 0)
      |> Metrics.apply({:stop, :b, 1.0, :failed}, 1)
      |> Metrics.apply({:exception, :b}, 2)

    %{nodes: %{b: b}} = Metrics.snapshot(state, 3)

    assert b.state == :failed
    assert b.completed == 3
    assert b.errors == 2
    assert_in_delta b.error_rate, 2 / 3, 0.001
  end

  test "drops samples and decays state outside the rolling window" do
    state =
      Metrics.new()
      |> Metrics.apply({:start, :c}, 0)
      |> Metrics.apply({:stop, :c, 5.0, :ok}, 10)

    # 20s later (window is 10s): sample pruned, state settles to idle
    %{nodes: %{c: c}} = Metrics.snapshot(state, 20_010)

    assert c.throughput == 0.0
    assert c.p95 == nil
    assert c.state == :idle
    # cumulative counters persist
    assert c.completed == 1
  end

  test "an empty state snapshots to no nodes" do
    assert %{nodes: nodes} = Metrics.snapshot(Metrics.new(), 0)
    assert nodes == %{}
  end
end
