defmodule Bloccs.Web.Components.Chart do
  @moduledoc """
  Server-rendered SVG charts for the Messages panel — no client charting library.
  `throughput/1` is an events-per-second volume chart (one bar per 1s bucket,
  failures stacked in red, à la Sentry); `sparkline/1` is a tiny inline line.
  The series is computed by `Bloccs.Web.Telemetry.Flow` and redrawn each frame.
  """

  use Phoenix.Component

  @w 720
  @h 80
  @pad_top 14
  @pad_bottom 1

  attr :series, :list, required: true

  def throughput(assigns) do
    series = assigns.series
    max = series |> Enum.map(& &1.total) |> Enum.max(fn -> 0 end) |> max(1)
    n = max(length(series), 1)
    bw = @w / n
    plot = @h - @pad_top - @pad_bottom

    bars =
      series
      |> Enum.with_index()
      |> Enum.map(fn {b, i} ->
        total_h = b.total / max * plot
        fail_h = (b[:failed] || 0) / max * plot

        %{
          x: Float.round(i * bw + bw * 0.12, 2),
          w: Float.round(bw * 0.76, 2),
          total_y: Float.round(@h - @pad_bottom - total_h, 2),
          total_h: Float.round(total_h, 2),
          fail_y: Float.round(@h - @pad_bottom - fail_h, 2),
          fail_h: Float.round(fail_h, 2),
          total: b.total,
          failed: b[:failed] || 0
        }
      end)

    assigns =
      assign(assigns,
        w: @w,
        h: @h,
        max: max,
        bars: bars,
        empty: max <= 1 and total_of(series) == 0
      )

    ~H"""
    <svg
      class="bloccs-chart"
      viewBox={"0 0 #{@w} #{@h}"}
      width="100%"
      height={@h}
      preserveAspectRatio="none"
      role="img"
      aria-label="events per second"
    >
      <line class="bloccs-chart__baseline" x1="0" y1={@h - 1} x2={@w} y2={@h - 1} />
      <g :for={b <- @bars}>
        <title>{b.total}/s{if b.failed > 0, do: " · #{b.failed} failed"}</title>
        <rect
          :if={b.total_h > 0}
          class="bloccs-chart__bar"
          x={b.x}
          y={b.total_y}
          width={b.w}
          height={b.total_h}
          rx="1"
        />
        <rect
          :if={b.fail_h > 0}
          class="bloccs-chart__bar-fail"
          x={b.x}
          y={b.fail_y}
          width={b.w}
          height={b.fail_h}
          rx="1"
        />
      </g>
      <text class="bloccs-chart__peak" x="8" y="14">peak {@max}/s</text>
      <text :if={@empty} class="bloccs-chart__peak" x={@w / 2} y={@h / 2} text-anchor="middle">
        waiting for traffic
      </text>
    </svg>
    """
  end

  defp total_of(series), do: series |> Enum.map(& &1.total) |> Enum.sum()

  @sw 84
  @sh 22

  attr :values, :list, required: true

  @doc "A tiny inline sparkline for a list of numbers (per-node throughput, etc.)."
  def sparkline(assigns) do
    values = assigns.values || []
    max = values |> Enum.max(fn -> 0 end) |> max(1)
    n = max(length(values), 1)

    pts =
      values
      |> Enum.with_index()
      |> Enum.map_join(" ", fn {v, i} ->
        sx = if n == 1, do: @sw, else: Float.round(i / (n - 1) * @sw, 1)
        sy = Float.round(@sh - 1 - v / max * (@sh - 2), 1)
        "#{sx},#{sy}"
      end)

    assigns =
      assign(assigns, sw: @sw, sh: @sh, pts: pts, empty: values == [] or Enum.sum(values) == 0)

    ~H"""
    <svg
      class="bloccs-spark"
      viewBox={"0 0 #{@sw} #{@sh}"}
      width={@sw}
      height={@sh}
      aria-hidden="true"
    >
      <polyline :if={not @empty} class="bloccs-spark__line" points={@pts} fill="none" />
      <line :if={@empty} class="bloccs-spark__zero" x1="0" y1={@sh - 1} x2={@sw} y2={@sh - 1} />
    </svg>
    """
  end
end
