defmodule Bloccs.Web.Coverage do
  @moduledoc """
  Structural coverage for the dashboard, computed from the runtime
  `Bloccs.Introspect.Network` (so it needs no parsed manifest). Mirrors
  `Bloccs.Coverage`'s obligation model — every in-port, out-port, and edge — and
  compares it against a *reached* set derived from `Bloccs.Trace` events
  (recorded live or loaded from a `.bloccs-trace` file).
  """

  alias Bloccs.Introspect.Network

  @type obligation ::
          {:port_in, atom(), atom()}
          | {:port_out, atom(), atom()}
          | {:edge, {atom(), atom()}, {atom(), atom()}}

  @type report :: %{
          obligations: [obligation()],
          reached: [obligation()],
          unreached: [obligation()],
          total: non_neg_integer(),
          reached_count: non_neg_integer(),
          percent: integer()
        }

  @doc "Every coverage obligation in a running network."
  @spec obligations(Network.t()) :: [obligation()]
  def obligations(%Network{nodes: nodes, edges: edges}) do
    port_obs =
      Enum.flat_map(nodes, fn n ->
        ins = Enum.map(n.ports_in, &{:port_in, n.id, &1.name})
        outs = Enum.map(n.ports_out, &{:port_out, n.id, &1.name})
        ins ++ outs
      end)

    edge_obs = Enum.map(edges, fn %{from: from, to: to} -> {:edge, from, to} end)

    port_obs ++ edge_obs
  end

  @doc "Compare a network's obligations against a reached obligation set."
  @spec report(Network.t(), [obligation()]) :: report()
  def report(%Network{} = network, reached) do
    all = obligations(network)
    reached_set = MapSet.new(reached)
    reached_present = Enum.filter(all, &MapSet.member?(reached_set, &1))
    unreached = Enum.reject(all, &MapSet.member?(reached_set, &1))

    %{
      obligations: all,
      reached: reached_present,
      unreached: unreached,
      total: length(all),
      reached_count: length(reached_present),
      percent: percent(length(reached_present), length(all))
    }
  end

  @doc "The set of node ids touched by any reached port obligation."
  @spec reached_nodes(report()) :: MapSet.t(atom())
  def reached_nodes(%{reached: reached}) do
    reached
    |> Enum.flat_map(fn
      {:port_in, node, _} -> [node]
      {:port_out, node, _} -> [node]
      {:edge, _, _} -> []
    end)
    |> MapSet.new()
  end

  @doc "The set of `{from_node, to_node}` pairs for reached edges (for the overlay)."
  @spec reached_edges(report()) :: MapSet.t({atom(), atom()})
  def reached_edges(%{reached: reached}) do
    reached
    |> Enum.flat_map(fn
      {:edge, {fnode, _}, {tnode, _}} -> [{fnode, tnode}]
      _ -> []
    end)
    |> MapSet.new()
  end

  @doc "Per-node glyph state for the overlay: reached → `:ok`, otherwise `:idle`."
  @spec node_states(Network.t(), report()) :: %{atom() => :ok | :idle}
  def node_states(%Network{nodes: nodes} = _network, report) do
    reached = reached_nodes(report)
    Map.new(nodes, fn n -> {n.id, if(MapSet.member?(reached, n.id), do: :ok, else: :idle)} end)
  end

  defp percent(_n, 0), do: 0
  defp percent(n, total), do: round(n / total * 100)
end
