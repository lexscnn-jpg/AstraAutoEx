defmodule AstraAutoEx.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "users" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :confirmed_at, :utc_datetime
    field :authenticated_at, :utc_datetime, virtual: true
    field :username, :string
    field :role, :string, default: "user"
    field :avatar_url, :string
    field :locale, :string, default: "zh"
    # Third-party OAuth identity (Google / GitHub). NULL for password-only users.
    field :oauth_provider, :string
    field :oauth_uid, :string

    has_one :preference, AstraAutoEx.Accounts.UserPreference
    has_one :balance, AstraAutoEx.Accounts.UserBalance
    has_many :projects, AstraAutoEx.Projects.Project

    timestamps(type: :utc_datetime)
  end

  @doc """
  A user changeset for registering or changing the email.

  It requires the email to change otherwise an error is added.

  ## Options

    * `:validate_unique` - Set to false if you don't want to validate the
      uniqueness of the email, useful when displaying live validations.
      Defaults to `true`.
  """
  def email_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email])
    |> validate_email(opts)
  end

  def profile_changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :avatar_url, :locale])
    |> validate_required([:username])
    |> validate_length(:username, min: 2, max: 30)
    |> validate_format(:username, ~r/^[a-zA-Z0-9_]+$/,
      message: "only letters, numbers, and underscores"
    )
    |> unsafe_validate_unique(:username, AstraAutoEx.Repo)
    |> unique_constraint(:username)
    |> validate_inclusion(:locale, ["en", "zh"])
  end

  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :username, :role, :password])
    |> validate_email(
      Keyword.put(opts, :validate_unique, Keyword.get(opts, :validate_unique, true))
    )
    |> validate_required([:username])
    |> validate_length(:username, min: 2, max: 30)
    |> validate_format(:username, ~r/^[a-zA-Z0-9_]+$/,
      message: "only letters, numbers, and underscores"
    )
    |> unsafe_validate_unique(:username, AstraAutoEx.Repo)
    |> unique_constraint(:username)
    |> validate_inclusion(:role, ["user", "admin"])
    |> validate_password(opts)
  end

  defp validate_email(changeset, opts) do
    changeset =
      changeset
      |> validate_required([:email])
      |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
        message: "must have the @ sign and no spaces"
      )
      |> validate_length(:email, max: 160)

    if Keyword.get(opts, :validate_unique, true) do
      changeset
      |> unsafe_validate_unique(:email, AstraAutoEx.Repo)
      |> unique_constraint(:email)
      |> validate_email_changed()
    else
      changeset
    end
  end

  defp validate_email_changed(changeset) do
    if get_field(changeset, :email) && get_change(changeset, :email) == nil do
      add_error(changeset, :email, "did not change")
    else
      changeset
    end
  end

  @doc """
  A user changeset for changing the password.

  It is important to validate the length of the password, as long passwords may
  be very expensive to hash for certain algorithms.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.
  """
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_required([:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  defp validate_password(changeset, opts) do
    # Password is optional at registration (magic-link flow).
    # Only validate if password is present or explicitly required via opts.
    if get_change(changeset, :password) do
      changeset
      |> validate_length(:password, min: 6, max: 72)
      |> maybe_hash_password(opts)
    else
      changeset
    end
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      # Hashing could be done with `Ecto.Changeset.prepare_changes/2`, but that
      # would keep the database transaction open longer and hurt performance.
      |> put_change(:hashed_password, Pbkdf2.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user) do
    now = DateTime.utc_now(:second)
    change(user, confirmed_at: now)
  end

  @doc """
  Changeset for registering a new user from OAuth provider data.

  * `email` is validated but password is NOT required (OAuth-only user)
  * `oauth_provider` + `oauth_uid` must be present
  * Email is auto-confirmed (provider verified it for us)
  """
  @spec oauth_registration_changeset(t(), map()) :: Ecto.Changeset.t()
  def oauth_registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :username, :oauth_provider, :oauth_uid, :avatar_url])
    |> validate_required([:email, :username, :oauth_provider, :oauth_uid])
    |> validate_email(validate_unique: true)
    |> validate_length(:username, min: 2, max: 30)
    |> validate_format(:username, ~r/^[a-zA-Z0-9_]+$/,
      message: "only letters, numbers, and underscores"
    )
    |> unsafe_validate_unique(:username, AstraAutoEx.Repo)
    |> unique_constraint(:username)
    |> unique_constraint([:oauth_provider, :oauth_uid],
      name: :users_oauth_provider_uid_index
    )
    |> put_change(:confirmed_at, DateTime.utc_now(:second))
  end

  @doc """
  Changeset for linking OAuth identity to an already-existing local user.
  Only writes oauth_provider + oauth_uid (and optional avatar).
  """
  @spec oauth_link_changeset(t(), map()) :: Ecto.Changeset.t()
  def oauth_link_changeset(user, attrs) do
    user
    |> cast(attrs, [:oauth_provider, :oauth_uid, :avatar_url])
    |> validate_required([:oauth_provider, :oauth_uid])
    |> unique_constraint([:oauth_provider, :oauth_uid],
      name: :users_oauth_provider_uid_index
    )
  end

  @doc """
  Verifies the password.

  If there is no user or the user doesn't have a password, we call
  `Pbkdf2.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%AstraAutoEx.Accounts.User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Pbkdf2.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Pbkdf2.no_user_verify()
    false
  end
end
