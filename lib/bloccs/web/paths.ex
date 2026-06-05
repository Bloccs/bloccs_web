defmodule Bloccs.Web.Paths do
  @moduledoc """
  Builds dashboard URLs from the mount base path (e.g. `"/bloccs"`), which the
  router macro stashes in the session. A library can't use the host's `~p`
  verified routes, so paths are assembled here from one source of truth.
  """

  @spec networks(String.t()) :: String.t()
  def networks(base), do: "#{base}/networks"

  @spec topology(String.t(), atom() | String.t()) :: String.t()
  def topology(base, id), do: "#{base}/networks/#{id}"

  @spec messages(String.t(), atom() | String.t()) :: String.t()
  def messages(base, id), do: "#{base}/networks/#{id}/messages"

  @spec metrics(String.t(), atom() | String.t()) :: String.t()
  def metrics(base, id), do: "#{base}/networks/#{id}/metrics"

  @spec coverage(String.t(), atom() | String.t()) :: String.t()
  def coverage(base, id), do: "#{base}/networks/#{id}/coverage"
end
