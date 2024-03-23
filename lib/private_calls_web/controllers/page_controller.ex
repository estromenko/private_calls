defmodule PrivateCallsWeb.PageController do
  use PrivateCallsWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
