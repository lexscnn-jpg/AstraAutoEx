defmodule AstraAutoEx.Repo.Migrations.CreateCharactersLocations do
  use Ecto.Migration

  def change do
    create table(:characters, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :project_id, :binary_id, null: false
      add :episode_id, :binary_id
      add :name, :string, null: false
      add :aliases, :string
      add :introduction, :text
      add :voice_id, :string
      add :voice_type, :string
      add :custom_voice_url, :string
      add :custom_voice_media_id, :binary_id
      add :profile_data, :map
      add :profile_confirmed, :boolean, default: false
      timestamps()
    end

    create index(:characters, [:project_id])
    create index(:characters, [:user_id])

    create table(:character_appearances, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :character_id, references(:characters, type: :binary_id, on_delete: :delete_all),
        null: false

      add :appearance_index, :integer, default: 0
      add :change_reason, :string
      add :description, :text
      add :descriptions, {:array, :string}, default: []
      add :image_url, :string
      add :image_media_id, :binary_id
      add :previous_description, :text
      add :previous_image_url, :string
      timestamps()
    end

    create index(:character_appearances, [:character_id])

    create table(:locations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :project_id, :binary_id, null: false
      add :episode_id, :binary_id
      add :name, :string, null: false
      add :summary, :text
      add :asset_kind, :string
      timestamps()
    end

    create index(:locations, [:project_id])

    create table(:location_images, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :location_id, references(:locations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :image_index, :integer, default: 0
      add :description, :text
      add :available_slots, :integer
      add :image_url, :string
      add :image_media_id, :binary_id
      add :is_selected, :boolean, default: false
      timestamps()
    end

    create index(:location_images, [:location_id])
  end
end
