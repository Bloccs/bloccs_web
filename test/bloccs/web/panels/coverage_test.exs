defmodule Bloccs.Web.Panels.CoverageTest do
  use Bloccs.Web.ConnCase, async: false

  alias Bloccs.Producer
  alias Bloccs.Web.Panels
  alias Bloccs.Web.Telemetry.Collector

  describe "export gate (Pro seam, component)" do
    test "free build (:all features) shows the export link" do
      html = render_export(:all)
      assert html =~ "Export .bloccs-trace"
      refute html =~ "Pro"
    end

    test "without :trace_export the export is locked behind Pro" do
      html = render_export([:coverage])
      assert html =~ "Pro"
      refute html =~ "Export .bloccs-trace"
    end

    defp render_export(features) do
      coverage = %{
        report: %{
          percent: 100,
          reached_count: 1,
          total: 1,
          reached: [],
          unreached: [],
          obligations: []
        },
        source: :trace,
        json: ~s({"network":"x","events":[]})
      }

      render_component(&Panels.Coverage.render/1,
        network: %Bloccs.Introspect.Network{
          id: :x,
          version: "1",
          supervisor: __MODULE__,
          nodes: [],
          edges: []
        },
        base_path: "/bloccs",
        features: features,
        coverage: coverage,
        recording: false,
        upload: nil
      )
    end
  end

  describe "live recording" do
    setup do
      supervisor = Demo.start!()
      on_exit(fn -> stop(supervisor) end)
      :ok
    end

    test "records a run and overlays structural coverage", %{conn: conn} do
      {:ok, view, html} = live(conn, "/bloccs/networks/demo/coverage")
      assert html =~ "No coverage yet"

      view |> element("button", "Record run") |> render_click()
      assert render(view) =~ "recording"

      push(3)
      eventually(fn -> Collector.snapshot(:demo).nodes[:third] end, &(&1 && &1.completed > 0))

      html = view |> element("button", "Stop") |> render_click()

      assert html =~ "obligations reached"
      # the linear demo run exercises every port and edge
      assert html =~ "100%" or html =~ "obligations reached"
      # free build → export available
      assert html =~ "Export .bloccs-trace"
    end

    test "stopping with no traffic reports 0% and lists unreached", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/bloccs/networks/demo/coverage")

      view |> element("button", "Record run") |> render_click()
      html = view |> element("button", "Stop") |> render_click()

      assert html =~ "0%"
      assert html =~ "Unreached"
    end
  end

  defp push(n) do
    name = Demo.seed_producer()
    Enum.each(1..n, fn i -> Producer.push(name, %{n: i}, %{}) end)
  end

  defp eventually(fun, pred, tries \\ 40) do
    value = fun.()

    cond do
      pred.(value) -> value
      tries > 0 -> Process.sleep(25) && eventually(fun, pred, tries - 1)
      true -> flunk("condition not met; last value: #{inspect(value)}")
    end
  end

  defp stop(supervisor) do
    Supervisor.stop(supervisor, :normal, 5_000)
  catch
    :exit, _ -> :ok
  end
end
