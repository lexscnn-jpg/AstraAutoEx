defmodule AstraAutoEx.Billing.BalanceFreeze do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "balance_freezes" do
    belongs_to :user, AstraAutoEx.Accounts.User, type: :id
    field :task_id, :binary_id
    field :amount, :decimal
    field :status, :string, default: "pending"
    field :idempotency_key, :string
    field :metadata, :map
    timestamps()
  end

  def changeset(freeze, attrs) do
    freeze
    |> cast(attrs, [:user_id, :task_id, :amount, :status, :idempotency_key, :metadata])
    |> validate_required([:user_id, :amount])
    |> validate_inclusion(:status, ~w(pending confirmed rolled_back))
    |> unique_constraint(:idempotency_key)
  end
end
