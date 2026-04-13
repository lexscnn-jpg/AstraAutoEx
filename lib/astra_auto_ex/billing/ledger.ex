defmodule AstraAutoEx.Billing.Ledger do
  @moduledoc """
  Three-phase commit billing: freeze → confirm → rollback.
  All operations use Ecto.Multi for ACID guarantees.
  """
  import Ecto.Query
  alias AstraAutoEx.Repo
  alias AstraAutoEx.Accounts.UserBalance
  alias AstraAutoEx.Billing.{BalanceFreeze, BalanceTransaction, UsageCost}

  @money_scale 6

  def get_balance(user_id) do
    case Repo.get_by(UserBalance, user_id: user_id) do
      nil ->
        %UserBalance{}
        |> UserBalance.changeset(%{
          user_id: user_id,
          balance: Decimal.new(0),
          frozen_amount: Decimal.new(0),
          total_spent: Decimal.new(0)
        })
        |> Repo.insert()

      balance ->
        {:ok, balance}
    end
  end

  def check_balance(user_id, required_amount) do
    {:ok, balance} = get_balance(user_id)
    available = Decimal.sub(balance.balance, balance.frozen_amount)
    Decimal.compare(available, Decimal.new("#{required_amount}")) != :lt
  end

  def freeze_balance(user_id, amount, opts \\ []) do
    idempotency_key = Keyword.get(opts, :idempotency_key)
    task_id = Keyword.get(opts, :task_id)
    metadata = Keyword.get(opts, :metadata)
    dec_amount = normalize(amount)

    Ecto.Multi.new()
    |> Ecto.Multi.run(:balance, fn _repo, _ -> get_balance(user_id) end)
    |> Ecto.Multi.run(:check, fn _repo, %{balance: balance} ->
      available = Decimal.sub(balance.balance, balance.frozen_amount)

      if Decimal.compare(available, dec_amount) != :lt,
        do: {:ok, :sufficient},
        else: {:error, :insufficient_balance}
    end)
    |> Ecto.Multi.run(:freeze, fn _repo, _ ->
      %BalanceFreeze{}
      |> BalanceFreeze.changeset(%{
        user_id: user_id,
        amount: dec_amount,
        task_id: task_id,
        idempotency_key: idempotency_key,
        metadata: metadata
      })
      |> Repo.insert()
    end)
    |> Ecto.Multi.run(:update_balance, fn _repo, %{balance: balance} ->
      from(ub in UserBalance, where: ub.id == ^balance.id)
      |> Repo.update_all(inc: [frozen_amount: dec_amount])

      {:ok, :updated}
    end)
    |> Repo.transaction(timeout: 10_000)
    |> case do
      {:ok, %{freeze: freeze}} -> {:ok, freeze}
      {:error, _step, reason, _} -> {:error, reason}
    end
  end

  def confirm_charge(freeze_id, charged_amount) do
    dec_charged = normalize(charged_amount)

    Ecto.Multi.new()
    |> Ecto.Multi.run(:freeze, fn _repo, _ ->
      case Repo.get(BalanceFreeze, freeze_id) do
        %BalanceFreeze{status: "pending"} = f -> {:ok, f}
        _ -> {:error, :freeze_not_pending}
      end
    end)
    |> Ecto.Multi.run(:update_freeze, fn _repo, %{freeze: freeze} ->
      freeze |> BalanceFreeze.changeset(%{status: "confirmed"}) |> Repo.update()
    end)
    |> Ecto.Multi.run(:settle_balance, fn _repo, %{freeze: freeze} ->
      refund = Decimal.sub(freeze.amount, dec_charged)

      from(ub in UserBalance, where: ub.user_id == ^freeze.user_id)
      |> Repo.update_all(
        inc: [
          frozen_amount: Decimal.negate(freeze.amount),
          balance: refund,
          total_spent: dec_charged
        ]
      )

      {:ok, :settled}
    end)
    |> Ecto.Multi.run(:transaction, fn _repo, %{freeze: freeze} ->
      {:ok, balance} = get_balance(freeze.user_id)

      %BalanceTransaction{}
      |> BalanceTransaction.changeset(%{
        user_id: freeze.user_id,
        type: "consume",
        amount: Decimal.negate(dec_charged),
        balance_after: balance.balance,
        freeze_id: freeze_id
      })
      |> Repo.insert()
    end)
    |> Repo.transaction(timeout: 10_000)
  end

  def rollback_freeze(freeze_id) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:freeze, fn _repo, _ ->
      case Repo.get(BalanceFreeze, freeze_id) do
        %BalanceFreeze{status: "pending"} = f -> {:ok, f}
        _ -> {:error, :freeze_not_pending}
      end
    end)
    |> Ecto.Multi.run(:update_freeze, fn _repo, %{freeze: freeze} ->
      freeze |> BalanceFreeze.changeset(%{status: "rolled_back"}) |> Repo.update()
    end)
    |> Ecto.Multi.run(:refund, fn _repo, %{freeze: freeze} ->
      from(ub in UserBalance, where: ub.user_id == ^freeze.user_id)
      |> Repo.update_all(inc: [frozen_amount: Decimal.negate(freeze.amount)])

      {:ok, :refunded}
    end)
    |> Repo.transaction(timeout: 10_000)
  end

  def record_usage(attrs) do
    %UsageCost{} |> UsageCost.changeset(attrs) |> Repo.insert()
  end

  defp normalize(amount) when is_float(amount),
    do: Decimal.from_float(amount) |> Decimal.round(@money_scale)

  defp normalize(amount) when is_integer(amount), do: Decimal.new(amount)
  defp normalize(%Decimal{} = amount), do: amount
  defp normalize(amount) when is_binary(amount), do: Decimal.new(amount)
end
