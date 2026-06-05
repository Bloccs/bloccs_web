defmodule Bloccs.Web.Panels.MessagesTest do
  use Bloccs.Web.ConnCase, async: false

  alias Bloccs.Producer
  alias Bloccs.Web.Telemetry.Collector

  setup do
    supervisor = Demo.start!()
    on_exit(fn -> stop(supervisor) end)
    :ok
  end

  test "real telemetry produces edge-traversal flow events", %{conn: _conn} do
    push(4)

    events =
      eventually(
        fn -> Collector.flow_snapshot(:demo).events end,
        &Enum.any?(&1, fn e -> e.node == :first and match?({:second, _}, e.to) end)
      )

    edge = Enum.find(events, &(&1.node == :first))
    assert edge.to == {:second, :n}
    assert edge.outcome == :ok
    # the emitting node's latency is paired onto the edge
    assert is_number(edge.duration_ms)
  end

  test "the panel renders the feed and reflects a live flow frame", %{conn: conn} do
    {:ok, view, html} = live(conn, "/bloccs/networks/demo/messages")
    assert html =~ "Messages"

    frame = %{
      rate: 7,
      series: for(_ <- 1..60, do: %{ok: 2, failed: 0, dropped: 0, other: 0, total: 2}),
      events: [
        %{
          node: :first,
          out_port: :n,
          to: {:second, :n},
          outcome: :ok,
          duration_ms: 0.4,
          reason: nil,
          at: 1_700_000_000_123
        },
        %{
          node: :second,
          out_port: :n,
          to: {:third, :n},
          outcome: :failed,
          duration_ms: 1.2,
          reason: :boom,
          at: 1_700_000_000_120
        }
      ]
    }

    send(view.pid, {:bloccs_flow, :demo, frame})
    rendered = render(view)

    assert rendered =~ "first.n → second.n"
    assert rendered =~ "second.n → third.n"
    assert rendered =~ "7/s"
    assert rendered =~ "bloccs-pill--failed"
  end

  test "filtering by outcome narrows the feed", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/bloccs/networks/demo/messages")

    frame = %{
      rate: 0,
      series: [],
      events: [
        %{
          node: :first,
          out_port: :n,
          to: {:second, :n},
          outcome: :ok,
          duration_ms: 0.4,
          reason: nil,
          at: 1_700_000_000_123
        },
        %{
          node: :second,
          out_port: :n,
          to: nil,
          outcome: :failed,
          duration_ms: 1.2,
          reason: :boom,
          at: 1_700_000_000_120
        }
      ]
    }

    send(view.pid, {:bloccs_flow, :demo, frame})
    render(view)

    filtered =
      view
      |> form("form[phx-change=flow_filter]", %{"node" => "", "outcome" => "failed"})
      |> render_change()

    assert filtered =~ "second.n → ·"
    refute filtered =~ "first.n → second.n"
  end

  defp push(n) do
    name = Bloccs.Router.producer_name(:demo, :first, :n)
    Enum.each(1..n, fn i -> Producer.push(name, %{n: i}, %{}) end)
  end

  defp eventually(fun, pred, tries \\ 40) do
    value = fun.()

    cond do
      pred.(value) -> value
      tries > 0 -> Process.sleep(25) && eventually(fun, pred, tries - 1)
      true -> flunk("condition not met; last: #{inspect(value)}")
    end
  end

  defp stop(supervisor) do
    Supervisor.stop(supervisor, :normal, 5_000)
  catch
    :exit, _ -> :ok
  end
end
