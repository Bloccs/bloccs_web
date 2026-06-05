defmodule Bloccs.Web.Panels.Topology do
  @moduledoc """
  Panel 2 — the network graph in the bloccs hexagon notation (P3).
  """

  use Bloccs.Web, :html

  attr :network, :any, required: true
  attr :base_path, :string, required: true
  attr :states, :map, default: %{}

  def render(assigns) do
    ~H"""
    <section class="bloccs-empty">
      <p><strong>Topology</strong> — coming online in P3.</p>
    </section>
    """
  end
end
