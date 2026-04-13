defmodule AstraAutoEx.Repo.Migrations.CreateUserPreferences do
  use Ecto.Migration

  def change do
    create table(:user_preferences) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :provider_configs, :binary
      add :model_selections, :map, default: %{}
      add :storage_config, :map, default: %{}
      add :theme, :string, null: false, default: "system"
      add :locale, :string, null: false, default: "zh"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_preferences, [:user_id])
  end
end
