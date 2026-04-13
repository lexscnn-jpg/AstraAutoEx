defmodule AstraAutoEx.Workflows.GraphStep do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "graph_steps" do
    belongs_to :run, AstraAutoEx.Workflows.GraphRun
    field :step_key, :string
    field :step_index, :integer
    field :step_total, :integer
    field :status, :string, default: "pending"
    field :current_attempt, :integer, default: 0
    field :error_code, :string
    field :error_message, :string
    field :started_at, :utc_datetime
    field :finished_at, :utc_datetime
    timestamps()
  end

  def changeset(step, attrs) do
    step
    |> cast(attrs, [
      :run_id,
      :step_key,
      :step_index,
      :step_total,
      :status,
      :current_attempt,
      :error_code,
      :error_message,
      :started_at,
      :finished_at
    ])
    |> validate_required([:run_id, :step_key])
    |> unique_constraint([:run_id, :step_key])
  end
end
