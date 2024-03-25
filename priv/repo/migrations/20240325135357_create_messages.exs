defmodule PrivateCalls.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages) do
      add :text, :string
      add :chat_id, references(:chats, on_delete: :nothing)
      add :sender_id, references(:users, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:messages, [:chat_id])
    create index(:messages, [:sender_id])
  end
end
