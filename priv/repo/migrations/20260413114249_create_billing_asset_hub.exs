defmodule AstraAutoEx.Repo.Migrations.CreateBillingAssetHub do
  use Ecto.Migration

  def change do
    # ── Billing ──

    create table(:balance_freezes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :task_id, :binary_id
      add :amount, :decimal, precision: 18, scale: 6, null: false
      add :status, :string, null: false, default: "pending"
      add :idempotency_key, :string
      add :metadata, :map
      timestamps()
    end

    create unique_index(:balance_freezes, [:idempotency_key],
             where: "idempotency_key IS NOT NULL"
           )

    create index(:balance_freezes, [:user_id])
    create index(:balance_freezes, [:task_id])

    create table(:balance_transactions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :type, :string, null: false
      add :amount, :decimal, precision: 18, scale: 6, null: false
      add :balance_after, :decimal, precision: 18, scale: 6
      add :freeze_id, :binary_id
      add :description, :string
      add :metadata, :map
      timestamps(updated_at: false)
    end

    create index(:balance_transactions, [:user_id])

    create table(:usage_costs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :project_id, :binary_id
      add :task_id, :binary_id
      add :task_type, :string
      add :api_type, :string
      add :model, :string
      add :provider, :string
      add :quantity, :decimal, precision: 18, scale: 6
      add :unit, :string
      add :cost, :decimal, precision: 18, scale: 6
      add :action, :string
      add :metadata, :map
      timestamps(updated_at: false)
    end

    create index(:usage_costs, [:user_id])
    create index(:usage_costs, [:project_id])

    # ── Asset Hub ──

    create table(:global_asset_folders, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :description, :string
      timestamps()
    end

    create index(:global_asset_folders, [:user_id])

    create table(:global_characters, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :folder_id, references(:global_asset_folders, type: :binary_id, on_delete: :nilify_all)
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

    create index(:global_characters, [:user_id])

    create table(:global_character_appearances, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :global_character_id,
          references(:global_characters, type: :binary_id, on_delete: :delete_all), null: false

      add :appearance_index, :integer, default: 0
      add :art_style, :string
      add :description, :text
      add :descriptions, {:array, :string}, default: []
      add :image_url, :string
      add :image_media_id, :binary_id
      timestamps()
    end

    create index(:global_character_appearances, [:global_character_id])

    create table(:global_locations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :folder_id, references(:global_asset_folders, type: :binary_id, on_delete: :nilify_all)
      add :name, :string, null: false
      add :art_style, :string
      add :summary, :text
      timestamps()
    end

    create index(:global_locations, [:user_id])

    create table(:global_location_images, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :global_location_id,
          references(:global_locations, type: :binary_id, on_delete: :delete_all), null: false

      add :image_index, :integer, default: 0
      add :description, :text
      add :available_slots, :integer
      add :image_url, :string
      add :image_media_id, :binary_id
      add :is_selected, :boolean, default: false
      timestamps()
    end

    create index(:global_location_images, [:global_location_id])

    create table(:global_voices, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :folder_id, references(:global_asset_folders, type: :binary_id, on_delete: :nilify_all)
      add :name, :string, null: false
      add :voice_id, :string
      add :voice_type, :string, default: "custom"
      add :custom_voice_url, :string
      add :custom_voice_media_id, :binary_id
      add :voice_prompt, :text
      add :gender, :string
      add :language, :string, default: "zh"
      add :description, :text
      timestamps()
    end

    create index(:global_voices, [:user_id])
  end
end
