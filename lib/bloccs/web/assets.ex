defmodule Bloccs.Web.Assets do
  @moduledoc """
  Serves the dashboard's own precompiled `app.css` / `app.js` from
  `priv/static/assets`, so the host needs no `Plug.Static` configuration and the
  bundles can't collide with the host's own assets.

  `forward`ed by `bloccs_dashboard/2` at `<path>/assets`, so the filename arrives
  as the remaining `path_info` segment. A long `cache-control` is safe because
  the filenames are content-stable per release.
  """

  @behaviour Plug

  @types %{
    "app.css" => "text/css",
    "app.js" => "application/javascript",
    "mark.svg" => "image/svg+xml"
  }

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%Plug.Conn{path_info: path_info} = conn, _opts) do
    serve(conn, List.last(path_info))
  end

  defp serve(conn, file) when is_binary(file) do
    case Map.fetch(@types, Path.basename(file)) do
      {:ok, content_type} ->
        path = Path.join(:code.priv_dir(:bloccs_web), "static/assets/#{Path.basename(file)}")

        if File.regular?(path) do
          conn
          |> Plug.Conn.put_resp_header("content-type", content_type)
          |> Plug.Conn.put_resp_header("cache-control", "public, max-age=31536000")
          |> Plug.Conn.send_file(200, path)
          |> Plug.Conn.halt()
        else
          not_found(conn)
        end

      :error ->
        not_found(conn)
    end
  end

  defp serve(conn, _), do: not_found(conn)

  defp not_found(conn) do
    conn
    |> Plug.Conn.send_resp(404, "not found")
    |> Plug.Conn.halt()
  end
end
