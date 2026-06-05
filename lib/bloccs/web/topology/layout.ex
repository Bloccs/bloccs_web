defmodule Bloccs.Web.Topology.Layout do
  @moduledoc """
  A pure, deterministic layered layout for a network's DAG — the server-side
  alternative to a client layout library. Each node is placed in a column by its
  longest path from a source, and in a row within that column; edges become
  cubic-bezier paths between the right and left faces of the hexagons.

  Returns plain data (coords + SVG path strings) so `Bloccs.Web.Panels.Topology`
  is pure rendering and the layout is unit-testable without a browser. Live node
  state is layered on at render time, not here.
  """

  alias Bloccs.Introspect.Network

  @col_w 220
  @row_h 170
  @margin 70
  # half the hexagon's width (the glyph path spans ±52 around its center)
  @half 52
  @bend 60

  @type placed_node :: %{
          id: atom(),
          glyph: atom(),
          kind: atom(),
          label: String.t(),
          x: number(),
          y: number()
        }
  @type placed_edge :: %{from: atom(), to: atom(), path: String.t()}
  @type t :: %{
          width: number(),
          height: number(),
          nodes: [placed_node()],
          edges: [placed_edge()]
        }

  @doc "Compute the layout for a running network's topology."
  @spec compute(Network.t()) :: t()
  def compute(%Network{nodes: nodes, edges: edges}) do
    ids = Enum.map(nodes, & &1.id)
    pairs = edges |> Enum.map(fn %{from: {f, _}, to: {t, _}} -> {f, t} end) |> Enum.uniq()

    layers = layer_map(ids, pairs)
    positions = positions(ids, layers)
    coord = fn id -> elem_coord(Map.fetch!(positions, id)) end

    %{
      width: width(layers),
      height: height(positions),
      nodes:
        Enum.map(nodes, fn n ->
          {x, y} = coord.(n.id)
          %{id: n.id, glyph: n.glyph, kind: n.kind, label: Atom.to_string(n.id), x: x, y: y}
        end),
      edges:
        Enum.map(pairs, fn {f, t} ->
          %{from: f, to: t, path: edge_path(coord.(f), coord.(t))}
        end)
    }
  end

  # Longest-path layering by relaxation (the DAG guarantees convergence in ≤|V|
  # passes; bloccs networks are acyclic).
  defp layer_map(ids, pairs) do
    init = Map.new(ids, &{&1, 0})
    passes = max(length(ids), 1)

    Enum.reduce(1..passes, init, fn _, acc ->
      Enum.reduce(pairs, acc, fn {f, t}, a ->
        Map.update!(a, t, fn cur -> max(cur, Map.fetch!(a, f) + 1) end)
      end)
    end)
  end

  # Assign a row within each column, ordered by id for a stable layout.
  defp positions(ids, layers) do
    ids
    |> Enum.group_by(&Map.fetch!(layers, &1))
    |> Enum.flat_map(fn {layer, layer_ids} ->
      layer_ids
      |> Enum.sort_by(&Atom.to_string/1)
      |> Enum.with_index()
      |> Enum.map(fn {id, row} -> {id, {layer, row}} end)
    end)
    |> Map.new()
  end

  defp elem_coord({layer, row}), do: {@margin + layer * @col_w, @margin + row * @row_h}

  defp width(layers) do
    max_layer = layers |> Map.values() |> Enum.max(fn -> 0 end)
    @margin * 2 + max_layer * @col_w
  end

  defp height(positions) do
    max_row = positions |> Map.values() |> Enum.map(fn {_l, r} -> r end) |> Enum.max(fn -> 0 end)
    @margin * 2 + max_row * @row_h
  end

  defp edge_path({fx, fy}, {tx, ty}) do
    x1 = fx + @half
    x2 = tx - @half
    "M#{x1},#{fy} C#{x1 + @bend},#{fy} #{x2 - @bend},#{ty} #{x2},#{ty}"
  end
end
