defmodule Bloccs.Web.Topology.LayoutTest do
  use ExUnit.Case, async: true

  alias Bloccs.Introspect.Network
  alias Bloccs.Web.Topology.Layout

  # A small fan-out DAG: a → b, a → c, b → d, c → d.
  defp net do
    %Network{
      id: :t,
      version: "1",
      supervisor: __MODULE__,
      nodes: [
        node(:a, :source),
        node(:b, :node),
        node(:c, :node_effect),
        node(:d, :sink)
      ],
      edges: [
        edge(:a, :b),
        edge(:a, :c),
        edge(:b, :d),
        edge(:c, :d)
      ]
    }
  end

  defp node(id, glyph),
    do: %{
      id: id,
      glyph: glyph,
      kind: :transform,
      ports_in: [],
      ports_out: [],
      effects: [],
      concurrency: 1,
      doc: %{}
    }

  defp edge(f, t), do: %{from: {f, :out}, to: {t, :in}}

  test "places nodes in longest-path columns" do
    layout = Layout.compute(net())
    col = Map.new(layout.nodes, &{&1.id, &1.x})

    # a is the source (col 0); d is two hops downstream (col 2); b and c share col 1.
    assert col[:a] < col[:b]
    assert col[:b] == col[:c]
    assert col[:b] < col[:d]
    # longest path a→b→d (or a→c→d) puts d two columns past a
    assert col[:d] - col[:a] == 2 * (col[:b] - col[:a])
  end

  test "stacks same-column nodes on distinct rows" do
    layout = Layout.compute(net())
    by_id = Map.new(layout.nodes, &{&1.id, &1})
    assert by_id[:b].y != by_id[:c].y
  end

  test "emits one bezier path per edge, within the canvas" do
    layout = Layout.compute(net())
    assert length(layout.edges) == 4
    assert Enum.all?(layout.edges, &String.starts_with?(&1.path, "M"))
    assert Enum.all?(layout.edges, &String.contains?(&1.path, "C"))
    assert layout.width > 0 and layout.height > 0
  end

  test "carries the glyph and label through for rendering" do
    layout = Layout.compute(net())
    a = Enum.find(layout.nodes, &(&1.id == :a))
    assert a.glyph == :source
    assert a.label == "a"
  end
end
