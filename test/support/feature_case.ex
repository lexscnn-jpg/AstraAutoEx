defmodule AstraAutoExWeb.FeatureCase do
  @moduledoc """
  Test case for Wallaby browser automation tests.
  These tests start a real server and drive Chrome headless.

  Tag tests with `@moduletag :feature` — they are excluded by default.

  Run locally (Linux/macOS): `mix test --include feature`
  Run in CI: Add `--include feature` to the CI test command.

  NOTE: Wallaby uses run_command.sh internally, which does not work
  natively on Windows. Use WSL or CI for browser tests on Windows.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      use Wallaby.Feature

      @endpoint AstraAutoExWeb.Endpoint
    end
  end

  setup _tags do
    {:ok, _} = Application.ensure_all_started(:wallaby)

    :ok = Ecto.Adapters.SQL.Sandbox.checkout(AstraAutoEx.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(AstraAutoEx.Repo, {:shared, self()})

    metadata = Phoenix.Ecto.SQL.Sandbox.metadata_for(AstraAutoEx.Repo, self())
    {:ok, session} = Wallaby.start_session(metadata: metadata)
    {:ok, session: session}
  end

  @doc "Register a user and return credentials."
  def register_user(attrs \\ %{}) do
    uniq = System.unique_integer([:positive])

    {:ok, user} =
      AstraAutoEx.Accounts.register_user(%{
        email: Map.get(attrs, :email, "wallaby_#{uniq}@example.com"),
        username: Map.get(attrs, :username, "wallaby#{uniq}"),
        password: Map.get(attrs, :password, "password123456")
      })

    %{user: user, email: user.email, password: Map.get(attrs, :password, "password123456")}
  end
end
