defmodule Bloccs.Web.Panels.Coverage do
  @moduledoc """
  Panel 4 — coverage overlay + `.bloccs-trace` viewer (P5).
  """

  use Bloccs.Web, :html

  attr :network, :any, required: true
  attr :base_path, :string, required: true
  attr :features, :any, required: true
  attr :coverage, :any, default: nil

  def render(assigns) do
    ~H"""
    <section class="bloccs-empty">
      <p><strong>Coverage</strong> — coming online in P5.</p>
    </section>
    """
  end
end
