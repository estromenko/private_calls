defmodule PrivateCalls.MessagesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `PrivateCalls.Messages` context.
  """

  @doc """
  Generate a message.
  """
  def make_chat_and_user() do
    {:ok, user} =
      PrivateCalls.Users.register_user(%{
        email: "admin@admin.admin",
        password: "adminadminadmin"
      })

    {:ok, chat} =
      PrivateCalls.Chats.create_chat(%{
        name: "general",
        owner_id: user.id
      })

    {chat, user}
  end

  def message_fixture(attrs \\ %{}) do
    {chat, user} = make_chat_and_user()

    {:ok, message} =
      attrs
      |> Enum.into(%{
        text: "some text",
        chat_id: chat.id,
        sender_id: user.id
      })
      |> PrivateCalls.Messages.create_message()

    message
  end
end
