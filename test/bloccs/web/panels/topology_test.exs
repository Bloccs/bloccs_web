defmodule Bloccs.Web.Panels.TopologyTest do
  use Bloccs.Web.ConnCase, async: false

  setup do
    supervisor = Demo.start!()
    on_exit(fn -> stop(supervisor) end)
    :ok
  end

  test "renders the demo network as an SVG of hexagon glyphs and edges", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/bloccs/networks/demo")

    assert html =~ "Topology"
    # three inc nodes → three plain-node glyphs
    assert count(html, "hex-glyph--node") >= 3
    # the shared hexagon outline appears once per glyph
    assert count(html, "M0,-52") >= 3
    # first → second → third = two edges (each path's class starts with
    # "bloccs-edge"; live edges may append a "--active" modifier, so count the
    # stable class prefix rather than the bare token).
    assert count(html, ~s(class="bloccs-edge)) == 2
    # node labels
    assert html =~ ">first<" or html =~ "first"
    assert html =~ "third"
  end

  test "unknown network shows a not-found state", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/bloccs/networks/nope")
    assert html =~ "Network not found"
  end

  describe "prim_config/1" do
    # Regression: with bloccs ≥ the contract/config introspection, a node's
    # `config` carries `Bloccs.Manifest.{Batch,Join,Rate}` structs — which do NOT
    # implement Access. The inspector formatted them with `b[:size]` bracket
    # syntax and crashed (UndefinedFunctionError: Manifest.Batch.fetch/2) the
    # moment a join/batch/rate node was selected. Format with Map.get/2 instead.
    alias Bloccs.Manifest.{Batch, Join, Rate}
    alias Bloccs.Web.Panels.Topology

    test "formats a Batch struct without crashing on Access" do
      config = %{batch: %Batch{size: 5, timeout_ms: 2000}}
      assert Topology.prim_config(config) == [{"batch", "size 5 · 2000ms"}]
    end

    test "formats a Join struct" do
      config = %{join: %Join{on: "order_id", timeout_ms: 4000, deadletter: :dead}}
      assert Topology.prim_config(config) == [{"join", "on order_id · 4000ms"}]
    end

    test "formats a Rate struct" do
      config = %{rate: %Rate{allowed: 5, interval_ms: 1000}}
      assert Topology.prim_config(config) == [{"rate", "5 / 1000ms"}]
    end

    test "formats a plain delay and skips nil primitives" do
      assert Topology.prim_config(%{delay_ms: 1000, batch: nil}) == [{"delay", "1000ms"}]
    end

    test "is empty for a config with no primitives" do
      assert Topology.prim_config(%{batch: nil, join: nil, rate: nil, delay_ms: nil}) == []
      assert Topology.prim_config(nil) == []
    end
  end

  describe "node inspector (render/1)" do
    alias Bloccs.Web.Panels.Topology

    defp reply_node do
      %{
        id: :pay,
        kind: :sink,
        glyph: :sink,
        ports_in: [%{name: :req, schema: "Req@1", buffer: nil}],
        ports_out: [%{name: :reply, schema: "Res@1", buffer: nil}],
        effects: [:db, :http],
        effect_detail: %{
          db: %{allow: ["events:read", "events:insert"]},
          http: %{allow: ["api.x"], methods: ["GET"]},
          time: nil,
          random: nil
        },
        reply: true,
        concurrency: 1,
        doc: %{intent: nil, owner: nil},
        contract: %{
          pure_core: "M.f/2",
          effect_shell: "M.g/2",
          timeout_ms: nil,
          retry: nil,
          idempotency: nil
        },
        config: %{batch: nil, join: nil, rate: nil, delay_ms: nil}
      }
    end

    test "renders the reply badge and per-axis effect scopes for a selected node" do
      network =
        struct(Bloccs.Introspect.Network, %{
          id: :demo,
          version: "0.1.0",
          supervisor: __MODULE__,
          started_at: 0,
          nodes: [reply_node()],
          edges: [],
          expose: %{in: %{}, out: %{}},
          supervision: %{strategy: :one_for_one, max_restarts: 3, max_seconds: 5}
        })

      html =
        render_component(&Topology.render/1,
          network: network,
          base_path: "/bloccs",
          selected: "pay"
        )

      # reply = true node is badged
      assert html =~ "reply"
      # db scopes + http host/method rendered as chips
      assert html =~ "events:read"
      assert html =~ "events:insert"
      assert html =~ "api.x"
      assert html =~ "GET"
    end
  end

  describe "effect_scopes/2 (bloccs ≥ 0.8 effect_detail)" do
    alias Bloccs.Web.Panels.Topology

    test "lists db table:action scopes" do
      node = %{effect_detail: %{db: %{allow: ["items:read", "items:update"]}}}
      assert Topology.effect_scopes(node, :db) == ["items:read", "items:update"]
    end

    test "lists http allowed hosts + methods" do
      node = %{effect_detail: %{http: %{allow: ["api.example.com"], methods: ["GET", "POST"]}}}
      assert Topology.effect_scopes(node, :http) == ["api.example.com", "GET", "POST"]
    end

    test "shows the mode string for time/random" do
      node = %{effect_detail: %{time: "wall_clock"}}
      assert Topology.effect_scopes(node, :time) == ["wall_clock"]
    end

    test "is empty for an undeclared axis or a pre-0.8 view with no effect_detail" do
      assert Topology.effect_scopes(%{effect_detail: %{db: nil}}, :db) == []
      assert Topology.effect_scopes(%{}, :db) == []
    end
  end

  defp count(html, needle), do: html |> String.split(needle) |> length() |> Kernel.-(1)

  defp stop(supervisor) do
    Supervisor.stop(supervisor, :normal, 5_000)
  catch
    :exit, _ -> :ok
  end
end
