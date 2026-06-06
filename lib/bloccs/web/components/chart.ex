defmodule Bloccs.Web.Components.Chart do
  @moduledoc """
  A tiny server-rendered SVG throughput chart for the Messages panel: a filled
  gradient area for total events/second with a red overlay line for failures and
  a dot on the latest value. No client charting library — the series is computed
  by `Bloccs.Web.Telemetry.Flow` and redrawn each frame.
  """

  use Phoenix.Component

  @w 720
  @h 72
  @pad_top 16
  @pad_bottom 4

  attr :series, :list, required: true

  def throughput(assigns) do
    series = assigns.series
    max = series |> Enum.map(& &1.total) |> Enum.max(fn -> 0 end) |> max(1)
    n = max(length(series), 1)
    last = List.last(series)

    assigns =
      assigns
      |> assign(:w, @w)
      |> assign(:h, @h)
      |> assign(:max, max)
      |> assign(:area, area_path(series, n, max))
      |> assign(:line, line_path(series, n, max, & &1.total))
      |> assign(:fail_line, line_path(series, n, max, & &1.failed))
      |> assign(:last_x, if(last, do: Float.round(x(n - 1, n), 1), else: 0))
      |> assign(:last_y, if(last, do: Float.round(y(last.total, max), 1), else: @h))
      |> assign(:has_last, last != nil && last.total > 0)

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
      <defs>
        <linearGradient id="bloccs-chart-grad" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stop-color="var(--bloccs-accent)" stop-opacity="0.5" />
          <stop offset="100%" stop-color="var(--bloccs-accent)" stop-opacity="0.03" />
        </linearGradient>
      </defs>
      <line class="bloccs-chart__baseline" x1="0" y1={@h - 1} x2={@w} y2={@h - 1} />
      <path class="bloccs-chart__area" d={@area} />
      <path class="bloccs-chart__line" d={@line} fill="none" />
      <path class="bloccs-chart__fail" d={@fail_line} fill="none" />
      <circle :if={@has_last} class="bloccs-chart__dot" cx={@last_x} cy={@last_y} r="3" />
      <text class="bloccs-chart__peak" x="8" y="15">peak {@max}/s</text>
    </svg>
    """
  end

  defp x(i, n), do: i / max(n - 1, 1) * @w
  defp y(v, max), do: @h - v / max * (@h - @pad_top - @pad_bottom) - @pad_bottom

  defp area_path([], _n, _max), do: "M0,#{@h} L#{@w},#{@h} Z"

  defp area_path(series, n, max) do
    pts =
      series
      |> Enum.with_index()
      |> Enum.map(fn {b, i} ->
        "#{Float.round(x(i, n), 1)},#{Float.round(y(b.total, max), 1)}"
      end)
      |> Enum.join(" L")

    "M0,#{@h} L#{pts} L#{@w},#{@h} Z"
  end

  defp line_path([], _n, _max, _getter), do: ""

  defp line_path(series, n, max, getter) do
    series
    |> Enum.with_index()
    |> Enum.map(fn {b, i} ->
      "#{Float.round(x(i, n), 1)},#{Float.round(y(getter.(b), max), 1)}"
    end)
    |> Enum.join(" L")
    |> then(&"M#{&1}")
  end
end
