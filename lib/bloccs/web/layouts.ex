defmodule Bloccs.Web.Layouts do
  @moduledoc """
  Self-contained root and app layouts for the dashboard. The dashboard ships its
  own precompiled CSS/JS from `priv/static` (served by a dashboard-owned static
  route), so these layouts never depend on the host's assets or layout.
  """

  use Bloccs.Web, :html

  @doc "The HTML document shell. Pulls in the dashboard's own precompiled assets."
  attr :inner_content, :any, required: true
  attr :page_title, :string, default: "bloccs"

  def root(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en" class="bloccs-root">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="csrf-token" content={Phoenix.Controller.get_csrf_token()} />
        <title>{assigns[:page_title] || "bloccs"}</title>
        <link rel="stylesheet" href="/bloccs/assets/app.css" />
        <script defer type="text/javascript" src="/bloccs/assets/app.js">
        </script>
      </head>
      <body>
        {@inner_content}
      </body>
    </html>
    """
  end

  @doc "The per-page wrapper inside the live_session."
  attr :flash, :map, default: %{}
  attr :inner_content, :any, required: true

  def app(assigns) do
    ~H"""
    <div class="bloccs-app">
      {@inner_content}
    </div>
    """
  end
end
