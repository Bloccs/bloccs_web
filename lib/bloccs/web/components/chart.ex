defmodule Bloccs.Web.Components.Chart do
  @moduledoc """
  A tiny server-rendered SVG throughput chart for the Messages panel: a filled
  area for total events/second with a red overlay line for failures. No client
  charting library — the series is computed by `Bloccs.Web.Telemetry.Flow` and
  redrawn each frame.
  """

  use Phoenix.Component

  @w 720
  @h 120

  attr :series, :list, required: true

  def throughput(assigns) do
    series = assigns.series
    max = series |> Enum.map(& &1.total) |> Enum.max(fn -> 0 end) |> max(1)
    n = max(length(series), 1)

    assigns =
      assigns
      |> assign(:w, @w)
      |> assign(:h, @h)
      |> assign(:max, max)
      |> assign(:area, area_path(series, n, max))
      |> assign(:fail_line, line_path(series, n, max, & &1.failed))

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
      <path class="bloccs-chart__area" d={@area} />
      <path class="bloccs-chart__fail" d={@fail_line} fill="none" />
      <text class="bloccs-chart__peak" x="6" y="14">{@max}/s peak</text>
    </svg>
    """
  end

  defp x(i, n), do: i / max(n - 1, 1) * @w
  defp y(v, max), do: @h - v / max * (@h - 16) - 2

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
