defmodule AstraAutoEx.Repo.Migrations.AddPublicIdToEpisodes do
  use Ecto.Migration

  def change do
    alter table(:episodes) do
      add :public_id, :string, size: 12
    end

    create unique_index(:episodes, [:public_id])
  end
end
