defmodule PrivateCalls.Messages.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "messages" do
    field :text, :string
    field :chat_id, :id
    field :sender_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:text, :chat_id, :sender_id])
    |> validate_required([:text, :chat_id, :sender_id])
  end
end
