defmodule AstraAutoEx.Repo.Migrations.CreateProjects do
  use Ecto.Migration

  def change do
    create table(:projects) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :description, :text
      add :type, :string, null: false, default: "standard"
      add :status, :string, null: false, default: "active"
      add :aspect_ratio, :string, default: "16:9"
      add :settings, :map, default: %{}
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:projects, [:user_id])
    create index(:projects, [:user_id, :status])
  end
end
