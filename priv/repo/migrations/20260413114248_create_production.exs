defmodule AstraAutoEx.Repo.Migrations.CreateProduction do
  use Ecto.Migration

  def change do
    create table(:novel_projects, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :project_id, :binary_id, null: false
      add :analysis_model, :string
      add :image_model, :string
      add :video_model, :string
      add :audio_model, :string
      add :storyboard_llm_model, :string
      add :video_ratio, :string, default: "9:16"
      add :video_resolution, :string, default: "720p"
      add :art_style, :string
      add :tts_rate, :float
      add :auto_chain_enabled, :boolean, default: false
      add :full_auto_chain_enabled, :boolean, default: false
      timestamps()
    end

    create unique_index(:novel_projects, [:project_id])

    create table(:episodes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :project_id, :binary_id, null: false
      add :user_id, :binary_id, null: false
      add :episode_number, :integer
      add :name, :string
      add :novel_text, :text
      add :audio_url, :string
      add :audio_media_id, :binary_id
      add :srt_content, :text
      add :imported_script_text, :text
      add :imported_script_meta, :map
      add :composed_video_key, :string
      add :compose_status, :string
      add :compose_task_id, :binary_id
      timestamps()
    end

    create index(:episodes, [:project_id])

    create table(:clips, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :episode_id, references(:episodes, type: :binary_id, on_delete: :delete_all),
        null: false

      add :clip_index, :integer
      add :start_time, :float
      add :end_time, :float
      add :duration, :float
      add :content, :text
      add :summary, :text
      add :location, :string
      add :characters, :string
      add :props, :string
      add :screenplay, :text
      timestamps()
    end

    create index(:clips, [:episode_id])

    create table(:storyboards, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :clip_id, references(:clips, type: :binary_id, on_delete: :delete_all), null: false
      add :episode_id, :binary_id, null: false
      add :panel_count, :integer, default: 0
      add :storyboard_text_json, :text
      add :image_history, :map
      timestamps()
    end

    create index(:storyboards, [:episode_id])

    create table(:panels, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :storyboard_id, references(:storyboards, type: :binary_id, on_delete: :delete_all),
        null: false

      add :episode_id, :binary_id
      add :panel_index, :integer
      add :shot_type, :string
      add :camera_move, :string
      add :description, :text
      add :location, :string
      add :characters, :string
      add :props, :string
      add :image_prompt, :text
      add :image_url, :string
      add :image_media_id, :binary_id
      add :image_history, :map
      add :video_prompt, :text
      add :video_url, :string
      add :video_media_id, :binary_id
      add :lip_sync_task_id, :binary_id
      add :lip_sync_video_url, :string
      add :lip_sync_video_media_id, :binary_id
      add :sketch_image_url, :string
      add :sketch_image_media_id, :binary_id
      add :photography_rules, :text
      add :acting_notes, :text
      add :candidate_images, :map
      timestamps()
    end

    create index(:panels, [:storyboard_id])
    create index(:panels, [:episode_id])

    create table(:shots, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :episode_id, :binary_id, null: false
      add :panel_id, references(:panels, type: :binary_id, on_delete: :nilify_all)
      add :shot_index, :integer
      add :srt_start, :float
      add :srt_end, :float
      add :srt_duration, :float
      add :sequence, :integer
      add :locations, :string
      add :characters, :string
      add :plot, :text
      add :image_prompt, :text
      add :image_url, :string
      add :image_media_id, :binary_id
      add :video_url, :string
      add :video_media_id, :binary_id
      add :scale, :string
      add :focus, :string
      add :pov, :string
      timestamps()
    end

    create index(:shots, [:episode_id])

    create table(:voice_lines, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :episode_id, :binary_id, null: false
      add :panel_id, references(:panels, type: :binary_id, on_delete: :nilify_all)
      add :line_index, :integer
      add :speaker, :string
      add :content, :text
      add :audio_url, :string
      add :audio_media_id, :binary_id
      add :audio_duration, :float
      add :voice_preset_id, :string
      add :voice_type, :string
      add :emotion_prompt, :string
      add :emotion_strength, :float
      add :matched_panel_id, :binary_id
      add :matched_panel_index, :integer
      timestamps()
    end

    create index(:voice_lines, [:episode_id])
  end
end
