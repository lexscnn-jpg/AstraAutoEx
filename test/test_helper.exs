ExUnit.start(exclude: [:feature])
Ecto.Adapters.SQL.Sandbox.mode(AstraAutoEx.Repo, :manual)

# Wallaby is started on-demand when feature tests run.
# Run feature tests with: mix test --include feature
