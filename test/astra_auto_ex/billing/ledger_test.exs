defmodule AstraAutoEx.Billing.LedgerTest do
  @moduledoc """
  Unit tests for the Billing.Ledger freeze / claim / release / topup lifecycle.

  Coverage goals (per CLAUDE.md TDD rules):
    - happy paths: freeze → claim, freeze → release, topup
    - edge cases: zero amounts, decimal rounding, already-settled freezes
    - error cases: insufficient balance, unknown task, double settle
    - concurrency: two simultaneous freezes cannot overdraw balance
  """

  use AstraAutoEx.DataCase, async: false

  alias AstraAutoEx.Accounts.UserBalance
  alias AstraAutoEx.Billing.{BalanceFreeze, BalanceTransaction, Ledger}
  alias AstraAutoEx.Repo

  # ── Fixtures ───────────────────────────────────────────────────────────────

  defp user_fixture(_attrs \\ %{}) do
    uniq = System.unique_integer([:positive])

    {:ok, user} =
      AstraAutoEx.Accounts.register_user(%{
        email: "billing_#{uniq}@example.com",
        username: "billuser#{uniq}",
        password: "password123456"
      })

    user
  end

  defp seed_balance(user, amount) do
    {:ok, _new} = Ledger.topup(user.id, amount, %{reason: "test_seed"})
    Repo.get_by!(UserBalance, user_id: user.id)
  end

  defp task_id, do: Ecto.UUID.generate()

  defp dec(n), do: Decimal.new("#{n}")

  # ── get_balance / check_balance (existing) ─────────────────────────────────

  describe "get_balance/1" do
    test "creates a zero balance on first call" do
      user = user_fixture()
      assert {:ok, %UserBalance{} = balance} = Ledger.get_balance(user.id)
      assert Decimal.equal?(balance.balance, dec(0))
      assert Decimal.equal?(balance.frozen_amount, dec(0))
      assert Decimal.equal?(balance.total_spent, dec(0))
    end

    test "returns the existing balance on subsequent calls" do
      user = user_fixture()
      {:ok, first} = Ledger.get_balance(user.id)
      {:ok, second} = Ledger.get_balance(user.id)
      assert first.id == second.id
    end
  end

  describe "check_balance/2" do
    test "true when available covers the amount" do
      user = user_fixture()
      seed_balance(user, 10)
      assert Ledger.check_balance(user.id, 5)
      assert Ledger.check_balance(user.id, 10)
    end

    test "false when available is insufficient" do
      user = user_fixture()
      seed_balance(user, 2)
      refute Ledger.check_balance(user.id, 5)
    end

    test "counts frozen amount as unavailable" do
      user = user_fixture()
      seed_balance(user, 10)
      {:ok, _freeze} = Ledger.freeze(user.id, task_id(), dec(7))
      assert Ledger.check_balance(user.id, 3)
      refute Ledger.check_balance(user.id, 4)
    end
  end

  # ── topup/3 ─────────────────────────────────────────────────────────────────

  describe "topup/3" do
    test "adds to balance and returns the new balance" do
      user = user_fixture()
      assert {:ok, %UserBalance{} = bal} = Ledger.topup(user.id, dec(15), %{source: "stripe"})
      assert Decimal.equal?(bal.balance, dec(15))
    end

    test "writes a balance_transaction of type topup" do
      user = user_fixture()
      {:ok, _} = Ledger.topup(user.id, dec(20), %{order_id: "ord_42"})

      assert [tx] = Repo.all(BalanceTransaction)
      assert tx.user_id == user.id
      assert tx.type == "topup"
      assert Decimal.equal?(tx.amount, dec(20))
      assert Decimal.equal?(tx.balance_after, dec(20))
      assert tx.metadata["order_id"] == "ord_42"
    end

    test "accumulates across multiple top-ups" do
      user = user_fixture()
      {:ok, _} = Ledger.topup(user.id, dec(10), %{})
      {:ok, %UserBalance{balance: b}} = Ledger.topup(user.id, dec(5), %{})
      assert Decimal.equal?(b, dec(15))
    end

    test "rejects non-positive amount" do
      user = user_fixture()
      assert {:error, :invalid_amount} = Ledger.topup(user.id, dec(0), %{})
      assert {:error, :invalid_amount} = Ledger.topup(user.id, dec(-1), %{})
    end

    test "accepts float and integer input" do
      user = user_fixture()
      {:ok, b1} = Ledger.topup(user.id, 5, %{})
      {:ok, b2} = Ledger.topup(user.id, 2.5, %{})
      assert Decimal.equal?(b1.balance, dec(5))
      assert Decimal.equal?(b2.balance, Decimal.new("7.5"))
    end
  end

  # ── freeze/3 ────────────────────────────────────────────────────────────────

  describe "freeze/3" do
    test "deducts from balance and increments frozen on success" do
      user = user_fixture()
      seed_balance(user, 10)
      tid = task_id()

      assert {:ok, %BalanceFreeze{} = f} = Ledger.freeze(user.id, tid, dec(3))
      assert f.user_id == user.id
      assert f.task_id == tid
      assert Decimal.equal?(f.amount, dec(3))
      assert f.status in ["active", "pending"]

      bal = Repo.get_by!(UserBalance, user_id: user.id)
      assert Decimal.equal?(bal.balance, dec(7))
      assert Decimal.equal?(bal.frozen_amount, dec(3))
    end

    test "records a balance_transaction of type freeze" do
      user = user_fixture()
      seed_balance(user, 10)
      {:ok, _f} = Ledger.freeze(user.id, task_id(), dec(4))

      [_topup_tx, freeze_tx] = Repo.all(BalanceTransaction) |> Enum.sort_by(& &1.inserted_at)
      assert freeze_tx.type == "freeze"
      assert Decimal.equal?(freeze_tx.amount, Decimal.new("-4"))
      assert Decimal.equal?(freeze_tx.balance_after, dec(6))
    end

    test "returns :insufficient_balance when not enough funds" do
      user = user_fixture()
      seed_balance(user, 2)

      assert {:error, :insufficient_balance} =
               Ledger.freeze(user.id, task_id(), dec(5))

      # Nothing written
      assert [] = Repo.all(BalanceFreeze)
      bal = Repo.get_by!(UserBalance, user_id: user.id)
      assert Decimal.equal?(bal.balance, dec(2))
      assert Decimal.equal?(bal.frozen_amount, dec(0))
    end

    test "rejects zero or negative amount" do
      user = user_fixture()
      seed_balance(user, 5)

      assert {:error, :invalid_amount} = Ledger.freeze(user.id, task_id(), 0)
      assert {:error, :invalid_amount} = Ledger.freeze(user.id, task_id(), -3)
    end

    test "two sequential freezes can both succeed when total fits" do
      user = user_fixture()
      seed_balance(user, 10)

      {:ok, _} = Ledger.freeze(user.id, task_id(), dec(4))
      {:ok, _} = Ledger.freeze(user.id, task_id(), dec(4))

      bal = Repo.get_by!(UserBalance, user_id: user.id)
      assert Decimal.equal?(bal.balance, dec(2))
      assert Decimal.equal?(bal.frozen_amount, dec(8))
    end

    test "two sequential freezes fail the second one when total exceeds" do
      user = user_fixture()
      seed_balance(user, 10)

      {:ok, _} = Ledger.freeze(user.id, task_id(), dec(7))

      assert {:error, :insufficient_balance} =
               Ledger.freeze(user.id, task_id(), dec(5))
    end
  end

  # ── claim/2 (task succeeded — consume the frozen funds) ─────────────────────

  describe "claim/2" do
    test "marks the freeze as claimed and reduces frozen_amount" do
      user = user_fixture()
      seed_balance(user, 10)
      tid = task_id()
      {:ok, _f} = Ledger.freeze(user.id, tid, dec(4))

      assert {:ok, %BalanceFreeze{status: status}} = Ledger.claim(tid, dec(4))
      assert status in ["claimed", "confirmed"]

      bal = Repo.get_by!(UserBalance, user_id: user.id)
      assert Decimal.equal?(bal.balance, dec(6))
      assert Decimal.equal?(bal.frozen_amount, dec(0))
      assert Decimal.equal?(bal.total_spent, dec(4))
    end

    test "refunds the difference when actual cost is lower than frozen" do
      user = user_fixture()
      seed_balance(user, 10)
      tid = task_id()
      {:ok, _f} = Ledger.freeze(user.id, tid, dec(5))

      assert {:ok, _} = Ledger.claim(tid, dec(3))

      bal = Repo.get_by!(UserBalance, user_id: user.id)
      # frozen 5, spent 3, refund 2, balance: 10-5+2 = 7
      assert Decimal.equal?(bal.balance, dec(7))
      assert Decimal.equal?(bal.frozen_amount, dec(0))
      assert Decimal.equal?(bal.total_spent, dec(3))
    end

    test "caps actual cost at the frozen amount (never overcharges)" do
      user = user_fixture()
      seed_balance(user, 10)
      tid = task_id()
      {:ok, _f} = Ledger.freeze(user.id, tid, dec(3))

      # Ask to charge more than frozen — should cap at frozen amount.
      assert {:ok, _} = Ledger.claim(tid, dec(10))

      bal = Repo.get_by!(UserBalance, user_id: user.id)
      # balance: 10-3 = 7 (frozen consumed entirely, no over-charge)
      assert Decimal.equal?(bal.balance, dec(7))
      assert Decimal.equal?(bal.total_spent, dec(3))
    end

    test "records a balance_transaction of type charge" do
      user = user_fixture()
      seed_balance(user, 10)
      tid = task_id()
      {:ok, _f} = Ledger.freeze(user.id, tid, dec(4))
      {:ok, _} = Ledger.claim(tid, dec(4))

      charge_tx =
        BalanceTransaction
        |> Repo.all()
        |> Enum.find(&(&1.type == "charge"))

      assert charge_tx
      assert Decimal.equal?(charge_tx.amount, Decimal.new("-4"))
      assert Decimal.equal?(charge_tx.balance_after, dec(6))
    end

    test "returns :not_found for unknown task" do
      assert {:error, :not_found} = Ledger.claim(task_id(), dec(1))
    end

    test "cannot claim twice" do
      user = user_fixture()
      seed_balance(user, 10)
      tid = task_id()
      {:ok, _} = Ledger.freeze(user.id, tid, dec(2))
      {:ok, _} = Ledger.claim(tid, dec(2))

      assert {:error, :not_active} = Ledger.claim(tid, dec(2))
    end

    test "cannot claim a released freeze" do
      user = user_fixture()
      seed_balance(user, 10)
      tid = task_id()
      {:ok, _} = Ledger.freeze(user.id, tid, dec(2))
      {:ok, _} = Ledger.release(tid)

      assert {:error, :not_active} = Ledger.claim(tid, dec(2))
    end
  end

  # ── release/1 (task failed — refund entire freeze) ──────────────────────────

  describe "release/1" do
    test "marks the freeze as released and refunds balance in full" do
      user = user_fixture()
      seed_balance(user, 10)
      tid = task_id()
      {:ok, _f} = Ledger.freeze(user.id, tid, dec(4))

      assert {:ok, %BalanceFreeze{status: status}} = Ledger.release(tid)
      assert status in ["released", "rolled_back"]

      bal = Repo.get_by!(UserBalance, user_id: user.id)
      assert Decimal.equal?(bal.balance, dec(10))
      assert Decimal.equal?(bal.frozen_amount, dec(0))
      assert Decimal.equal?(bal.total_spent, dec(0))
    end

    test "records a balance_transaction of type release" do
      user = user_fixture()
      seed_balance(user, 10)
      tid = task_id()
      {:ok, _f} = Ledger.freeze(user.id, tid, dec(6))
      {:ok, _} = Ledger.release(tid)

      release_tx =
        BalanceTransaction
        |> Repo.all()
        |> Enum.find(&(&1.type == "release"))

      assert release_tx
      assert Decimal.equal?(release_tx.amount, dec(6))
      assert Decimal.equal?(release_tx.balance_after, dec(10))
    end

    test "returns :not_found for unknown task" do
      assert {:error, :not_found} = Ledger.release(task_id())
    end

    test "cannot release twice" do
      user = user_fixture()
      seed_balance(user, 10)
      tid = task_id()
      {:ok, _} = Ledger.freeze(user.id, tid, dec(2))
      {:ok, _} = Ledger.release(tid)

      assert {:error, :not_active} = Ledger.release(tid)
    end

    test "cannot release a claimed freeze" do
      user = user_fixture()
      seed_balance(user, 10)
      tid = task_id()
      {:ok, _} = Ledger.freeze(user.id, tid, dec(2))
      {:ok, _} = Ledger.claim(tid, dec(2))

      assert {:error, :not_active} = Ledger.release(tid)
    end
  end

  # ── Integration: freeze → claim / freeze → release lifecycle ────────────────

  describe "lifecycle" do
    test "freeze → claim → balance reflects actual consumption" do
      user = user_fixture()
      seed_balance(user, 100)

      tid = task_id()
      {:ok, _f} = Ledger.freeze(user.id, tid, dec(30))
      {:ok, _} = Ledger.claim(tid, Decimal.new("22.5"))

      bal = Repo.get_by!(UserBalance, user_id: user.id)
      assert Decimal.equal?(bal.balance, Decimal.new("77.5"))
      assert Decimal.equal?(bal.total_spent, Decimal.new("22.5"))
      assert Decimal.equal?(bal.frozen_amount, dec(0))
    end

    test "freeze → release → balance restored exactly" do
      user = user_fixture()
      seed_balance(user, 50)

      tid = task_id()
      {:ok, _} = Ledger.freeze(user.id, tid, dec(25))
      {:ok, _} = Ledger.release(tid)

      bal = Repo.get_by!(UserBalance, user_id: user.id)
      assert Decimal.equal?(bal.balance, dec(50))
      assert Decimal.equal?(bal.frozen_amount, dec(0))
    end

    test "mixed lifecycle: two freezes, one claimed, one released" do
      user = user_fixture()
      seed_balance(user, 100)

      tid_a = task_id()
      tid_b = task_id()
      {:ok, _} = Ledger.freeze(user.id, tid_a, dec(20))
      {:ok, _} = Ledger.freeze(user.id, tid_b, dec(30))
      # balance 50, frozen 50

      {:ok, _} = Ledger.claim(tid_a, dec(15))
      # a claimed: spent 15, refund 5 → balance 55, frozen 30
      {:ok, _} = Ledger.release(tid_b)
      # b released → balance 85, frozen 0

      bal = Repo.get_by!(UserBalance, user_id: user.id)
      assert Decimal.equal?(bal.balance, dec(85))
      assert Decimal.equal?(bal.total_spent, dec(15))
      assert Decimal.equal?(bal.frozen_amount, dec(0))
    end
  end

  # ── Concurrency: two simultaneous freezes cannot overdraw ───────────────────

  describe "concurrent freezes" do
    test "two concurrent freezes totalling more than balance — exactly one fails" do
      user = user_fixture()
      seed_balance(user, 10)

      # Both tasks try to freeze 7 each. Only one can succeed.
      parent = self()

      spawn_freezer = fn amount ->
        spawn_link(fn ->
          Ecto.Adapters.SQL.Sandbox.allow(Repo, parent, self())
          result = Ledger.freeze(user.id, task_id(), dec(amount))
          send(parent, {:result, self(), result})
        end)
      end

      p1 = spawn_freezer.(7)
      p2 = spawn_freezer.(7)

      results =
        for pid <- [p1, p2] do
          receive do
            {:result, ^pid, r} -> r
          after
            5_000 -> flunk("freeze worker timed out")
          end
        end

      ok_count = Enum.count(results, &match?({:ok, _}, &1))
      err_count = Enum.count(results, &match?({:error, :insufficient_balance}, &1))

      assert ok_count == 1
      assert err_count == 1

      bal = Repo.get_by!(UserBalance, user_id: user.id)
      # Only one freeze of 7 went through
      assert Decimal.equal?(bal.balance, dec(3))
      assert Decimal.equal?(bal.frozen_amount, dec(7))
    end
  end
end
