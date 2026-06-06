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

  defp count(html, needle), do: html |> String.split(needle) |> length() |> Kernel.-(1)

  defp stop(supervisor) do
    Supervisor.stop(supervisor, :normal, 5_000)
  catch
    :exit, _ -> :ok
  end
end
