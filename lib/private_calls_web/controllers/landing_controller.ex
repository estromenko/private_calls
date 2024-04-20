defmodule PrivateCallsWeb.LandingController do
  use PrivateCallsWeb, :controller

  def index(conn, _params) do
    if conn.assigns.current_user do
      redirect(conn, to: ~p"/chats/")
    else
      render(conn, :index)
    end
  end
end
