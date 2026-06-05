defmodule Bloccs.Web.Panels.MetricsTest do
  use Bloccs.Web.ConnCase, async: false

  alias Bloccs.Producer
  alias Bloccs.Web.Telemetry.Collector

  setup do
    supervisor = Demo.start!()
    on_exit(fn -> stop(supervisor) end)
    :ok
  end

  test "real telemetry folds into the collector as messages flow", %{conn: _conn} do
    push(3)

    metrics =
      eventually(fn -> Collector.snapshot(:demo).nodes[:first] end, &(&1 && &1.completed > 0))

    assert metrics.completed >= 1
    assert metrics.state in [:ok, :running]
  end

  test "the metrics panel renders a row per node and reflects a live frame", %{conn: conn} do
    {:ok, view, html} = live(conn, "/bloccs/networks/demo/metrics")

    assert html =~ "Live metrics"
    # one row per node (first/second/third)
    assert html =~ "first"
    assert html =~ "second"
    assert html =~ "third"

    # Deliver a synthetic frame and assert the panel reflects it (a flipped pill).
    frame = %{
      nodes: %{
        first: node_view(:ok, 12.5),
        second: node_view(:running, nil),
        third: node_view(:idle, nil)
      },
      updated_at: 1
    }

    send(view.pid, {:bloccs_frame, :demo, frame})
    rendered = render(view)

    assert rendered =~ "bloccs-pill--ok"
    assert rendered =~ "12.5ms" or rendered =~ "13ms"
  end

  defp node_view(state, p95) do
    %{state: state, completed: 4, errors: 0, error_rate: 0.0, throughput: 2.0, p50: p95, p95: p95}
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
