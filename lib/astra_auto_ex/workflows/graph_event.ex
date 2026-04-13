defmodule AstraAutoEx.Workflows.GraphEvent do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "graph_events" do
    belongs_to :run, AstraAutoEx.Workflows.GraphRun
    field :seq, :integer
    field :lane, :string
    field :step_key, :string
    field :attempt, :integer
    field :event_type, :string
    field :payload, :map
    timestamps(updated_at: false)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:run_id, :seq, :lane, :step_key, :attempt, :event_type, :payload])
    |> validate_required([:run_id, :seq, :event_type])
    |> unique_constraint([:run_id, :seq])
  end
end
