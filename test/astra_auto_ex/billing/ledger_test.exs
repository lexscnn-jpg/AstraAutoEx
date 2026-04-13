defmodule AstraAutoEx.Billing.LedgerTest do
  use AstraAutoEx.DataCase

  alias AstraAutoEx.Billing.Ledger

  describe "get_balance/1" do
    test "creates balance if none exists" do
      user = user_fixture()
      assert {:ok, balance} = Ledger.get_balance(user.id)
      assert Decimal.equal?(balance.balance, Decimal.new(0))
    end
  end

  describe "check_balance/2" do
    test "returns true when sufficient" do
      user = user_fixture()
      {:ok, _} = Ledger.get_balance(user.id)
      assert Ledger.check_balance(user.id, 0)
    end

    test "returns false when insufficient" do
      user = user_fixture()
      {:ok, _} = Ledger.get_balance(user.id)
      refute Ledger.check_balance(user.id, 100)
    end
  end

  defp user_fixture do
    {:ok, user} =
      AstraAutoEx.Accounts.register_user(%{
        email: "billing_test_#{System.unique_integer([:positive])}@example.com",
        username: "billtest#{System.unique_integer([:positive])}",
        password: "password123456"
      })

    user
  end
end
