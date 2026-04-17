defmodule AstraAutoEx.Billing.Ledger do
  @moduledoc """
  Credit/balance ledger with freeze → claim/release lifecycle.

  Provides the four canonical operations used by the task pipeline to
  reserve, settle, and refund user credits:

    * `topup/3`     — user recharges their balance.
    * `freeze/3`    — reserve credits for a task before calling a paid API.
    * `claim/2`     — task succeeded; consume the reserved credits (with
                      refund of unused portion if actual cost < frozen).
    * `release/1`   — task failed; return the full reserved amount to
                      available balance.

  All operations are executed inside `Ecto.Multi` transactions so the
  balance table (`user_balances`), freeze records (`balance_freezes`) and
  audit trail (`balance_transactions`) stay consistent. Row-level locking
  (`FOR UPDATE`) on the balance row prevents concurrent freezes from
  overdrawing.

  Backwards-compat aliases are kept for the older verb set:

    * `freeze_balance/3` → `freeze/3`
    * `confirm_charge/2` → `claim_by_freeze/2`
    * `rollback_freeze/1` → `release_by_freeze/1`
  """

  import Ecto.Query

  alias AstraAutoEx.Accounts.UserBalance
  alias AstraAutoEx.Billing.{BalanceFreeze, BalanceTransaction, UsageCost}
  alias AstraAutoEx.Repo
  alias Ecto.Multi

  @money_scale 6
  @status_active "active"
  @status_claimed "claimed"
  @status_released "released"

  @type user_id :: integer()
  @type task_id :: Ecto.UUID.t()
  @type amount :: Decimal.t() | number() | String.t()
  @type money :: Decimal.t()

  # ────────────────────────────────────────────────────────────────────────────
  # Read helpers
  # ────────────────────────────────────────────────────────────────────────────

  @doc """
  Returns the user's balance row, creating a zero row on first access.
  """
  @spec get_balance(user_id()) :: {:ok, UserBalance.t()} | {:error, term()}
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
        |> case do
          {:ok, row} -> {:ok, row}
          # Race: another connection just created the row — re-read.
          {:error, _} -> {:ok, Repo.get_by!(UserBalance, user_id: user_id)}
        end

      %UserBalance{} = balance ->
        {:ok, balance}
    end
  end

  @doc """
  True when the user's available balance covers `amount`.

  Because freezes already debit the balance column (and credit
  `frozen_amount`), "available" is simply the `balance` column.
  """
  @spec check_balance(user_id(), amount()) :: boolean()
  def check_balance(user_id, amount) do
    {:ok, bal} = get_balance(user_id)
    Decimal.compare(bal.balance, normalize(amount)) != :lt
  end

  # ────────────────────────────────────────────────────────────────────────────
  # topup/3 — user recharges their balance
  # ────────────────────────────────────────────────────────────────────────────

  @doc """
  Add `amount` to the user's balance and write a `topup` transaction.

  `meta` is an optional map (e.g. `%{source: "stripe", order_id: "..."}`).
  """
  @spec topup(user_id(), amount(), map()) ::
          {:ok, UserBalance.t()} | {:error, atom() | Ecto.Changeset.t()}
  def topup(user_id, amount, meta \\ %{}) do
    dec_amount = normalize(amount)

    if not positive?(dec_amount) do
      {:error, :invalid_amount}
    else
      Multi.new()
      |> Multi.run(:balance, fn _repo, _ -> get_balance(user_id) end)
      |> Multi.run(:locked, fn _repo, %{balance: b} -> lock_balance(b.id) end)
      |> Multi.run(:update, fn _repo, %{locked: locked} ->
        new_balance = Decimal.add(locked.balance, dec_amount)

        {1, [updated]} =
          from(ub in UserBalance,
            where: ub.id == ^locked.id,
            select: ub
          )
          |> Repo.update_all(set: [balance: new_balance, updated_at: now()])

        {:ok, updated}
      end)
      |> Multi.run(:tx, fn _repo, %{update: updated} ->
        %BalanceTransaction{}
        |> BalanceTransaction.changeset(%{
          user_id: user_id,
          type: "topup",
          amount: dec_amount,
          balance_after: updated.balance,
          metadata: meta
        })
        |> Repo.insert()
      end)
      |> Repo.transaction(timeout: 10_000)
      |> case do
        {:ok, %{update: updated}} -> {:ok, updated}
        {:error, _step, reason, _} -> {:error, reason}
      end
    end
  end

  # ────────────────────────────────────────────────────────────────────────────
  # freeze/3 — reserve credits for a task
  # ────────────────────────────────────────────────────────────────────────────

  @doc """
  Reserve `amount` credits for `task_id`, moving them from `balance` to
  `frozen_amount`. Fails with `:insufficient_balance` if available
  balance can't cover the reservation.

  `opts` accepts `:idempotency_key` and `:metadata`.
  """
  @spec freeze(user_id(), task_id(), amount(), keyword()) ::
          {:ok, BalanceFreeze.t()}
          | {:error, :insufficient_balance | :invalid_amount | term()}
  def freeze(user_id, task_id, amount, opts \\ []) do
    dec_amount = normalize(amount)

    if not positive?(dec_amount) do
      {:error, :invalid_amount}
    else
      idempotency_key = Keyword.get(opts, :idempotency_key)
      metadata = Keyword.get(opts, :metadata, %{})

      Multi.new()
      |> Multi.run(:balance, fn _repo, _ -> get_balance(user_id) end)
      |> Multi.run(:locked, fn _repo, %{balance: b} -> lock_balance(b.id) end)
      |> Multi.run(:check, fn _repo, %{locked: locked} ->
        # `balance` is the available column (frozen is a separate bucket).
        if Decimal.compare(locked.balance, dec_amount) == :lt do
          {:error, :insufficient_balance}
        else
          {:ok, :sufficient}
        end
      end)
      |> Multi.run(:freeze, fn _repo, _ ->
        %BalanceFreeze{}
        |> BalanceFreeze.changeset(%{
          user_id: user_id,
          task_id: task_id,
          amount: dec_amount,
          status: @status_active,
          idempotency_key: idempotency_key,
          metadata: metadata
        })
        |> Repo.insert()
      end)
      |> Multi.run(:update, fn _repo, %{locked: locked} ->
        new_balance = Decimal.sub(locked.balance, dec_amount)
        new_frozen = Decimal.add(locked.frozen_amount, dec_amount)

        {1, [updated]} =
          from(ub in UserBalance,
            where: ub.id == ^locked.id,
            select: ub
          )
          |> Repo.update_all(
            set: [
              balance: new_balance,
              frozen_amount: new_frozen,
              updated_at: now()
            ]
          )

        {:ok, updated}
      end)
      |> Multi.run(:tx, fn _repo, %{update: updated, freeze: f} ->
        %BalanceTransaction{}
        |> BalanceTransaction.changeset(%{
          user_id: user_id,
          type: "freeze",
          amount: Decimal.negate(dec_amount),
          balance_after: updated.balance,
          freeze_id: f.id,
          description: "freeze for task #{task_id}",
          metadata: metadata
        })
        |> Repo.insert()
      end)
      |> Repo.transaction(timeout: 10_000)
      |> case do
        {:ok, %{freeze: freeze}} -> {:ok, freeze}
        {:error, _step, reason, _} -> {:error, reason}
      end
    end
  end

  @doc false
  # Backwards-compatible alias for the old verb set.
  @spec freeze_balance(user_id(), amount(), keyword()) ::
          {:ok, BalanceFreeze.t()} | {:error, term()}
  def freeze_balance(user_id, amount, opts \\ []) do
    task_id = Keyword.get(opts, :task_id)
    freeze(user_id, task_id, amount, opts)
  end

  # ────────────────────────────────────────────────────────────────────────────
  # claim/2 — task succeeded, consume frozen funds
  # ────────────────────────────────────────────────────────────────────────────

  @doc """
  Consume the active freeze for `task_id`. `actual_amount` is the real
  cost charged by the provider; any unused portion of the freeze is
  refunded to available balance.

    * If `actual_amount ≥ frozen` the entire frozen amount is charged
      (no over-charge beyond the reservation).
    * If `actual_amount < frozen` the difference is refunded.
  """
  @spec claim(task_id(), amount()) ::
          {:ok, BalanceFreeze.t()}
          | {:error, :not_found | :not_active | term()}
  def claim(task_id, actual_amount) do
    dec_actual = normalize(actual_amount)

    Multi.new()
    |> Multi.run(:freeze, fn _repo, _ -> fetch_active_freeze(task_id) end)
    |> Multi.run(:locked, fn _repo, %{freeze: f} ->
      with {:ok, bal} <- get_balance(f.user_id),
           {:ok, locked} <- lock_balance(bal.id) do
        {:ok, locked}
      end
    end)
    |> Multi.run(:settle, fn _repo, %{freeze: f, locked: locked} ->
      charge = min_dec(dec_actual, f.amount)
      refund = Decimal.sub(f.amount, charge)

      new_balance = Decimal.add(locked.balance, refund)
      new_frozen = Decimal.sub(locked.frozen_amount, f.amount)
      new_spent = Decimal.add(locked.total_spent, charge)

      {1, [updated]} =
        from(ub in UserBalance,
          where: ub.id == ^locked.id,
          select: ub
        )
        |> Repo.update_all(
          set: [
            balance: new_balance,
            frozen_amount: new_frozen,
            total_spent: new_spent,
            updated_at: now()
          ]
        )

      {:ok, %{updated: updated, charge: charge, refund: refund}}
    end)
    |> Multi.run(:update_freeze, fn _repo, %{freeze: f} ->
      f
      |> BalanceFreeze.changeset(%{status: @status_claimed})
      |> Repo.update()
    end)
    |> Multi.run(:tx, fn _repo, %{freeze: f, settle: s, update_freeze: uf} ->
      %BalanceTransaction{}
      |> BalanceTransaction.changeset(%{
        user_id: f.user_id,
        type: "charge",
        amount: Decimal.negate(s.charge),
        balance_after: s.updated.balance,
        freeze_id: uf.id,
        description: "claim task #{f.task_id}",
        metadata: %{refund: Decimal.to_string(s.refund)}
      })
      |> Repo.insert()
    end)
    |> Repo.transaction(timeout: 10_000)
    |> case do
      {:ok, %{update_freeze: freeze}} -> {:ok, freeze}
      {:error, _step, reason, _} -> {:error, reason}
    end
  end

  @doc false
  @spec confirm_charge(Ecto.UUID.t(), amount()) :: {:ok, map()} | {:error, term()}
  def confirm_charge(freeze_id, charged_amount) do
    case Repo.get(BalanceFreeze, freeze_id) do
      %BalanceFreeze{task_id: tid} when not is_nil(tid) ->
        with {:ok, freeze} <- claim(tid, charged_amount) do
          {:ok, %{freeze: freeze}}
        end

      _ ->
        {:error, :not_found}
    end
  end

  # ────────────────────────────────────────────────────────────────────────────
  # release/1 — task failed, refund the entire freeze
  # ────────────────────────────────────────────────────────────────────────────

  @doc """
  Mark the active freeze for `task_id` as released and return the full
  frozen amount to available balance.
  """
  @spec release(task_id()) ::
          {:ok, BalanceFreeze.t()}
          | {:error, :not_found | :not_active | term()}
  def release(task_id) do
    Multi.new()
    |> Multi.run(:freeze, fn _repo, _ -> fetch_active_freeze(task_id) end)
    |> Multi.run(:locked, fn _repo, %{freeze: f} ->
      with {:ok, bal} <- get_balance(f.user_id),
           {:ok, locked} <- lock_balance(bal.id) do
        {:ok, locked}
      end
    end)
    |> Multi.run(:refund, fn _repo, %{freeze: f, locked: locked} ->
      new_balance = Decimal.add(locked.balance, f.amount)
      new_frozen = Decimal.sub(locked.frozen_amount, f.amount)

      {1, [updated]} =
        from(ub in UserBalance,
          where: ub.id == ^locked.id,
          select: ub
        )
        |> Repo.update_all(
          set: [
            balance: new_balance,
            frozen_amount: new_frozen,
            updated_at: now()
          ]
        )

      {:ok, updated}
    end)
    |> Multi.run(:update_freeze, fn _repo, %{freeze: f} ->
      f
      |> BalanceFreeze.changeset(%{status: @status_released})
      |> Repo.update()
    end)
    |> Multi.run(:tx, fn _repo, %{freeze: f, refund: updated, update_freeze: uf} ->
      %BalanceTransaction{}
      |> BalanceTransaction.changeset(%{
        user_id: f.user_id,
        type: "release",
        amount: f.amount,
        balance_after: updated.balance,
        freeze_id: uf.id,
        description: "release task #{f.task_id}"
      })
      |> Repo.insert()
    end)
    |> Repo.transaction(timeout: 10_000)
    |> case do
      {:ok, %{update_freeze: freeze}} -> {:ok, freeze}
      {:error, _step, reason, _} -> {:error, reason}
    end
  end

  @doc false
  @spec rollback_freeze(Ecto.UUID.t()) :: {:ok, map()} | {:error, term()}
  def rollback_freeze(freeze_id) do
    case Repo.get(BalanceFreeze, freeze_id) do
      %BalanceFreeze{task_id: tid} when not is_nil(tid) ->
        with {:ok, freeze} <- release(tid) do
          {:ok, %{freeze: freeze}}
        end

      _ ->
        {:error, :not_found}
    end
  end

  # ────────────────────────────────────────────────────────────────────────────
  # Usage recording
  # ────────────────────────────────────────────────────────────────────────────

  @doc """
  Persist a usage-cost line for fine-grained per-call auditing.
  """
  @spec record_usage(map()) :: {:ok, UsageCost.t()} | {:error, Ecto.Changeset.t()}
  def record_usage(attrs) do
    %UsageCost{}
    |> UsageCost.changeset(attrs)
    |> Repo.insert()
  end

  # ────────────────────────────────────────────────────────────────────────────
  # Internal helpers
  # ────────────────────────────────────────────────────────────────────────────

  # Acquires a row-level lock on the balance row via SELECT ... FOR UPDATE so
  # concurrent freeze/claim/release/topup on the same user serialize.
  @spec lock_balance(integer()) :: {:ok, UserBalance.t()} | {:error, :balance_missing}
  defp lock_balance(balance_id) do
    row =
      from(ub in UserBalance,
        where: ub.id == ^balance_id,
        lock: "FOR UPDATE"
      )
      |> Repo.one()

    case row do
      %UserBalance{} = b -> {:ok, b}
      nil -> {:error, :balance_missing}
    end
  end

  @spec fetch_active_freeze(task_id()) ::
          {:ok, BalanceFreeze.t()} | {:error, :not_found | :not_active}
  defp fetch_active_freeze(task_id) when is_binary(task_id) do
    case Repo.get_by(BalanceFreeze, task_id: task_id) do
      nil ->
        {:error, :not_found}

      %BalanceFreeze{status: status} = f when status in [@status_active, "pending"] ->
        {:ok, f}

      %BalanceFreeze{} ->
        {:error, :not_active}
    end
  end

  defp fetch_active_freeze(_), do: {:error, :not_found}

  @spec normalize(amount()) :: money()
  defp normalize(%Decimal{} = amount), do: amount

  defp normalize(amount) when is_integer(amount), do: Decimal.new(amount)

  defp normalize(amount) when is_float(amount) do
    amount |> Decimal.from_float() |> Decimal.round(@money_scale)
  end

  defp normalize(amount) when is_binary(amount), do: Decimal.new(amount)

  @spec positive?(money()) :: boolean()
  defp positive?(%Decimal{} = d), do: Decimal.compare(d, Decimal.new(0)) == :gt

  @spec min_dec(money(), money()) :: money()
  defp min_dec(a, b), do: if(Decimal.compare(a, b) == :lt, do: a, else: b)

  @spec now() :: NaiveDateTime.t()
  defp now do
    NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
  end
end
