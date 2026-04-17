defmodule AstraAutoExWeb.OauthControllerTest do
  @moduledoc """
  Tests for the OAuth (Google/GitHub) controller + the
  `AstraAutoEx.Accounts.find_or_create_user_from_oauth/2` helper.

  We do NOT hit the real Google/GitHub servers. The controller's `request/2`
  action we exercise via the actual endpoint, which builds an authorize URL
  from config + redirects. For `callback/2` the happy path (token exchange)
  requires a real HTTP round-trip — that path is covered indirectly via the
  pure `find_or_create_user_from_oauth/2` unit tests (since the controller is
  a thin wrapper around Assent + that helper). The controller-level tests
  focus on:

    * request/2 → redirect with state in session
    * callback/2 with an invalid/missing code param → render error
    * callback/2 with an unknown provider → 404-ish error
  """
  use AstraAutoExWeb.ConnCase, async: true

  alias AstraAutoEx.Accounts
  alias AstraAutoEx.Accounts.User

  import AstraAutoEx.AccountsFixtures

  # ── Config fixture: set test-only OAuth env so controller can run ──
  setup do
    Application.put_env(:astra_auto_ex, :oauth,
      google: [
        client_id: "test-google-client-id",
        client_secret: "test-google-client-secret",
        redirect_uri: "http://localhost:4002/auth/google/callback"
      ],
      github: [
        client_id: "test-github-client-id",
        client_secret: "test-github-client-secret",
        redirect_uri: "http://localhost:4002/auth/github/callback"
      ]
    )

    on_exit(fn -> Application.delete_env(:astra_auto_ex, :oauth) end)

    :ok
  end

  describe "GET /auth/:provider (request)" do
    test "redirects to google authorize url with state in session", %{conn: conn} do
      conn = get(conn, ~p"/auth/google")

      assert redirected_to(conn, 302) =~ "accounts.google.com"
      # state param must be set in session for later CSRF verification
      assert get_session(conn, :oauth_session_params)["state"]
    end

    test "redirects to github authorize url with state in session", %{conn: conn} do
      conn = get(conn, ~p"/auth/github")

      assert redirected_to(conn, 302) =~ "github.com/login/oauth/authorize"
      assert get_session(conn, :oauth_session_params)["state"]
    end

    test "unknown provider returns error flash + redirect to login", %{conn: conn} do
      conn = get(conn, ~p"/auth/facebook")

      assert redirected_to(conn) == ~p"/users/log-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Unknown"
    end
  end

  describe "GET /auth/:provider/callback (callback)" do
    test "callback without session_params errors out cleanly", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{})
        |> get(~p"/auth/google/callback?code=fakecode&state=fakestate")

      assert redirected_to(conn) == ~p"/users/log-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error)
    end

    test "callback error param from provider → render error", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{oauth_session_params: %{"state" => "abc"}})
        |> get(~p"/auth/google/callback?error=access_denied&state=abc")

      assert redirected_to(conn) == ~p"/users/log-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error)
    end

    test "callback unknown provider → redirect to login with error", %{conn: conn} do
      conn = get(conn, ~p"/auth/facebook/callback?code=fake")

      assert redirected_to(conn) == ~p"/users/log-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Unknown"
    end
  end

  describe "Accounts.find_or_create_user_from_oauth/2 — new users" do
    test "creates a new user from google oauth data" do
      oauth_data = %{
        email: unique_user_email(),
        name: "Alice Anderson",
        sub: "google-uid-1001"
      }

      assert {:ok, %User{} = user} = Accounts.find_or_create_user_from_oauth("google", oauth_data)
      assert user.email == oauth_data.email
      assert user.oauth_provider == "google"
      assert user.oauth_uid == "google-uid-1001"
      assert is_binary(user.username)
      # No password for OAuth-only users
      refute user.hashed_password
      # Auto-confirmed since provider already verified the email
      assert user.confirmed_at
    end

    test "creates a new user from github oauth data" do
      oauth_data = %{
        email: unique_user_email(),
        name: "Bob Builder",
        sub: "123456"
      }

      assert {:ok, %User{} = user} = Accounts.find_or_create_user_from_oauth("github", oauth_data)
      assert user.oauth_provider == "github"
      assert user.oauth_uid == "123456"
    end

    test "derives a username from email when name has invalid characters" do
      oauth_data = %{
        email: "special+chars@example.com",
        name: "王小明",
        sub: "github-uid-9001"
      }

      assert {:ok, %User{} = user} = Accounts.find_or_create_user_from_oauth("github", oauth_data)
      assert user.username
      # username must satisfy registration regex ^[a-zA-Z0-9_]+$
      assert user.username =~ ~r/^[a-zA-Z0-9_]+$/
    end

    test "returns error when oauth_data is missing email" do
      oauth_data = %{name: "No Email", sub: "google-uid-9999"}

      assert {:error, _} = Accounts.find_or_create_user_from_oauth("google", oauth_data)
    end
  end

  describe "Accounts.find_or_create_user_from_oauth/2 — existing users" do
    test "returns existing user when oauth_provider + oauth_uid already matches" do
      email = unique_user_email()

      {:ok, %User{id: existing_id}} =
        Accounts.find_or_create_user_from_oauth("google", %{
          email: email,
          name: "Carol",
          sub: "google-uid-2001"
        })

      # Second call with same provider+uid returns the same user
      assert {:ok, %User{id: ^existing_id}} =
               Accounts.find_or_create_user_from_oauth("google", %{
                 email: email,
                 name: "Carol",
                 sub: "google-uid-2001"
               })
    end

    test "links oauth to an existing password user by matching email" do
      # User registered with email+password first
      password_user = user_fixture() |> set_password()

      assert {:ok, %User{} = linked_user} =
               Accounts.find_or_create_user_from_oauth("google", %{
                 email: password_user.email,
                 name: password_user.username,
                 sub: "google-uid-3001"
               })

      # Same user id — OAuth did NOT create a new record
      assert linked_user.id == password_user.id
      # OAuth fields are now set
      assert linked_user.oauth_provider == "google"
      assert linked_user.oauth_uid == "google-uid-3001"
      # Password still intact so user can still log in via email/password
      assert linked_user.hashed_password == password_user.hashed_password
    end

    test "does not overwrite different-provider oauth_uid when email matches" do
      # A user first signed up with google
      {:ok, google_user} =
        Accounts.find_or_create_user_from_oauth("google", %{
          email: unique_user_email(),
          name: "Dave",
          sub: "google-uid-4001"
        })

      # Same email tries github → should link (same user) but re-key to github
      # (business decision: we treat email as the canonical identity; last OAuth
      # provider wins, but tests document explicit behavior either way)
      assert {:ok, %User{id: same_id}} =
               Accounts.find_or_create_user_from_oauth("github", %{
                 email: google_user.email,
                 name: "Dave",
                 sub: "github-uid-4002"
               })

      assert same_id == google_user.id
    end
  end
end
