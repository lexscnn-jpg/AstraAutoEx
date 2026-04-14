defmodule AstraAutoEx.Repo.Migrations.AddIterationV061Tables do
  use Ecto.Migration

  def change do
    # ── API Call Logs (Billing) ──
    create table(:api_call_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, :integer, null: false
      add :project_id, :integer
      add :project_name, :string
      add :model_key, :string, null: false
      add :model_type, :string, null: false
      add :pipeline_step, :string, null: false
      add :input_tokens, :integer, default: 0
      add :output_tokens, :integer, default: 0
      add :status, :string, null: false, default: "success"
      add :cost_estimate, :decimal
      add :duration_ms, :integer, default: 0
      add :metadata, :map, default: %{}

      timestamps()
    end

    create index(:api_call_logs, [:user_id])
    create index(:api_call_logs, [:user_id, :project_id])
    create index(:api_call_logs, [:user_id, :model_key])
    create index(:api_call_logs, [:inserted_at])

    # ── Global Props ──
    create table(:global_props, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, :integer, null: false
      add :folder_id, references(:global_asset_folders, type: :binary_id, on_delete: :nilify_all)
      add :name, :string, null: false
      add :prop_type, :string
      add :description, :text
      add :image_url, :string
      add :image_urls, {:array, :string}, default: []
      add :selected_index, :integer, default: 0
      add :previous_image_url, :string

      timestamps()
    end

    create index(:global_props, [:user_id])

    # ── Global SFX ──
    create table(:global_sfx, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, :integer, null: false
      add :folder_id, references(:global_asset_folders, type: :binary_id, on_delete: :nilify_all)
      add :name, :string, null: false
      add :category, :string
      add :description, :text
      add :audio_url, :string
      add :duration_ms, :integer

      timestamps()
    end

    create index(:global_sfx, [:user_id])

    # ── Global BGM ──
    create table(:global_bgm, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, :integer, null: false
      add :folder_id, references(:global_asset_folders, type: :binary_id, on_delete: :nilify_all)
      add :name, :string, null: false
      add :category, :string
      add :description, :text
      add :audio_url, :string
      add :duration_ms, :integer
      add :prompt, :text
      add :lyrics, :text
      add :is_instrumental, :boolean, default: false

      timestamps()
    end

    create index(:global_bgm, [:user_id])

    # ── Panel extensions for first/last frame ──
    alter table(:panels) do
      add_if_not_exists :first_last_frame_prompt, :text
      add_if_not_exists :fl_video_url, :string
      add_if_not_exists :video_generation_mode, :string, default: "normal"
    end

    # ── NovelProject extension for custom art style prompt ──
    alter table(:novel_projects) do
      add_if_not_exists :art_style_prompt, :text
    end
  end
end
