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
