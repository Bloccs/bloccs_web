defmodule Bloccs.Web.ConnCase do
  @moduledoc """
  Test case for dashboard LiveView tests: brings in `Phoenix.ConnTest` /
  `Phoenix.LiveViewTest` wired to the headless test endpoint, and a fresh
  `conn`.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Plug.Conn
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest

      alias Bloccs.Web.Test.Demo

      @endpoint Bloccs.Web.Test.Endpoint
    end
  end

  setup do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
