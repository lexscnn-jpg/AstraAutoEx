defmodule AstraAutoEx.Repo.Migrations.FixProjectIdColumnTypes do
  use Ecto.Migration

  @moduledoc """
  Fix project_id and user_id column types.
  These were created as uuid but reference tables with bigint PKs (users, projects).
  """

  def up do
    # Tables with project_id as uuid → bigint
    for table <-
          ~w(characters locations episodes novel_projects tasks task_events graph_runs usage_costs series_plans) do
      execute "ALTER TABLE #{table} ALTER COLUMN project_id TYPE bigint USING NULL"
    end

    # Tables with user_id as uuid → bigint (episodes, task_events)
    execute "ALTER TABLE episodes ALTER COLUMN user_id TYPE bigint USING NULL"
    execute "ALTER TABLE task_events ALTER COLUMN user_id TYPE bigint USING NULL"
  end

  def down do
    for table <-
          ~w(characters locations episodes novel_projects tasks task_events graph_runs usage_costs series_plans) do
      execute "ALTER TABLE #{table} ALTER COLUMN project_id TYPE uuid USING NULL"
    end

    execute "ALTER TABLE episodes ALTER COLUMN user_id TYPE uuid USING NULL"
    execute "ALTER TABLE task_events ALTER COLUMN user_id TYPE uuid USING NULL"
  end
end
