defmodule Bloccs.Web.Panels.NetworksTest do
  use Bloccs.Web.ConnCase, async: false

  alias Bloccs.Web.Panels

  describe "render/1 (component)" do
    test "renders a row per network with counts and a topology link" do
      networks = [
        %{
          id: :demo,
          version: "0.1.0",
          node_count: 3,
          edge_count: 2,
          started_at: -1_000,
          supervisor: X
        }
      ]

      html =
        render_component(&Panels.Networks.render/1,
          networks: networks,
          base_path: "/bloccs",
          now: 0,
          stats: %{demo: %{rate: 0, series: [], errors: 0, in_flight: 4}}
        )

      assert html =~ "demo"
      assert html =~ "0.1.0"
      assert html =~ ~s(href="/bloccs/networks/demo")
      assert html =~ "1s"
      # in-flight request/response column (Bloccs.Collector.stats/0)
      assert html =~ "In-flight"
      assert html =~ "4"
    end

    test "shows an empty state when nothing is running" do
      html =
        render_component(&Panels.Networks.render/1, networks: [], base_path: "/bloccs", now: 0)

      assert html =~ "No running networks"
    end
  end

  describe "live mount" do
    setup do
      supervisor = Demo.start!()
      on_exit(fn -> stop(supervisor) end)
      :ok
    end

    test "lists the running demo network", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/bloccs")

      assert html =~ "Networks"
      assert html =~ "demo"
      # 3 nodes, 2 edges
      assert html =~ ~s(href="/bloccs/networks/demo")
      # the dashboard's real load path calls Bloccs.Collector.stats/0 for this column
      assert html =~ "In-flight"
    end

    test "navigates into the topology panel from a network row", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/bloccs")

      {:ok, topology_view, html} =
        view
        |> element(~s(a[href="/bloccs/networks/demo"]))
        |> render_click()
        |> follow_redirect(conn, "/bloccs/networks/demo")

      assert html =~ "demo"
      assert render(topology_view) =~ "Topology"
    end
  end

  defp stop(supervisor) do
    Supervisor.stop(supervisor, :normal, 5_000)
  catch
    :exit, _ -> :ok
  end
end
