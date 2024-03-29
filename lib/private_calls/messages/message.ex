defmodule PrivateCalls.Messages.Message do
  alias PrivateCalls.Users.User
  use Ecto.Schema
  import Ecto.Changeset

  schema "messages" do
    field :text, :string
    field :chat_id, :id
    belongs_to :sender, User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:text, :chat_id, :sender_id])
    |> validate_required([:text, :chat_id, :sender_id])
  end
end
