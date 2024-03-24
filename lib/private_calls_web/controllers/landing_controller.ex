defmodule PrivateCallsWeb.LandingController do
  use PrivateCallsWeb, :controller

  def index(conn, _params) do
    render(conn, :index)
  end
end
