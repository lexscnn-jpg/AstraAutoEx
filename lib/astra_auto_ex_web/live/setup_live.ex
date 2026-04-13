defmodule AstraAutoExWeb.SetupLive do
  use AstraAutoExWeb, :live_view

  alias AstraAutoEx.Accounts
  alias AstraAutoEx.Accounts.User

  @steps [:admin, :providers, :storage, :summary]

  @impl true
  def mount(_params, _session, socket) do
    if Accounts.user_count() > 0 do
      {:ok, push_navigate(socket, to: ~p"/home")}
    else
      changeset =
        User.registration_changeset(%User{}, %{}, hash_password: false, validate_unique: false)

      {:ok,
       socket
       |> assign(:step, :admin)
       |> assign(:steps, @steps)
       |> assign(:admin_form, to_form(changeset, as: "user"))
       |> assign(:provider_configs, %{})
       |> assign(:selected_providers, [])
       |> assign(:provider_form, to_form(%{"provider" => "", "api_key" => ""}, as: "provider"))
       |> assign(:storage_type, "local")
       |> assign(
         :storage_form,
         to_form(
           %{
             "type" => "local",
             "bucket" => "",
             "region" => "",
             "endpoint" => "",
             "access_key" => "",
             "secret_key" => ""
           },
           as: "storage"
         )
       )
       |> assign(:page_title, dgettext("setup", "AstraAutoEx Setup"))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="glass-page flex items-center justify-center p-4">
      <div class="glass-surface-modal w-full max-w-2xl p-8">
        <h2 class="text-2xl font-bold mb-2 text-[var(--glass-text-primary)]">
          {dgettext("setup", "AstraAutoEx Setup")}
        </h2>
        
    <!-- Step indicator -->
        <div class="flex gap-2 mb-8">
          <%= for {step_atom, label} <- [{:admin, dgettext("setup", "Admin")}, {:providers, dgettext("setup", "Providers")}, {:storage, dgettext("setup", "Storage")}, {:summary, dgettext("setup", "Done")}] do %>
            <div class={[
              "flex-1 text-center py-2 rounded-full text-sm font-semibold transition-all",
              (step_active?(@step, step_atom) &&
                 "bg-gradient-to-r from-[var(--glass-accent-from)] to-[var(--glass-accent-to)] text-white") ||
                "bg-[var(--glass-bg-muted)] text-[var(--glass-text-tertiary)]"
            ]}>
              {label}
            </div>
          <% end %>
        </div>
        
    <!-- Step content -->
        <%= case @step do %>
          <% :admin -> %>
            <.admin_step form={@admin_form} />
          <% :providers -> %>
            <.providers_step
              provider_form={@provider_form}
              provider_configs={@provider_configs}
              selected_providers={@selected_providers}
            />
          <% :storage -> %>
            <.storage_step storage_form={@storage_form} storage_type={@storage_type} />
          <% :summary -> %>
            <.summary_step
              provider_configs={@provider_configs}
              storage_type={@storage_type}
            />
        <% end %>
      </div>
    </div>
    """
  end

  ## Step Components

  defp admin_step(assigns) do
    ~H"""
    <div>
      <h3 class="text-lg font-semibold mb-4">{dgettext("setup", "Create Admin Account")}</h3>
      <.form for={@form} id="admin-form" phx-submit="save_admin" phx-change="validate_admin">
        <div class="form-control mb-3">
          <label class="glass-label mb-1"><span>{dgettext("auth", "Username")}</span></label>
          <input
            type="text"
            name={@form[:username].name}
            value={@form[:username].value}
            class={["glass-input", @form[:username].errors != [] && "input-error"]}
            required
            autofocus
          />
          <.field_errors field={@form[:username]} />
        </div>
        <div class="form-control mb-3">
          <label class="glass-label mb-1"><span>{dgettext("setup", "Email")}</span></label>
          <input
            type="email"
            name={@form[:email].name}
            value={@form[:email].value}
            class={["glass-input", @form[:email].errors != [] && "input-error"]}
            required
          />
          <.field_errors field={@form[:email]} />
        </div>
        <div class="form-control mb-4">
          <label class="glass-label mb-1"><span>{dgettext("auth", "Password")}</span></label>
          <input
            type="password"
            name={@form[:password].name}
            value={@form[:password].value}
            class={["glass-input", @form[:password].errors != [] && "input-error"]}
            required
            minlength="6"
          />
          <.field_errors field={@form[:password]} />
        </div>
        <div class="card-actions justify-end">
          <button type="submit" class="glass-btn glass-btn-primary">
            {dgettext("default", "Next")} →
          </button>
        </div>
      </.form>
    </div>
    """
  end

  defp providers_step(assigns) do
    ~H"""
    <div>
      <h3 class="text-lg font-semibold mb-2">{dgettext("setup", "Configure AI Providers")}</h3>
      <p class="text-sm text-base-content/60 mb-4">
        {dgettext("setup", "Add at least one AI provider to get started.")}
      </p>
      
    <!-- Configured providers -->
      <%= if map_size(@provider_configs) > 0 do %>
        <div class="mb-4 space-y-2">
          <%= for {name, _config} <- @provider_configs do %>
            <div class="alert alert-success py-2">
              <span>{provider_label(name)}</span>
              <button
                type="button"
                phx-click="remove_provider"
                phx-value-name={name}
                class="btn btn-ghost btn-xs"
              >
                ✕
              </button>
            </div>
          <% end %>
        </div>
      <% end %>
      
    <!-- Add provider form -->
      <.form
        for={@provider_form}
        id="provider-form"
        phx-submit="add_provider"
        phx-change="validate_provider"
      >
        <div class="flex gap-2 mb-3">
          <select name="provider[provider]" class="glass-select flex-1">
            <option value="">{dgettext("setup", "Select provider...")}</option>
            <%= for p <- available_providers(@selected_providers) do %>
              <option value={p.id}>{p.label}</option>
            <% end %>
          </select>
        </div>
        <div class="form-control mb-3">
          <input
            type="password"
            name="provider[api_key]"
            placeholder={dgettext("setup", "API Key")}
            class="glass-input"
            autocomplete="off"
          />
        </div>
        <div class="flex gap-2">
          <button type="submit" class="glass-btn glass-btn-secondary text-sm py-1.5">
            {dgettext("setup", "Add Provider")}
          </button>
        </div>
      </.form>

      <div class="card-actions justify-between mt-6">
        <button type="button" phx-click="prev_step" class="glass-btn glass-btn-ghost">
          ← {dgettext("default", "Back")}
        </button>
        <button
          type="button"
          phx-click="next_step"
          class={["btn btn-primary", map_size(@provider_configs) == 0 && "btn-disabled"]}
        >
          {dgettext("default", "Next")} →
        </button>
      </div>
    </div>
    """
  end

  defp storage_step(assigns) do
    ~H"""
    <div>
      <h3 class="text-lg font-semibold mb-2">{dgettext("setup", "Storage Configuration")}</h3>
      <p class="text-sm text-base-content/60 mb-4">
        {dgettext("setup", "Choose where to store generated media files.")}
      </p>

      <.form
        for={@storage_form}
        id="storage-form"
        phx-submit="save_storage"
        phx-change="change_storage_type"
      >
        <div class="form-control mb-4">
          <label class="label cursor-pointer justify-start gap-3">
            <input
              type="radio"
              name="storage[type]"
              value="local"
              class="radio"
              checked={@storage_type == "local"}
            />
            <div>
              <span class="label-text font-medium">{dgettext("setup", "Local Storage")}</span>
              <p class="text-xs text-base-content/60">
                {dgettext("setup", "Files stored on the server. Zero configuration needed.")}
              </p>
            </div>
          </label>
          <label class="label cursor-pointer justify-start gap-3">
            <input
              type="radio"
              name="storage[type]"
              value="s3"
              class="radio"
              checked={@storage_type == "s3"}
            />
            <div>
              <span class="label-text font-medium">{dgettext("setup", "S3 / MinIO")}</span>
              <p class="text-xs text-base-content/60">
                {dgettext("setup", "Compatible with AWS S3 or self-hosted MinIO.")}
              </p>
            </div>
          </label>
        </div>

        <%= if @storage_type == "s3" do %>
          <div class="space-y-3 p-4 bg-base-200 rounded-lg">
            <div class="form-control">
              <label class="glass-label mb-1"><span>{dgettext("setup", "Endpoint")}</span></label>
              <input
                type="text"
                name="storage[endpoint]"
                value={@storage_form[:endpoint].value}
                class="glass-input input-sm"
                placeholder="https://s3.amazonaws.com"
              />
            </div>
            <div class="grid grid-cols-2 gap-3">
              <div class="form-control">
                <label class="glass-label mb-1"><span>{dgettext("setup", "Bucket")}</span></label>
                <input
                  type="text"
                  name="storage[bucket]"
                  value={@storage_form[:bucket].value}
                  class="glass-input input-sm"
                />
              </div>
              <div class="form-control">
                <label class="glass-label mb-1"><span>{dgettext("setup", "Region")}</span></label>
                <input
                  type="text"
                  name="storage[region]"
                  value={@storage_form[:region].value}
                  class="glass-input input-sm"
                  placeholder="us-east-1"
                />
              </div>
            </div>
            <div class="grid grid-cols-2 gap-3">
              <div class="form-control">
                <label class="glass-label mb-1"><span>{dgettext("setup", "Access Key")}</span></label>
                <input
                  type="text"
                  name="storage[access_key]"
                  value={@storage_form[:access_key].value}
                  class="glass-input input-sm"
                />
              </div>
              <div class="form-control">
                <label class="glass-label mb-1"><span>{dgettext("setup", "Secret Key")}</span></label>
                <input
                  type="password"
                  name="storage[secret_key]"
                  value={@storage_form[:secret_key].value}
                  class="glass-input input-sm"
                />
              </div>
            </div>
          </div>
        <% end %>

        <div class="card-actions justify-between mt-6">
          <button type="button" phx-click="prev_step" class="glass-btn glass-btn-ghost">
            ← {dgettext("default", "Back")}
          </button>
          <button type="submit" class="glass-btn glass-btn-primary">
            {dgettext("default", "Next")} →
          </button>
        </div>
      </.form>
    </div>
    """
  end

  defp summary_step(assigns) do
    ~H"""
    <div>
      <h3 class="text-lg font-semibold mb-4">{dgettext("setup", "Setup Complete!")}</h3>
      <div class="space-y-3">
        <div class="flex items-center gap-2">
          <span class="badge badge-success">✓</span>
          <span>{dgettext("setup", "Admin account created")}</span>
        </div>
        <div class="flex items-center gap-2">
          <span class="badge badge-success">✓</span>
          <span>
            {dgettext("setup", "%{count} AI provider(s) configured",
              count: map_size(@provider_configs)
            )}
          </span>
        </div>
        <div class="flex items-center gap-2">
          <span class="badge badge-success">✓</span>
          <span>
            {dgettext("setup", "Storage")}: {if @storage_type == "local",
              do: dgettext("setup", "Local Storage"),
              else: dgettext("setup", "S3 / MinIO")}
          </span>
        </div>
      </div>
      <div class="card-actions justify-end mt-6">
        <button type="button" phx-click="finish_setup" class="btn btn-primary btn-lg">
          {dgettext("setup", "Start Using AstraAutoEx")} →
        </button>
      </div>
    </div>
    """
  end

  defp field_errors(assigns) do
    ~H"""
    <%= for {msg, _opts} <- @field.errors do %>
      <label class="label"><span class="label-text-alt text-error">{msg}</span></label>
    <% end %>
    """
  end

  ## Event Handlers

  @impl true
  def handle_event("validate_admin", %{"user" => params}, socket) do
    changeset =
      %User{}
      |> User.registration_changeset(params, hash_password: false, validate_unique: false)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :admin_form, to_form(changeset, as: "user"))}
  end

  def handle_event("save_admin", %{"user" => params}, socket) do
    changeset =
      %User{}
      |> User.registration_changeset(params, hash_password: false, validate_unique: false)
      |> Map.put(:action, :validate)

    if changeset.valid? do
      {:noreply,
       socket
       |> assign(:admin_form, to_form(changeset, as: "user"))
       |> assign(:admin_params, params)
       |> assign(:step, :providers)}
    else
      {:noreply, assign(socket, :admin_form, to_form(changeset, as: "user"))}
    end
  end

  def handle_event("validate_provider", _params, socket) do
    {:noreply, socket}
  end

  def handle_event(
        "add_provider",
        %{"provider" => %{"provider" => name, "api_key" => key}},
        socket
      )
      when name != "" and key != "" do
    configs = Map.put(socket.assigns.provider_configs, name, %{"api_key" => key})
    selected = Map.keys(configs)

    {:noreply,
     socket
     |> assign(:provider_configs, configs)
     |> assign(:selected_providers, selected)
     |> assign(:provider_form, to_form(%{"provider" => "", "api_key" => ""}, as: "provider"))}
  end

  def handle_event("add_provider", _params, socket) do
    {:noreply,
     put_flash(
       socket,
       :error,
       dgettext("setup", "Please select a provider and enter an API key.")
     )}
  end

  def handle_event("remove_provider", %{"name" => name}, socket) do
    configs = Map.delete(socket.assigns.provider_configs, name)

    {:noreply,
     socket
     |> assign(:provider_configs, configs)
     |> assign(:selected_providers, Map.keys(configs))}
  end

  def handle_event("change_storage_type", %{"storage" => %{"type" => type} = params}, socket) do
    {:noreply,
     socket
     |> assign(:storage_type, type)
     |> assign(:storage_form, to_form(params, as: "storage"))}
  end

  def handle_event("save_storage", %{"storage" => params}, socket) do
    {:noreply,
     socket
     |> assign(:storage_config, params)
     |> assign(:step, :summary)}
  end

  def handle_event("next_step", _params, socket) do
    next = next_step(socket.assigns.step)
    {:noreply, assign(socket, :step, next)}
  end

  def handle_event("prev_step", _params, socket) do
    prev = prev_step(socket.assigns.step)
    {:noreply, assign(socket, :step, prev)}
  end

  def handle_event("finish_setup", _params, socket) do
    admin_params = socket.assigns.admin_params
    provider_configs = socket.assigns.provider_configs
    storage_config = Map.get(socket.assigns, :storage_config, %{"type" => "local"})

    preference_attrs = %{
      "provider_configs" => Jason.encode!(provider_configs),
      "storage_config" => storage_config
    }

    attrs = Map.put(admin_params, "preference", preference_attrs)

    case Accounts.register_admin(attrs) do
      {:ok, %{user: user}} ->
        token = Accounts.generate_user_session_token(user)

        {:noreply,
         socket
         |> put_flash(:info, dgettext("setup", "Welcome to AstraAutoEx!"))
         |> redirect(to: ~p"/users/log-in?_action=registered&token=#{Base.url_encode64(token)}")}

      {:error, :user, %Ecto.Changeset{} = changeset, _} ->
        {:noreply,
         socket
         |> assign(:step, :admin)
         |> assign(:admin_form, to_form(changeset, as: "user"))
         |> put_flash(
           :error,
           dgettext("setup", "Failed to create admin account. Please check the form.")
         )}

      {:error, _, _, _} ->
        {:noreply,
         put_flash(socket, :error, dgettext("setup", "Setup failed. Please try again."))}
    end
  end

  ## Helpers

  defp step_active?(current, target) do
    current_idx = Enum.find_index(@steps, &(&1 == current))
    target_idx = Enum.find_index(@steps, &(&1 == target))
    target_idx <= current_idx
  end

  defp next_step(:admin), do: :providers
  defp next_step(:providers), do: :storage
  defp next_step(:storage), do: :summary
  defp next_step(:summary), do: :summary

  defp prev_step(:providers), do: :admin
  defp prev_step(:storage), do: :providers
  defp prev_step(:summary), do: :storage
  defp prev_step(step), do: step

  defp available_providers(selected) do
    all_providers()
    |> Enum.reject(fn p -> p.id in selected end)
  end

  defp all_providers do
    [
      %{id: "fal", label: "FAL"},
      %{id: "ark", label: "ARK"},
      %{id: "google", label: "Google Official"},
      %{id: "minimax", label: "MiniMax"},
      %{id: "apiyi", label: "API Yi"},
      %{id: "runninghub", label: "RunningHub"}
    ]
  end

  defp provider_label(id) do
    case Enum.find(all_providers(), fn p -> p.id == id end) do
      nil -> id
      p -> p.label
    end
  end
end
