defmodule AstraAutoExWeb.OauthController do
  @moduledoc """
  Third-party OAuth sign-in controller (Google / GitHub).

  ## Flow

    1. User clicks "Sign in with Google" → `GET /auth/google`
       `request/2` builds an authorize URL via Assent + stashes session params
       (CSRF state + PKCE verifier if enabled) into the session, then 302s to
       the provider.

    2. Provider redirects back → `GET /auth/:provider/callback?code=…&state=…`
       `callback/2` reads the session params back out, exchanges the code for
       a token, fetches the profile, and calls
       `Accounts.find_or_create_user_from_oauth/2` to resolve-or-create the
       local user. On success it logs the user in via `UserAuth.log_in_user/2`.

  Configuration is read at runtime from `Application.get_env(:astra_auto_ex, :oauth)`:

      config :astra_auto_ex, :oauth,
        google: [
          client_id: System.get_env("GOOGLE_CLIENT_ID"),
          client_secret: System.get_env("GOOGLE_CLIENT_SECRET"),
          redirect_uri: "http://localhost:4000/auth/google/callback"
        ],
        github: [
          client_id: System.get_env("GITHUB_CLIENT_ID"),
          client_secret: System.get_env("GITHUB_CLIENT_SECRET"),
          redirect_uri: "http://localhost:4000/auth/github/callback"
        ]
  """
  use AstraAutoExWeb, :controller

  alias AstraAutoEx.Accounts
  alias AstraAutoExWeb.UserAuth

  @providers %{
    "google" => Assent.Strategy.Google,
    "github" => Assent.Strategy.Github
  }

  @session_key :oauth_session_params

  @doc """
  Phase 1 — build the authorize URL and redirect the user's browser there.
  """
  @spec request(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def request(conn, %{"provider" => provider}) do
    with {:ok, strategy} <- fetch_strategy(provider),
         {:ok, config} <- fetch_provider_config(provider),
         {:ok, %{url: url, session_params: session_params}} <-
           strategy.authorize_url(config) do
      conn
      |> put_session(@session_key, stringify_session_params(session_params))
      |> redirect(external: url)
    else
      {:error, :unknown_provider} ->
        conn
        |> put_flash(:error, "Unknown OAuth provider: #{provider}")
        |> redirect(to: ~p"/users/log-in")

      {:error, :missing_config} ->
        conn
        |> put_flash(:error, "OAuth provider #{provider} is not configured")
        |> redirect(to: ~p"/users/log-in")

      {:error, _other} ->
        conn
        |> put_flash(:error, "Unable to start #{provider} sign-in")
        |> redirect(to: ~p"/users/log-in")
    end
  end

  @doc """
  Phase 2 — handle the callback: exchange code → user profile → local user.
  """
  @spec callback(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def callback(conn, %{"provider" => provider} = params) do
    with {:ok, strategy} <- fetch_strategy(provider),
         {:ok, config} <- fetch_provider_config(provider),
         {:ok, session_params} <- fetch_session_params(conn),
         config <- Keyword.put(config, :session_params, atomize_session_params(session_params)),
         {:ok, %{user: oauth_user}} <- strategy.callback(config, params),
         {:ok, local_user} <-
           Accounts.find_or_create_user_from_oauth(provider, normalize_oauth_user(oauth_user)) do
      conn
      |> delete_session(@session_key)
      |> put_flash(:info, "Signed in with #{String.capitalize(provider)}")
      |> UserAuth.log_in_user(local_user)
    else
      {:error, :unknown_provider} ->
        conn
        |> put_flash(:error, "Unknown OAuth provider: #{provider}")
        |> redirect(to: ~p"/users/log-in")

      {:error, :missing_config} ->
        conn
        |> put_flash(:error, "OAuth provider #{provider} is not configured")
        |> redirect(to: ~p"/users/log-in")

      {:error, :missing_session_params} ->
        conn
        |> put_flash(:error, "OAuth session expired — please try again")
        |> redirect(to: ~p"/users/log-in")

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_flash(:error, "Could not link account: #{changeset_error_summary(changeset)}")
        |> redirect(to: ~p"/users/log-in")

      {:error, %{__struct__: _} = assent_error} ->
        conn
        |> delete_session(@session_key)
        |> put_flash(:error, "OAuth sign-in failed: #{exception_message(assent_error)}")
        |> redirect(to: ~p"/users/log-in")

      {:error, reason} ->
        conn
        |> delete_session(@session_key)
        |> put_flash(:error, "OAuth sign-in failed: #{inspect(reason)}")
        |> redirect(to: ~p"/users/log-in")
    end
  end

  # ── helpers ──

  defp fetch_strategy(provider) do
    case Map.fetch(@providers, provider) do
      {:ok, mod} -> {:ok, mod}
      :error -> {:error, :unknown_provider}
    end
  end

  defp fetch_provider_config(provider) do
    oauth_env = Application.get_env(:astra_auto_ex, :oauth, [])

    config =
      oauth_env
      |> Keyword.get(String.to_existing_atom(provider), [])

    if Keyword.get(config, :client_id) in [nil, ""] do
      {:error, :missing_config}
    else
      {:ok, config}
    end
  rescue
    ArgumentError -> {:error, :unknown_provider}
  end

  defp fetch_session_params(conn) do
    case get_session(conn, @session_key) do
      nil -> {:error, :missing_session_params}
      params when is_map(params) and map_size(params) == 0 -> {:error, :missing_session_params}
      params -> {:ok, params}
    end
  end

  # Assent uses string keys when we stash in session (JSON-friendly) but its
  # callback expects atom-keyed state in session_params.
  defp stringify_session_params(params) when is_map(params) do
    Map.new(params, fn {k, v} -> {to_string(k), v} end)
  end

  defp atomize_session_params(params) when is_map(params) do
    Map.new(params, fn
      {k, v} when is_binary(k) -> {String.to_atom(k), v}
      {k, v} -> {k, v}
    end)
  end

  # Assent returns normalized user maps with string keys (OIDC / custom
  # strategies). Project them down to what Accounts.find_or_create_user_from_oauth
  # expects: %{email:, name:, sub:, picture:}
  defp normalize_oauth_user(user) when is_map(user) do
    %{
      email: Map.get(user, "email"),
      name: Map.get(user, "name") || Map.get(user, "preferred_username"),
      sub: user |> Map.get("sub") |> to_string(),
      picture: Map.get(user, "picture")
    }
  end

  defp changeset_error_summary(%Ecto.Changeset{errors: errors}) do
    errors
    |> Enum.map_join(", ", fn {field, {msg, _}} -> "#{field}: #{msg}" end)
  end

  defp exception_message(%_{} = err) do
    cond do
      Map.has_key?(err, :message) and is_binary(err.message) ->
        err.message

      function_exported?(err.__struct__, :message, 1) ->
        Exception.message(err)

      true ->
        inspect(err)
    end
  end
end
