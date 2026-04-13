defmodule AstraAutoEx.Billing.UsageCost do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "usage_costs" do
    belongs_to :user, AstraAutoEx.Accounts.User, type: :id
    field :project_id, :integer
    field :task_id, :binary_id
    field :task_type, :string
    field :api_type, :string
    field :model, :string
    field :provider, :string
    field :quantity, :decimal
    field :unit, :string
    field :cost, :decimal
    field :action, :string
    field :metadata, :map
    timestamps(updated_at: false)
  end

  def changeset(uc, attrs) do
    uc
    |> cast(attrs, [
      :user_id,
      :project_id,
      :task_id,
      :task_type,
      :api_type,
      :model,
      :provider,
      :quantity,
      :unit,
      :cost,
      :action,
      :metadata
    ])
    |> validate_required([:user_id])
  end
end
