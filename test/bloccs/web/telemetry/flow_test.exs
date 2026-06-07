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

  # A lineage event: msg_id with parents + trace, plus an `at` for ordering.
  defp lev(msg_id, parents, trace, at, node \\ :n) do
    %{
      node: node,
      out_port: :out,
      to: nil,
      outcome: :ok,
      at: at,
      msg_id: msg_id,
      parents: parents,
      trace_id: trace
    }
  end

  describe "journey/2" do
    test "is empty for a nil msg_id" do
      assert Flow.journey([lev(2, [1], 1, 10)], nil) == []
    end

    test "walks a 1:1 chain from any hop, oldest-first" do
      # ingress root 1 (no event) -> emit 2 -> emit 3 -> emit 4, one trace
      events = [lev(4, [3], 1, 40), lev(3, [2], 1, 30), lev(2, [1], 1, 20)]

      ids = Flow.journey(events, 3) |> Enum.map(& &1.msg_id)
      # from the middle hop, reaches the whole chain present in the ring
      assert ids == [2, 3, 4]
    end

    test "a fan-in journey includes every merged input branch" do
      # two independent inputs (traces 1 and 2) merge at msg 30 (fresh trace 99),
      # which then emits 31.
      events = [
        lev(31, [30], 99, 60),
        lev(30, [10, 20], 99, 50),
        lev(10, [1], 1, 10),
        lev(20, [2], 2, 20)
      ]

      ids = Flow.journey(events, 31) |> Enum.map(& &1.msg_id) |> Enum.sort()
      # both pre-merge branches (10, 20) and the merge (30) + its child (31)
      assert ids == [10, 20, 30, 31]
    end
  end

  describe "messages/1" do
    test "keeps one representative per trace, newest-first, dropping trace-less events" do
      events = [
        lev(5, [4], 2, 50),
        lev(4, [3], 2, 40),
        lev(9, [8], 7, 30),
        %{
          node: :x,
          out_port: nil,
          to: nil,
          outcome: :dropped,
          at: 20,
          msg_id: 1,
          parents: [],
          trace_id: nil
        }
      ]

      reps = Flow.messages(events)
      assert Enum.map(reps, & &1.trace_id) == [2, 7]
      # newest occurrence per trace is the representative
      assert hd(reps).msg_id == 5
    end
  end
end
