defmodule PrivateCalls.Repo.Migrations.MakeChatOwnerNullable do
  use Ecto.Migration

  def change do
    drop constraint(:chats, "chats_owner_fkey")

    alter table(:chats) do
      modify :owner, references(:users, on_delete: :nilify_all), null: true
    end
  end
end
