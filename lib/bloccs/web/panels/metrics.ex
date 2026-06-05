defmodule Bloccs.Web.Panels.Metrics do
  @moduledoc """
  Panel 3 — live per-node metrics (P4).
  """

  use Bloccs.Web, :html

  attr :network, :any, required: true
  attr :base_path, :string, required: true
  attr :frame, :map, default: %{nodes: %{}, updated_at: nil}

  def render(assigns) do
    ~H"""
    <section class="bloccs-empty">
      <p><strong>Live metrics</strong> — coming online in P4.</p>
    </section>
    """
  end
end
