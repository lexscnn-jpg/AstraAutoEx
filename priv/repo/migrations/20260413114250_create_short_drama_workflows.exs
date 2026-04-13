defmodule AstraAutoEx.Repo.Migrations.CreateShortDramaWorkflows do
  use Ecto.Migration

  def change do
    # ── Short Drama ──

    create table(:series_plans, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :project_id, :binary_id, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :stage, :string, default: "topic_selection"
      add :topic_report, :text
      add :story_outline, :text
      add :characters, :text
      add :episode_directory, :text
      add :compliance_result, :text
      add :quality_reviews, :text
      add :overseas_adaptation, :text
      add :metadata, :map
      timestamps()
    end

    create index(:series_plans, [:project_id])

    create table(:episode_scripts, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :series_plan_id, references(:series_plans, type: :binary_id, on_delete: :delete_all),
        null: false

      add :episode_number, :integer
      add :title, :string
      add :conflict, :text
      add :script_content, :text
      add :quality_score, :float
      add :quality_report, :text
      add :compliance_status, :string
      add :status, :string, default: "draft"
      timestamps()
    end

    create index(:episode_scripts, [:series_plan_id])

    # ── Workflows ──

    create table(:graph_runs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :project_id, :binary_id, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :workflow_type, :string, null: false
      add :task_type, :string
      add :target_type, :string
      add :target_id, :string
      add :status, :string, default: "queued"
      add :input, :map
      add :output, :map
      add :error_message, :text
      add :started_at, :utc_datetime
      add :finished_at, :utc_datetime
      add :lease_owner, :string
      add :lease_expires_at, :utc_datetime
      timestamps()
    end

    create index(:graph_runs, [:project_id, :status])
    create index(:graph_runs, [:user_id])

    create table(:graph_steps, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :run_id, references(:graph_runs, type: :binary_id, on_delete: :delete_all), null: false
      add :step_key, :string, null: false
      add :step_index, :integer
      add :step_total, :integer
      add :status, :string, default: "pending"
      add :current_attempt, :integer, default: 0
      add :error_code, :string
      add :error_message, :text
      add :started_at, :utc_datetime
      add :finished_at, :utc_datetime
      timestamps()
    end

    create unique_index(:graph_steps, [:run_id, :step_key])

    create table(:graph_step_attempts, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :step_id, references(:graph_steps, type: :binary_id, on_delete: :delete_all),
        null: false

      add :attempt_number, :integer, null: false
      add :provider, :string
      add :model_key, :string
      add :input_hash, :string
      add :output_text, :text
      add :output_reasoning, :text
      add :usage_json, :map
      add :error_code, :string
      add :error_message, :text
      add :started_at, :utc_datetime
      add :finished_at, :utc_datetime
      timestamps()
    end

    create index(:graph_step_attempts, [:step_id])

    create table(:graph_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :run_id, references(:graph_runs, type: :binary_id, on_delete: :delete_all), null: false
      add :seq, :integer, null: false
      add :lane, :string
      add :step_key, :string
      add :attempt, :integer
      add :event_type, :string, null: false
      add :payload, :map
      timestamps(updated_at: false)
    end

    create unique_index(:graph_events, [:run_id, :seq])

    create table(:graph_checkpoints, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :run_id, references(:graph_runs, type: :binary_id, on_delete: :delete_all), null: false
      add :step_key, :string
      add :node_key, :string
      add :version, :integer, default: 1
      add :state_json, :map
      add :state_bytes, :binary
      timestamps()
    end

    create index(:graph_checkpoints, [:run_id])

    create table(:graph_artifacts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :run_id, references(:graph_runs, type: :binary_id, on_delete: :delete_all), null: false
      add :step_key, :string
      add :artifact_type, :string, null: false
      add :ref_id, :string
      add :version_hash, :string
      add :payload, :map
      timestamps()
    end

    create index(:graph_artifacts, [:run_id])
  end
end
