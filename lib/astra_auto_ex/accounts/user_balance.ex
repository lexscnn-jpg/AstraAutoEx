defmodule AstraAutoEx.Accounts.UserBalance do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_balances" do
    field :balance, :decimal, default: Decimal.new(0)
    field :frozen_amount, :decimal, default: Decimal.new(0)
    field :total_spent, :decimal, default: Decimal.new(0)

    belongs_to :user, AstraAutoEx.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(user_balance, attrs) do
    user_balance
    |> cast(attrs, [:user_id, :balance, :frozen_amount, :total_spent])
    |> validate_required([:user_id])
    |> validate_number(:balance, greater_than_or_equal_to: 0)
    |> validate_number(:frozen_amount, greater_than_or_equal_to: 0)
    |> validate_number(:total_spent, greater_than_or_equal_to: 0)
    |> unique_constraint(:user_id)
  end
end
