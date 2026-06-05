defmodule Bloccs.Web.Telemetry.FlowTest do
  use ExUnit.Case, async: true

  alias Bloccs.Web.Telemetry.Flow

  defp ev(node, to, outcome \\ :ok) do
    %{node: node, out_port: :out, to: to, outcome: outcome, duration_ms: 1.0, reason: nil}
  end

  test "keeps recent events newest-first and stamps them" do
    state =
      Flow.new()
      |> Flow.record(ev(:a, {:b, :in}), 1_000)
      |> Flow.record(ev(:b, {:c, :in}), 1_010)

    %{events: [first, second]} = Flow.snapshot(state, 1_020)
    assert first.node == :b and first.at == 1_010
    assert second.node == :a
  end

  test "buckets events per second and reports last-second rate" do
    state =
      Enum.reduce(1..5, Flow.new(), fn _i, acc ->
        Flow.record(acc, ev(:a, {:b, :in}), 10_000)
      end)
      |> Flow.record(ev(:a, {:b, :in}), 11_500)

    snap = Flow.snapshot(state, 11_900)

    # 5 events landed in second 10; the rate is events in the previous full second (11_900 → prev sec 10)
    assert snap.rate == 5
    assert Enum.any?(snap.series, &(&1.total > 0))
  end

  test "classifies failed and dropped into their bucket lanes" do
    state =
      Flow.new()
      |> Flow.record(ev(:a, {:b, :in}, :ok), 2_000)
      |> Flow.record(ev(:a, nil, :failed), 2_001)
      |> Flow.record(ev(:a, nil, :dropped), 2_002)

    %{series: series} = Flow.snapshot(state, 2_500)
    bucket = Enum.find(series, &(&1.total == 3))
    assert bucket.ok == 1 and bucket.failed == 1 and bucket.dropped == 1
  end

  test "caps the recent ring" do
    state =
      Enum.reduce(1..150, Flow.new(), fn i, acc ->
        Flow.record(acc, ev(:a, {:b, :in}), 1_000 + i)
      end)

    assert length(Flow.snapshot(state, 2_000).events) == 100
  end
end
