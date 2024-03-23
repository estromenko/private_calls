defmodule PrivateCallsWeb.AppComponents do
  use PrivateCallsWeb, :html
  use Phoenix.Component
  alias PrivateCalls.Users.User

  embed_templates "app_components/*"

  attr :current_user, User, default: nil
  def app_header(assigns)
end
