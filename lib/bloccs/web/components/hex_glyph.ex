defmodule Bloccs.Web.HexGlyph do
  @moduledoc """
  The bloccs hexagon notation as inline SVG.

  One function component, `hex_glyph/1`, renders the canonical glyph for a node
  (the atoms `Bloccs.Introspect.glyph/1` returns) so the dashboard and the
  marketing notation stay a single visual language. Live state
  (`:idle | :running | :ok | :failed`) is a CSS class on the outer `<g>`, flipped
  by an assign — no client animation framework.

  Brand tokens (kept in sync with `marketing/notation-icons`):
  fill `#18181b`, stroke `#7028bd`, accent `#a78bfa`, mark `#fafafa`.
  """

  use Phoenix.Component

  @hex_path "M0,-52 L45,-26 L45,26 L0,52 L-45,26 L-45,-26 Z"

  @glyphs ~w(node node_effect source sink split batch join throttle delay)a

  @doc """
  Render the hexagon glyph for `glyph` at optional `x`/`y` (for placement inside
  a larger topology `<svg>`). Falls back to the plain `:node` glyph for an
  unknown atom so the viewer never crashes on a glyph it doesn't know.

  ## Attributes

    * `:glyph` — one of #{inspect(@glyphs)} (required)
    * `:state` — `:idle | :running | :ok | :failed` (default `:idle`)
    * `:label` — accessible label / `<title>` (default: the glyph name)
    * `:x`, `:y` — translate the glyph within a parent SVG (default `0`)
    * `:size` — rendered px (default `120`)
  """
  attr :glyph, :atom, required: true
  attr :state, :atom, default: :idle
  attr :label, :string, default: nil
  attr :x, :integer, default: 0
  attr :y, :integer, default: 0
  attr :size, :integer, default: 120

  def hex_glyph(assigns) do
    assigns =
      assigns
      |> assign(:glyph, normalize(assigns.glyph))
      |> assign(:hex_path, @hex_path)

    ~H"""
    <g
      class={["hex-glyph", "hex-glyph--#{@glyph}", "hex-glyph--#{@state}"]}
      transform={"translate(#{@x},#{@y})"}
    >
      <title>{@label || Atom.to_string(@glyph)}</title>
      <path class="hex-glyph__body" d={@hex_path} fill="#18181b" stroke="#7028bd" stroke-width="3" />
      {inner(assigns)}
    </g>
    """
  end

  # Convenience for templates that want a self-contained, sized <svg>.
  attr :glyph, :atom, required: true
  attr :state, :atom, default: :idle
  attr :label, :string, default: nil
  attr :size, :integer, default: 120

  def hex_glyph_svg(assigns) do
    ~H"""
    <svg
      class="hex-glyph-svg"
      viewBox="-60 -62 120 120"
      width={@size}
      height={@size}
      role="img"
      aria-label={@label || Atom.to_string(@glyph)}
    >
      <.hex_glyph glyph={@glyph} state={@state} label={@label} />
    </svg>
    """
  end

  # ---- per-glyph inner marks (ports + the distinguishing detail) ----

  defp inner(%{glyph: :node} = assigns) do
    ~H"""
    <circle cx="0" cy="0" r="3" fill="#7028bd" />
    <.ports left={[0]} right={[0]} />
    """
  end

  defp inner(%{glyph: :node_effect} = assigns) do
    ~H"""
    <path
      d="M0,-44 L38,-22 L38,22 L0,44 L-38,22 L-38,-22 Z"
      fill="none"
      stroke="#7028bd"
      stroke-width="1.5"
      opacity="0.6"
    />
    <circle cx="0" cy="0" r="3" fill="#7028bd" />
    <circle cx="0" cy="-52" r="6.5" fill="#a78bfa" stroke="#09090b" stroke-width="2" />
    <.ports left={[0]} right={[0]} />
    """
  end

  defp inner(%{glyph: :source} = assigns) do
    ~H"""
    <g stroke="#fafafa" stroke-width="4.5" fill="none" stroke-linecap="round">
      <circle cx="-8" cy="0" r="9" fill="#18181b" stroke="#fafafa" stroke-width="3" />
      <line x1="6" y1="0" x2="30" y2="0" />
      <polyline points="22,-7 30,0 22,7" stroke-width="3" />
    </g>
    <.ports right={[0]} />
    """
  end

  defp inner(%{glyph: :sink} = assigns) do
    ~H"""
    <g stroke="#fafafa" stroke-width="4.5" fill="none" stroke-linecap="round">
      <line x1="-30" y1="0" x2="-2" y2="0" />
      <circle cx="10" cy="0" r="9" fill="#18181b" stroke="#fafafa" stroke-width="3" />
    </g>
    <.ports left={[0]} />
    """
  end

  defp inner(%{glyph: :split} = assigns) do
    ~H"""
    <g stroke="#fafafa" stroke-width="4.5" fill="none" stroke-linecap="round" stroke-linejoin="round">
      <line x1="-34" y1="0" x2="-12" y2="0" />
      <polygon points="-12,0 -4,-8 4,0 -4,8" fill="#18181b" stroke="#fafafa" stroke-width="3" />
      <line x1="4" y1="0" x2="34" y2="-22" />
      <line x1="4" y1="0" x2="34" y2="22" />
    </g>
    <.ports left={[0]} right={[-22, 22]} />
    """
  end

  defp inner(%{glyph: :batch} = assigns) do
    ~H"""
    <g fill="#18181b" stroke="#fafafa" stroke-width="3">
      <rect x="-26" y="-18" width="20" height="20" rx="3" />
      <rect x="-12" y="-9" width="20" height="20" rx="3" />
      <rect x="2" y="0" width="20" height="20" rx="3" />
    </g>
    <.ports left={[0]} right={[0]} />
    """
  end

  defp inner(%{glyph: :join} = assigns) do
    ~H"""
    <g stroke="#fafafa" stroke-width="4.5" fill="none" stroke-linecap="round" stroke-linejoin="round">
      <line x1="-34" y1="-22" x2="-4" y2="0" />
      <line x1="-34" y1="22" x2="-4" y2="0" />
      <polygon points="-4,0 4,-8 12,0 4,8" fill="#18181b" stroke="#fafafa" stroke-width="3" />
      <line x1="12" y1="0" x2="34" y2="0" />
    </g>
    <.ports left={[-22, 22]} right={[0]} />
    """
  end

  defp inner(%{glyph: :throttle} = assigns) do
    ~H"""
    <g stroke="#fafafa" stroke-width="4.5" fill="none" stroke-linecap="round">
      <line x1="-34" y1="0" x2="34" y2="0" />
      <line x1="-6" y1="-16" x2="-6" y2="16" stroke-width="6" />
      <line x1="10" y1="-10" x2="10" y2="10" stroke-width="6" opacity="0.6" />
    </g>
    <.ports left={[0]} right={[0]} />
    """
  end

  defp inner(%{glyph: :delay} = assigns) do
    ~H"""
    <g stroke="#fafafa" stroke-width="3.5" fill="none" stroke-linecap="round">
      <circle cx="0" cy="0" r="16" />
      <line x1="0" y1="0" x2="0" y2="-11" />
      <line x1="0" y1="0" x2="8" y2="4" />
    </g>
    <.ports left={[0]} right={[0]} />
    """
  end

  # Port nubs on the left (in) and right (out) edges of the hexagon.
  attr :left, :list, default: []
  attr :right, :list, default: []

  defp ports(assigns) do
    ~H"""
    <%= for y <- @left do %>
      <circle cx="-45" cy={y} r="4" fill="#7028bd" stroke="#09090b" stroke-width="1.5" />
    <% end %>
    <%= for y <- @right do %>
      <circle cx="45" cy={y} r="4" fill="#7028bd" stroke="#09090b" stroke-width="1.5" />
    <% end %>
    """
  end

  @doc "Every glyph this component can render."
  @spec known() :: [atom()]
  def known, do: @glyphs

  defp normalize(glyph) when glyph in @glyphs, do: glyph
  defp normalize(_), do: :node
end
