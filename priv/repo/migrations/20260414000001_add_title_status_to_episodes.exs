defmodule AstraAutoEx.Repo.Migrations.AddTitleStatusToEpisodes do
  use Ecto.Migration

  def change do
    alter table(:episodes) do
      add :title, :string
      add :status, :string, default: "draft"
    end
  end
end
