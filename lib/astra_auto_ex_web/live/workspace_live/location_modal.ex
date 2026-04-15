defmodule AstraAutoExWeb.WorkspaceLive.LocationModal do
  @moduledoc "Create/edit location modal."
  use AstraAutoExWeb, :live_component

  alias AstraAutoEx.Locations

  @impl true
  def update(assigns, socket) do
    location = assigns[:location]
    mode = if location, do: :edit, else: :create

    form_data =
      if location do
        %{name: location.name, description: location.summary || ""}
      else
        %{name: "", description: ""}
      end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:mode, mode)
     |> assign(:form, to_form(form_data, as: "location"))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center">
      <div class="absolute inset-0 bg-black/70" phx-click="close_location_modal" />
      <div class="glass-card p-6 w-full max-w-lg relative z-10">
        <h2 class="text-lg font-bold text-[var(--glass-text-primary)] mb-4">
          {if @mode == :create,
            do: dgettext("projects", "Create Location"),
            else: dgettext("projects", "Edit Location")}
        </h2>

        <.form for={@form} phx-submit="save_location" phx-target={@myself} class="space-y-4">
          <div>
            <label class="text-xs text-[var(--glass-text-tertiary)] mb-1 block">
              {dgettext("projects", "Name")}
            </label>
            <input
              type="text"
              name="location[name]"
              value={@form[:name].value}
              class="glass-input w-full"
              required
              autofocus
            />
          </div>

          <div>
            <label class="text-xs text-[var(--glass-text-tertiary)] mb-1 block">
              {dgettext("projects", "Description")}
            </label>
            <textarea
              name="location[description]"
              class="glass-input w-full h-24 resize-none"
              placeholder="Scene description, atmosphere, lighting, colors..."
            ><%= @form[:description].value %></textarea>
          </div>

          <div class="flex justify-end gap-2 pt-2">
            <button
              type="button"
              phx-click="close_location_modal"
              class="px-4 py-2 text-sm text-[var(--glass-text-tertiary)] hover:text-[var(--glass-text-primary)]"
            >
              {dgettext("default", "Cancel")}
            </button>
            <button type="submit" class="glass-btn glass-btn-primary px-6 py-2 text-sm">
              {if @mode == :create,
                do: dgettext("projects", "Create"),
                else: dgettext("default", "Save")}
            </button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("save_location", %{"location" => params}, socket) do
    project_id = socket.assigns.project_id

    result =
      case socket.assigns.mode do
        :create ->
          Locations.create_location(Map.put(params, "project_id", project_id))

        :edit ->
          Locations.update_location(socket.assigns.location, params)
      end

    case result do
      {:ok, loc} ->
        send(self(), {:location_saved, loc})
        {:noreply, socket}

      {:error, _} ->
        {:noreply, socket}
    end
  end
end
