defmodule AstraAutoEx.Tasks.TaskEvent do
  use Ecto.Schema
  import Ecto.Changeset

  schema "task_events" do
    belongs_to :task, AstraAutoEx.Tasks.Task, type: :binary_id
    field :project_id, :integer
    field :user_id, :integer
    field :event_type, :string
    field :payload, :map

    timestamps(updated_at: false)
  end

  @event_types ~w(task.created task.processing task.progress task.completed task.failed task.paused)

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:task_id, :project_id, :user_id, :event_type, :payload])
    |> validate_required([:task_id, :project_id, :user_id, :event_type])
    |> validate_inclusion(:event_type, @event_types)
  end
end
