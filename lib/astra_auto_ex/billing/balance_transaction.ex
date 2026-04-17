defmodule AstraAutoEx.Billing.BalanceTransaction do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "balance_transactions" do
    belongs_to :user, AstraAutoEx.Accounts.User, type: :id
    field :type, :string
    field :amount, :decimal
    field :balance_after, :decimal
    field :freeze_id, :binary_id
    field :description, :string
    field :metadata, :map
    timestamps(updated_at: false)
  end

  @valid_types ~w(freeze release charge topup recharge consume adjust shadow_consume)

  def changeset(tx, attrs) do
    tx
    |> cast(attrs, [:user_id, :type, :amount, :balance_after, :freeze_id, :description, :metadata])
    |> validate_required([:user_id, :type, :amount])
    |> validate_inclusion(:type, @valid_types)
  end
end
