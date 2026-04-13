import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :pbkdf2_elixir, :rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :astra_auto_ex, AstraAutoEx.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "astra_auto_ex_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :astra_auto_ex, AstraAutoExWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "BQmEJOgyIgFpdGs2gknPUqd2aPpJZBMdGcIhTaTVFKe1I+Sy3hXPR8YoWo2qKPEd",
  server: true

# In test we don't send emails
config :astra_auto_ex, AstraAutoEx.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Enable SQL sandbox for Wallaby
config :astra_auto_ex, :sql_sandbox, true

# Disable task scheduler in tests to avoid DB connection leaks
config :astra_auto_ex, :disable_scheduler, true

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

# Wallaby browser testing
config :wallaby,
  driver: Wallaby.Chrome,
  chromedriver: [
    path:
      System.get_env(
        "CHROMEDRIVER_PATH",
        Path.join([
          System.get_env("APPDATA", ""),
          "npm",
          "node_modules",
          "chromedriver",
          "lib",
          "chromedriver",
          "chromedriver.exe"
        ])
      ),
    headless: true
  ],
  screenshot_on_failure: true,
  screenshot_dir: "tmp/wallaby_screenshots"
