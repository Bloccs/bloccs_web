defmodule Bloccs.Web.DashboardLiveTest do
  use Bloccs.Web.ConnCase, async: false

  alias Bloccs.{Introspect, Producer, Trace}

  describe "a network that has stopped" do
    test "renders the not-found panel instead of crashing", %{conn: conn} do
      # Start then stop, so the `:demo` atom exists (String.to_existing_atom
      # succeeds) but the network is no longer registered — Introspect.network/1
      # returns {:error, :not_found}. This is the race that used to crash the
      # LiveView with a CaseClauseError.
      supervisor = Demo.start!()
      Supervisor.stop(supervisor, :normal, 5_000)
      eventually(fn -> Introspect.network(:demo) end, &(&1 == {:error, :not_found}))

      {:ok, _view, html} = live(conn, "/bloccs/networks/demo")
      assert html =~ "Network not found"
    end
  end

  describe "loading a .bloccs-trace" do
    setup do
      supervisor = Demo.start!()
      on_exit(fn -> stop(supervisor) end)
      :ok
    end

    test "uploads a trace file and renders structural coverage", %{conn: conn} do
      # Produce a real trace from a recorded run, dumped to a .bloccs-trace file.
      rec = Trace.record(:demo)
      push(3)
      eventually(fn -> snapshot_completed() end, &(&1 && &1 > 0))
      events = Trace.stop(rec)

      path =
        Path.join(System.tmp_dir!(), "demo-#{System.unique_integer([:positive])}.bloccs-trace")

      :ok = Trace.dump(events, :demo, path)
      on_exit(fn -> File.rm(path) end)

      {:ok, view, _html} = live(conn, "/bloccs/networks/demo/coverage")

      file =
        file_input(view, "form.bloccs-coverage__upload", :trace, [
          %{name: "run.bloccs-trace", content: File.read!(path), type: "application/octet-stream"}
        ])

      render_upload(file, "run.bloccs-trace")
      html = view |> element("form.bloccs-coverage__upload") |> render_submit()

      # the load path produced a structural coverage report from the trace file
      assert html =~ "obligations reached"
      assert html =~ "from a loaded .bloccs-trace"
    end
  end

  defp snapshot_completed do
    case Bloccs.Web.Telemetry.Collector.snapshot(:demo).nodes[:third] do
      %{completed: c} -> c
      _ -> nil
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
