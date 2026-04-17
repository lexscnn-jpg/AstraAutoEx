defmodule AstraAutoEx.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias AstraAutoEx.Repo

  alias AstraAutoEx.Accounts.{User, UserToken, UserNotifier, UserPreference, UserBalance}

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  ## OAuth (Google / GitHub) sign-in

  @type oauth_data :: %{
          required(:email) => String.t(),
          required(:sub) => String.t(),
          optional(:name) => String.t() | nil,
          optional(:picture) => String.t() | nil
        }

  @doc """
  Finds or creates a user from OAuth provider data.

  Resolution order:

    1. If a user with this `(provider, oauth_uid)` already exists → return it.
    2. Else if a user with the same email exists → link OAuth to it
       (updates oauth_provider + oauth_uid, keeps any existing password).
    3. Else → create a new OAuth-only user (no password, auto-confirmed).

  `oauth_data` must include `:email` and `:sub`. `:name` is used to derive a
  username. `:picture` is optional and will be stored as avatar_url.

  Returns `{:ok, user}` or `{:error, changeset}`.
  """
  @spec find_or_create_user_from_oauth(String.t(), oauth_data()) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t() | atom()}
  def find_or_create_user_from_oauth(provider, oauth_data)
      when is_binary(provider) and is_map(oauth_data) do
    with {:ok, email} <- fetch_oauth_field(oauth_data, :email),
         {:ok, sub} <- fetch_oauth_field(oauth_data, :sub) do
      uid = to_string(sub)

      case Repo.get_by(User, oauth_provider: provider, oauth_uid: uid) do
        %User{} = user ->
          {:ok, user}

        nil ->
          find_by_email_or_create(provider, uid, email, oauth_data)
      end
    end
  end

  defp fetch_oauth_field(data, key) do
    case Map.get(data, key) || Map.get(data, to_string(key)) do
      nil -> {:error, :"missing_#{key}"}
      "" -> {:error, :"missing_#{key}"}
      value -> {:ok, value}
    end
  end

  defp find_by_email_or_create(provider, uid, email, oauth_data) do
    case get_user_by_email(email) do
      %User{} = existing_user ->
        link_oauth_to_user(existing_user, provider, uid, oauth_data)

      nil ->
        create_oauth_user(provider, uid, email, oauth_data)
    end
  end

  defp link_oauth_to_user(user, provider, uid, oauth_data) do
    user
    |> User.oauth_link_changeset(%{
      oauth_provider: provider,
      oauth_uid: uid,
      avatar_url: user.avatar_url || Map.get(oauth_data, :picture)
    })
    |> Repo.update()
  end

  defp create_oauth_user(provider, uid, email, oauth_data) do
    %User{}
    |> User.oauth_registration_changeset(%{
      email: email,
      username: derive_username(oauth_data, email),
      oauth_provider: provider,
      oauth_uid: uid,
      avatar_url: Map.get(oauth_data, :picture)
    })
    |> Repo.insert()
  end

  # Derive a valid username (regex ^[a-zA-Z0-9_]+$, 2-30 chars).
  # Strategy: sanitize `name` first; if empty, fall back to email local-part;
  # if still empty/conflicting, append a short random suffix.
  defp derive_username(oauth_data, email) do
    base =
      oauth_data
      |> Map.get(:name, "")
      |> to_string()
      |> sanitize_username()
      |> fallback_to_email_local(email)

    ensure_unique_username(base)
  end

  defp sanitize_username(s) do
    s
    |> String.replace(~r/[^a-zA-Z0-9_]+/, "_")
    |> String.trim("_")
    |> String.slice(0, 24)
  end

  defp fallback_to_email_local("", email) do
    email
    |> String.split("@", parts: 2)
    |> List.first()
    |> to_string()
    |> sanitize_username()
    |> case do
      "" -> "user"
      short when byte_size(short) < 2 -> short <> "_" <> random_suffix()
      ok -> ok
    end
  end

  defp fallback_to_email_local(base, _email) when byte_size(base) < 2 do
    base <> "_" <> random_suffix()
  end

  defp fallback_to_email_local(base, _email), do: base

  defp ensure_unique_username(base) do
    if Repo.get_by(User, username: base), do: base <> "_" <> random_suffix(), else: base
  end

  defp random_suffix do
    :crypto.strong_rand_bytes(4) |> Base.url_encode64(padding: false) |> String.slice(0, 6)
  end

  def register_admin(attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(
      :user,
      User.registration_changeset(%User{}, Map.put(attrs, "role", "admin"))
    )
    |> Ecto.Multi.insert(:preference, fn %{user: user} ->
      %UserPreference{user_id: user.id}
      |> UserPreference.changeset(Map.get(attrs, "preference", %{}))
    end)
    |> Ecto.Multi.insert(:balance, fn %{user: user} ->
      %UserBalance{user_id: user.id}
      |> UserBalance.changeset(%{})
    end)
    |> Repo.transaction()
  end

  def user_count do
    Repo.aggregate(User, :count)
  end

  ## User Preferences

  def get_user_preference(user_id) do
    Repo.get_by(UserPreference, user_id: user_id)
  end

  def update_user_preference(%UserPreference{} = preference, attrs) do
    preference
    |> UserPreference.changeset(attrs)
    |> Repo.update()
  end

  def create_user_preference(attrs) do
    %UserPreference{}
    |> UserPreference.changeset(attrs)
    |> Repo.insert()
  end

  ## User Balance

  def get_user_balance(user_id) do
    Repo.get_by(UserBalance, user_id: user_id)
  end

  ## Settings

  @doc """
  Checks whether the user is in sudo mode.

  The user is in sudo mode when the last authentication was done no further
  than 20 minutes ago. The limit can be given as second argument in minutes.
  """
  def sudo_mode?(user, minutes \\ -20)

  def sudo_mode?(%User{authenticated_at: ts}, minutes) when is_struct(ts, DateTime) do
    DateTime.after?(ts, DateTime.utc_now() |> DateTime.add(minutes, :minute))
  end

  def sudo_mode?(_user, _minutes), do: false

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  See `AstraAutoEx.Accounts.User.email_changeset/3` for a list of supported options.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}, opts \\ []) do
    User.email_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    Repo.transact(fn ->
      with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
           %UserToken{sent_to: email} <- Repo.one(query),
           {:ok, user} <- Repo.update(User.email_changeset(user, %{email: email})),
           {_count, _result} <-
             Repo.delete_all(from(UserToken, where: [user_id: ^user.id, context: ^context])) do
        {:ok, user}
      else
        _ -> {:error, :transaction_aborted}
      end
    end)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  See `AstraAutoEx.Accounts.User.password_changeset/3` for a list of supported options.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}, opts \\ []) do
    User.password_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user password.

  Returns a tuple with the updated user, as well as a list of expired tokens.

  ## Examples

      iex> update_user_password(user, %{password: ...})
      {:ok, {%User{}, [...]}}

      iex> update_user_password(user, %{password: "too short"})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, attrs) do
    user
    |> User.password_changeset(attrs)
    |> update_user_and_delete_all_tokens()
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.

  If the token is valid `{user, token_inserted_at}` is returned, otherwise `nil` is returned.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Gets the user with the given magic link token.
  """
  def get_user_by_magic_link_token(token) do
    with {:ok, query} <- UserToken.verify_magic_link_token_query(token),
         {user, _token} <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Logs the user in by magic link.

  There are three cases to consider:

  1. The user has already confirmed their email. They are logged in
     and the magic link is expired.

  2. The user has not confirmed their email and no password is set.
     In this case, the user gets confirmed, logged in, and all tokens -
     including session ones - are expired. In theory, no other tokens
     exist but we delete all of them for best security practices.

  3. The user has not confirmed their email but a password is set.
     This cannot happen in the default implementation but may be the
     source of security pitfalls. See the "Mixing magic link and password registration" section of
     `mix help phx.gen.auth`.
  """
  def login_user_by_magic_link(token) do
    {:ok, query} = UserToken.verify_magic_link_token_query(token)

    case Repo.one(query) do
      # Prevent session fixation attacks by disallowing magic links for unconfirmed users with password
      {%User{confirmed_at: nil, hashed_password: hash}, _token} when not is_nil(hash) ->
        raise """
        magic link log in is not allowed for unconfirmed users with a password set!

        This cannot happen with the default implementation, which indicates that you
        might have adapted the code to a different use case. Please make sure to read the
        "Mixing magic link and password registration" section of `mix help phx.gen.auth`.
        """

      {%User{confirmed_at: nil} = user, _token} ->
        user
        |> User.confirm_changeset()
        |> update_user_and_delete_all_tokens()

      {user, token} ->
        Repo.delete!(token)
        {:ok, {user, []}}

      nil ->
        {:error, :not_found}
    end
  end

  @doc ~S"""
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_user_update_email_instructions(user, current_email, &url(~p"/users/settings/confirm-email/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Delivers the magic link login instructions to the given user.
  """
  def deliver_login_instructions(%User{} = user, magic_link_url_fun)
      when is_function(magic_link_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "login")
    Repo.insert!(user_token)
    UserNotifier.deliver_login_instructions(user, magic_link_url_fun.(encoded_token))
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(from(UserToken, where: [token: ^token, context: "session"]))
    :ok
  end

  ## Token helper

  defp update_user_and_delete_all_tokens(changeset) do
    Repo.transact(fn ->
      with {:ok, user} <- Repo.update(changeset) do
        tokens_to_expire = Repo.all_by(UserToken, user_id: user.id)

        Repo.delete_all(from(t in UserToken, where: t.id in ^Enum.map(tokens_to_expire, & &1.id)))

        {:ok, {user, tokens_to_expire}}
      end
    end)
  end
end
