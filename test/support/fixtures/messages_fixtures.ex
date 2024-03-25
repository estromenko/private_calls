defmodule PrivateCalls.MessagesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `PrivateCalls.Messages` context.
  """

  @doc """
  Generate a message.
  """
  def message_fixture(attrs \\ %{}) do
    {:ok, message} =
      attrs
      |> Enum.into(%{
        text: "some text"
      })
      |> PrivateCalls.Messages.create_message()

    message
  end
end
