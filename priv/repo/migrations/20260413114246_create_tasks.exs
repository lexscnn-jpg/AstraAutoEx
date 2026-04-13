defmodule AstraAutoEx.Repo.Migrations.CreateTasks do
  use Ecto.Migration

  def change do
    create table(:tasks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :project_id, :binary_id, null: false
      add :episode_id, :binary_id
      add :type, :string, null: false
      add :target_type, :string, null: false
      add :target_id, :string, null: false
      add :status, :string, null: false, default: "queued"
      add :progress, :integer, default: 0
      add :attempt, :integer, default: 0
      add :max_attempts, :integer, default: 5
      add :priority, :integer, default: 0
      add :dedupe_key, :string
      add :external_id, :string
      add :payload, :map
      add :result, :map
      add :error_code, :string
      add :error_message, :text
      add :billing_info, :map
      add :billed_at, :utc_datetime
      add :queued_at, :utc_datetime
      add :started_at, :utc_datetime
      add :finished_at, :utc_datetime
      add :heartbeat_at, :utc_datetime

      timestamps()
    end

    create unique_index(:tasks, [:dedupe_key], where: "dedupe_key IS NOT NULL")
    create index(:tasks, [:status])
    create index(:tasks, [:type])
    create index(:tasks, [:target_type, :target_id])
    create index(:tasks, [:project_id])
    create index(:tasks, [:user_id])
    create index(:tasks, [:heartbeat_at])

    create table(:task_events) do
      add :task_id, references(:tasks, type: :binary_id, on_delete: :delete_all), null: false
      add :project_id, :binary_id, null: false
      add :user_id, :binary_id, null: false
      add :event_type, :string, null: false
      add :payload, :map

      timestamps(updated_at: false)
    end

    create index(:task_events, [:task_id])
    create index(:task_events, [:project_id, :id])
    create index(:task_events, [:user_id])
  end
end
