defmodule AstraAutoEx.Repo.Migrations.AlterUserPreferencesProviderConfigs do
  use Ecto.Migration

  def change do
    alter table(:user_preferences) do
      remove :provider_configs
      add :provider_configs, :map, default: %{}
    end
  end
end
