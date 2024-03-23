defmodule PrivateCallsWeb.PageController do
  alias PrivateCalls.Chats
  use PrivateCallsWeb, :controller

  def home(conn, _params) do
    render(conn, :home, layout: false, chats: Chats.list_chats())
  end
end
