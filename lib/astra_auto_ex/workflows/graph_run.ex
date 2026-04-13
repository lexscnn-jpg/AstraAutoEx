defmodule AstraAutoEx.Workflows.GraphRun do
  use Ecto.Schema
  import Ecto.Changeset
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "graph_runs" do
    field :project_id, :integer
    belongs_to :user, AstraAutoEx.Accounts.User, type: :id
    field :workflow_type, :string
    field :task_type, :string
    field :target_type, :string
    field :target_id, :string
    field :status, :string, default: "queued"
    field :input, :map
    field :output, :map
    field :error_message, :string
    field :started_at, :utc_datetime
    field :finished_at, :utc_datetime
    field :lease_owner, :string
    field :lease_expires_at, :utc_datetime
    has_many :steps, AstraAutoEx.Workflows.GraphStep, foreign_key: :run_id
    has_many :events, AstraAutoEx.Workflows.GraphEvent, foreign_key: :run_id
    timestamps()
  end

  def changeset(run, attrs) do
    run
    |> cast(attrs, [
      :project_id,
      :user_id,
      :workflow_type,
      :task_type,
      :target_type,
      :target_id,
      :status,
      :input,
      :output,
      :error_message,
      :started_at,
      :finished_at,
      :lease_owner,
      :lease_expires_at
    ])
    |> validate_required([:project_id, :user_id, :workflow_type])
    |> validate_inclusion(:status, ~w(queued processing completed failed canceled))
  end
end
