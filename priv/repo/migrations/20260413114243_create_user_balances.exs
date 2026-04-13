defmodule AstraAutoEx.Repo.Migrations.CreateUserBalances do
  use Ecto.Migration

  def change do
    create table(:user_balances) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :balance, :decimal, precision: 18, scale: 6, null: false, default: 0
      add :frozen_amount, :decimal, precision: 18, scale: 6, null: false, default: 0
      add :total_spent, :decimal, precision: 18, scale: 6, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_balances, [:user_id])
  end
end
