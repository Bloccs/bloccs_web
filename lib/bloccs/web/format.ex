defmodule Bloccs.Web.Format do
  @moduledoc """
  Small, dependency-free formatting helpers for the dashboard: human durations,
  counts, rates, and percentages. Pure functions, easy to unit-test.
  """

  @doc """
  Render an uptime from a monotonic `started_at` (ms) relative to `now` (ms,
  defaults to the current monotonic clock). Coarse on purpose — "3d", "4h",
  "12m", "5s", or "just now".
  """
  @spec uptime(integer(), integer()) :: String.t()
  def uptime(started_at, now \\ System.monotonic_time(:millisecond))
      when is_integer(started_at) do
    duration(now - started_at)
  end

  @doc "Render a millisecond duration coarsely (largest unit only)."
  @spec duration(integer()) :: String.t()
  def duration(ms) when ms < 0, do: duration(0)
  def duration(ms) when ms < 1_000, do: "just now"
  def duration(ms) when ms < 60_000, do: "#{div(ms, 1_000)}s"
  def duration(ms) when ms < 3_600_000, do: "#{div(ms, 60_000)}m"
  def duration(ms) when ms < 86_400_000, do: "#{div(ms, 3_600_000)}h"
  def duration(ms), do: "#{div(ms, 86_400_000)}d"

  @doc "A latency in ms rendered with a unit (sub-ms shown in µs)."
  @spec latency(number() | nil) :: String.t()
  def latency(nil), do: "—"
  def latency(ms) when ms >= 1, do: "#{round_to(ms, 1)}ms"
  def latency(ms) when ms > 0, do: "#{round(ms * 1000)}µs"
  def latency(_), do: "0ms"

  @doc "A per-second rate, one decimal place."
  @spec rate(number() | nil) :: String.t()
  def rate(nil), do: "—"
  def rate(per_sec), do: "#{round_to(per_sec, 1)}/s"

  @doc "A 0.0–1.0 fraction as an integer percentage."
  @spec percent(number() | nil) :: String.t()
  def percent(nil), do: "—"
  def percent(frac), do: "#{round(frac * 100)}%"

  @doc "Compact integer count (1.2k, 3.4M)."
  @spec count(integer() | nil) :: String.t()
  def count(nil), do: "—"
  def count(n) when n < 1_000, do: Integer.to_string(n)
  def count(n) when n < 1_000_000, do: "#{round_to(n / 1_000, 1)}k"
  def count(n), do: "#{round_to(n / 1_000_000, 1)}M"

  defp round_to(value, places) do
    factor = :math.pow(10, places)
    rounded = Float.round(value / 1, places)

    # Drop a trailing ".0" so "4.0ms" reads "4ms".
    if rounded == Float.round(rounded) do
      trunc(rounded)
    else
      Float.round(rounded * factor) / factor
    end
  end
end
