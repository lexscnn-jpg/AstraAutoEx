defmodule AstraAutoEx.Billing.ApiCallLog do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "api_call_logs" do
    field :user_id, :integer
    field :project_id, :integer
    field :project_name, :string
    field :model_key, :string
    field :model_type, :string
    field :pipeline_step, :string
    field :input_tokens, :integer, default: 0
    field :output_tokens, :integer, default: 0
    field :status, :string, default: "success"
    field :cost_estimate, :decimal
    field :duration_ms, :integer, default: 0
    field :metadata, :map, default: %{}

    timestamps()
  end

  @required_fields [:user_id, :model_key, :model_type, :pipeline_step, :status]
  @optional_fields [:project_id, :project_name, :input_tokens, :output_tokens,
                    :cost_estimate, :duration_ms, :metadata]

  def changeset(log, attrs) do
    log
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:model_type, ~w(text image video voice music))
    |> validate_inclusion(:status, ~w(success failed timeout))
  end
end
