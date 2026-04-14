defmodule AstraAutoExWeb.UserLive.Registration do
  use AstraAutoExWeb, :live_view

  alias AstraAutoEx.Accounts
  alias AstraAutoEx.Accounts.User

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="flex items-center justify-center min-h-[calc(100vh-120px)] px-4">
        <div class="glass-surface-modal p-8 w-full max-w-md animate-scale-in">
          <h2 class="text-2xl font-bold text-center mb-2 text-[var(--glass-text-primary)]">
            {dgettext("auth", "Create Account")}
          </h2>

          <p class="text-sm text-center text-[var(--glass-text-tertiary)] mb-6">
            {dgettext("auth", "Join AstraAutoEx")}
          </p>

          <.form for={@form} id="registration_form" phx-submit="save" phx-change="validate">
            <div class="mb-4">
              <label class="glass-label">{dgettext("auth", "Username")}</label>
              <input
                type="text"
                name={@form[:username].name}
                value={@form[:username].value}
                class="glass-input"
                placeholder={dgettext("auth", "Enter your username")}
                autocomplete="username"
                required
                autofocus
              /> <.field_errors field={@form[:username]} />
            </div>

            <div class="mb-4">
              <label class="glass-label">Email</label>
              <input
                type="email"
                name={@form[:email].name}
                value={@form[:email].value}
                class="glass-input"
                autocomplete="email"
                required
              /> <.field_errors field={@form[:email]} />
            </div>

            <div class="mb-6">
              <label class="glass-label">{dgettext("auth", "Password")}</label>
              <input
                type="password"
                name={@form[:password].name}
                value={@form[:password].value}
                class="glass-input"
                placeholder={dgettext("auth", "Enter your password")}
                autocomplete="new-password"
                required
                minlength="6"
              /> <.field_errors field={@form[:password]} />
            </div>

            <button
              type="submit"
              phx-disable-with="..."
              class="glass-btn glass-btn-primary w-full py-3"
            >
              {dgettext("auth", "Sign Up")}
            </button>
          </.form>

          <p class="text-center text-sm text-[var(--glass-text-tertiary)] mt-6">
            {dgettext("auth", "Already have an account?")}
            <a
              href={~p"/users/log-in"}
              class="text-[var(--glass-accent-from)] font-semibold hover:underline ml-1"
            >
              {dgettext("auth", "Sign In Now")}
            </a>
          </p>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp field_errors(assigns) do
    ~H"""
    <%= for {msg, _opts} <- @field.errors do %>
      <p class="text-sm text-[var(--glass-tone-danger-fg)] mt-1">{msg}</p>
    <% end %>
    """
  end

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:ok, redirect(socket, to: AstraAutoExWeb.UserAuth.signed_in_path(socket))}
  end

  def mount(_params, _session, socket) do
    changeset =
      User.registration_changeset(%User{}, %{}, hash_password: false, validate_unique: false)

    {:ok, assign_form(socket, changeset), temporary_assigns: [form: nil]}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, dgettext("auth", "Registration successful!"))
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      %User{}
      |> User.registration_changeset(user_params, hash_password: false, validate_unique: false)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end
end
