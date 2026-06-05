defmodule Bloccs.Web.CoverageTest do
  use ExUnit.Case, async: true

  alias Bloccs.Introspect.Network
  alias Bloccs.Web.Coverage

  # a → b (one edge), each node one in + one out port.
  defp net do
    %Network{
      id: :t,
      version: "1",
      supervisor: __MODULE__,
      nodes: [
        %{
          id: :a,
          glyph: :source,
          kind: :source,
          ports_in: [%{name: :seed}],
          ports_out: [%{name: :n}],
          effects: [],
          concurrency: 1,
          doc: %{}
        },
        %{
          id: :b,
          glyph: :sink,
          kind: :sink,
          ports_in: [%{name: :n}],
          ports_out: [%{name: :done}],
          effects: [],
          concurrency: 1,
          doc: %{}
        }
      ],
      edges: [%{from: {:a, :n}, to: {:b, :n}}]
    }
  end

  test "enumerates every port and edge as an obligation" do
    obs = Coverage.obligations(net())
    # 2 nodes × 2 ports + 1 edge = 5
    assert length(obs) == 5
    assert {:port_in, :a, :seed} in obs
    assert {:port_out, :a, :n} in obs
    assert {:edge, {:a, :n}, {:b, :n}} in obs
  end

  test "reports reached/unreached and a percentage" do
    reached = [{:port_in, :a, :seed}, {:port_out, :a, :n}, {:edge, {:a, :n}, {:b, :n}}]
    report = Coverage.report(net(), reached)

    assert report.total == 5
    assert report.reached_count == 3
    assert report.percent == 60
    assert {:port_in, :b, :n} in report.unreached
  end

  test "derives node and edge overlays from a report" do
    reached = [{:port_in, :a, :seed}, {:edge, {:a, :n}, {:b, :n}}]
    report = Coverage.report(net(), reached)

    assert Coverage.reached_nodes(report) == MapSet.new([:a])
    assert Coverage.reached_edges(report) == MapSet.new([{:a, :b}])

    states = Coverage.node_states(net(), report)
    assert states[:a] == :ok
    assert states[:b] == :idle
  end

  test "empty reached set yields 0%" do
    report = Coverage.report(net(), [])
    assert report.percent == 0
    assert report.reached_count == 0
  end
end
