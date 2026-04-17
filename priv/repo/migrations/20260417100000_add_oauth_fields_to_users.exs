defmodule AstraAutoEx.Repo.Migrations.AddOauthFieldsToUsers do
  @moduledoc """
  Adds third-party OAuth identity fields to the users table to support
  Google / GitHub sign-in.

  * `oauth_provider` — e.g. "google" | "github" (nullable — email+password users
    keep this NULL)
  * `oauth_uid` — the provider-specific stable user ID (Google `sub`, GitHub
    numeric id)

  A partial unique index on (oauth_provider, oauth_uid) ensures the same
  provider identity cannot be bound to two local accounts. Partial so that
  password-only users (both columns NULL) don't collide with each other.
  """
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :oauth_provider, :string
      add :oauth_uid, :string
    end

    create unique_index(
             :users,
             [:oauth_provider, :oauth_uid],
             name: :users_oauth_provider_uid_index,
             where: "oauth_provider IS NOT NULL AND oauth_uid IS NOT NULL"
           )
  end
end
