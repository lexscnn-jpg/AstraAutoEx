defmodule AstraAutoEx.Repo do
  use Ecto.Repo,
    otp_app: :astra_auto_ex,
    adapter: Ecto.Adapters.Postgres
end
