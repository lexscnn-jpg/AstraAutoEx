defmodule AstraAutoEx.Repo.Migrations.AddPerformanceIndexes do
  use Ecto.Migration

  def change do
    # Task scheduler hot query: queued tasks ordered by priority
    create_if_not_exists index(:tasks, [:status, :priority, :queued_at])

    # Stale task watchdog query
    create_if_not_exists index(:tasks, [:status, :heartbeat_at],
                           where: "status = 'processing'",
                           name: :tasks_stale_processing_idx
                         )

    # Task polling by external_id
    create_if_not_exists index(:tasks, [:external_id],
                           where: "external_id IS NOT NULL",
                           name: :tasks_external_id_idx
                         )

    # Panels by storyboard (N+1 prevention)
    create_if_not_exists index(:panels, [:storyboard_id, :panel_index])

    # Voice lines by episode
    create_if_not_exists index(:voice_lines, [:episode_id, :line_index])

    # Storyboards by clip (used in script→storyboard flow)
    create_if_not_exists index(:storyboards, [:clip_id])

    # Balance freeze lookup
    create_if_not_exists index(:balance_freezes, [:user_id, :status])

    # Usage cost aggregation
    create_if_not_exists index(:usage_costs, [:user_id, :inserted_at])

    # Global assets by user
    create_if_not_exists index(:global_characters, [:user_id])
    create_if_not_exists index(:global_locations, [:user_id])
    create_if_not_exists index(:global_voices, [:user_id])

    # Graph runs by project + status
    create_if_not_exists index(:graph_runs, [:project_id, :status])

    # Graph steps by run
    create_if_not_exists index(:graph_steps, [:run_id])
  end
end
