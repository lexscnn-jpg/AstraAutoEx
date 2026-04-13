defmodule AstraAutoEx.Repo.Migrations.AddPromptOverridesToUserPreferences do
  use Ecto.Migration

  def change do
    alter table(:user_preferences) do
      add :prompt_overrides, :map, default: %{}
    end
  end
end
