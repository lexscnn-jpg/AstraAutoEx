defmodule AstraAutoExWeb.UserLive.Login do
  use AstraAutoExWeb, :live_view

  alias AstraAutoEx.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="flex items-center justify-center min-h-[calc(100vh-120px)] px-4">
        <div class="glass-surface-modal p-8 w-full max-w-md animate-scale-in">
          <h2 class="text-2xl font-bold text-center mb-2 text-[var(--glass-text-primary)]">
            {dgettext("auth", "Welcome Back")}
          </h2>

          <p class="text-sm text-center text-[var(--glass-text-tertiary)] mb-6">
            {dgettext("auth", "Sign in to AstraAutoEx")}
          </p>

          <.form
            :let={f}
            for={@form}
            id="login_form_password"
            action={~p"/users/log-in"}
            phx-submit="submit_password"
            phx-trigger-action={@trigger_submit}
          >
            <div class="mb-4">
              <label class="glass-label">Email</label>
              <input
                type="email"
                name={f[:email].name}
                value={f[:email].value}
                class="glass-input"
                placeholder="name@example.com"
                autocomplete="email"
                required
                autofocus
              />
            </div>

            <div class="mb-6">
              <label class="glass-label">{dgettext("auth", "Password")}</label>
              <input
                type="password"
                name="user[password]"
                class="glass-input"
                placeholder={dgettext("auth", "Enter your password")}
                autocomplete="current-password"
              />
            </div>

            <button
              type="submit"
              name={@form[:remember_me].name}
              value="true"
              class="glass-btn glass-btn-primary w-full py-3"
            >
              {dgettext("auth", "Sign In")}
            </button>
          </.form>

          <div class="flex items-center gap-3 my-6" aria-hidden="true">
            <div class="flex-1 h-px bg-[var(--glass-border)]"></div>

            <span class="text-xs uppercase tracking-wide text-[var(--glass-text-tertiary)]">
              {dgettext("auth", "or continue with")}
            </span>
            <div class="flex-1 h-px bg-[var(--glass-border)]"></div>
          </div>

          <div class="grid grid-cols-1 gap-3">
            <a
              href={~p"/auth/google"}
              data-test-id="oauth-google"
              class="glass-btn w-full py-3 flex items-center justify-center gap-3 hover:bg-white/10 transition"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 48 48"
                class="w-5 h-5"
                aria-hidden="true"
              >
                <path
                  fill="#FFC107"
                  d="M43.6 20.5H42V20H24v8h11.3c-1.6 4.7-6.1 8-11.3 8-6.6 0-12-5.4-12-12s5.4-12 12-12c3.1 0 5.9 1.2 8 3.1l5.7-5.7C34 6.1 29.3 4 24 4 12.9 4 4 12.9 4 24s8.9 20 20 20 20-8.9 20-20c0-1.3-.1-2.4-.4-3.5z"
                />
                <path
                  fill="#FF3D00"
                  d="M6.3 14.7l6.6 4.8C14.6 15.1 18.9 12 24 12c3.1 0 5.9 1.2 8 3.1l5.7-5.7C34 6.1 29.3 4 24 4 16.3 4 9.6 8.3 6.3 14.7z"
                />
                <path
                  fill="#4CAF50"
                  d="M24 44c5.2 0 9.9-2 13.4-5.2l-6.2-5.1c-2 1.5-4.5 2.3-7.2 2.3-5.2 0-9.6-3.3-11.2-8l-6.5 5C9.5 39.6 16.2 44 24 44z"
                />
                <path
                  fill="#1976D2"
                  d="M43.6 20.5H42V20H24v8h11.3c-.8 2.3-2.3 4.3-4.2 5.7l6.2 5.1C41.3 36.3 44 30.6 44 24c0-1.3-.1-2.4-.4-3.5z"
                />
              </svg>
              <span class="font-medium text-[var(--glass-text-primary)]">
                {dgettext("auth", "Sign in with Google")}
              </span>
            </a>
            <a
              href={~p"/auth/github"}
              data-test-id="oauth-github"
              class="glass-btn w-full py-3 flex items-center justify-center gap-3 hover:bg-white/10 transition"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 24 24"
                class="w-5 h-5 fill-current text-[var(--glass-text-primary)]"
                aria-hidden="true"
              >
                <path d="M12 .3a12 12 0 0 0-3.79 23.38c.6.11.82-.26.82-.58v-2.24c-3.34.73-4.04-1.43-4.04-1.43-.55-1.39-1.34-1.76-1.34-1.76-1.1-.75.08-.74.08-.74 1.22.09 1.86 1.25 1.86 1.25 1.08 1.85 2.82 1.31 3.51 1 .11-.79.42-1.31.76-1.62-2.67-.3-5.47-1.33-5.47-5.93 0-1.31.47-2.38 1.23-3.22-.12-.3-.54-1.52.12-3.18 0 0 1-.32 3.3 1.23a11.46 11.46 0 0 1 6 0c2.29-1.55 3.29-1.23 3.29-1.23.67 1.66.25 2.88.12 3.18.77.84 1.23 1.91 1.23 3.22 0 4.61-2.8 5.63-5.48 5.92.43.37.81 1.1.81 2.22v3.29c0 .32.21.69.83.58A12 12 0 0 0 12 .3" />
              </svg>
              <span class="font-medium text-[var(--glass-text-primary)]">
                {dgettext("auth", "Sign in with GitHub")}
              </span>
            </a>
          </div>

          <p class="text-center text-sm text-[var(--glass-text-tertiary)] mt-6">
            {dgettext("auth", "Don't have an account?")}
            <a
              href={~p"/users/register"}
              class="text-[var(--glass-accent-from)] font-semibold hover:underline ml-1"
            >
              {dgettext("auth", "Sign Up Now")}
            </a>
          </p>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email}, as: "user")

    {:ok, assign(socket, form: form, trigger_submit: false)}
  end

  @impl true
  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end

  def handle_event("submit_magic", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_login_instructions(
        user,
        &url(~p"/users/log-in/#{&1}")
      )
    end

    {:noreply,
     socket
     |> put_flash(:info, "If your email is in our system, you will receive instructions shortly.")
     |> push_navigate(to: ~p"/users/log-in")}
  end
end
