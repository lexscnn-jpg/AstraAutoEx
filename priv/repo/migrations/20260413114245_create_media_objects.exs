defmodule AstraAutoEx.Repo.Migrations.CreateMediaObjects do
  use Ecto.Migration

  def change do
    create table(:media_objects, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :public_id, :string, null: false
      add :storage_key, :string, size: 512, null: false
      add :sha256, :string
      add :mime_type, :string
      add :size_bytes, :bigint
      add :width, :integer
      add :height, :integer
      add :duration_ms, :integer

      timestamps()
    end

    create unique_index(:media_objects, [:public_id])
    create unique_index(:media_objects, [:storage_key])
    create index(:media_objects, [:inserted_at])
  end
end
