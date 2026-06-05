defmodule Bloccs.Web.HexGlyphTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias Bloccs.Web.HexGlyph

  test "known/0 covers exactly the atoms Bloccs.Introspect.glyph/1 can return" do
    assert Enum.sort(HexGlyph.known()) ==
             Enum.sort(~w(node node_effect source sink split batch join throttle delay)a)
  end

  test "renders the hexagon body and a state class for each known glyph" do
    for glyph <- HexGlyph.known() do
      html = render_component(&HexGlyph.hex_glyph_svg/1, glyph: glyph, state: :running)
      assert html =~ "hex-glyph--#{glyph}"
      assert html =~ "hex-glyph--running"
      # the shared hexagon outline
      assert html =~ "M0,-52"
    end
  end

  test "falls back to :node for an unknown glyph instead of crashing" do
    html = render_component(&HexGlyph.hex_glyph_svg/1, glyph: :totally_unknown)
    assert html =~ "hex-glyph--node"
  end
end
