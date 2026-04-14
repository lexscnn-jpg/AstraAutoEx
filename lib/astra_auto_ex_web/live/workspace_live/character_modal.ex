defmodule AstraAutoExWeb.WorkspaceLive.CharacterModal do
  @moduledoc "Create/edit character modal with appearance management."
  use AstraAutoExWeb, :live_component

  alias AstraAutoEx.Characters

  @impl true
  def mount(socket) do
    {:ok, assign(socket, :mode, :create)}
  end

  @impl true
  def update(assigns, socket) do
    character = assigns[:character]
    mode = if character, do: :edit, else: :create

    profile = if character, do: character.profile_data || %{}, else: %{}

    form_data =
      if character do
        %{
          name: character.name,
          gender: profile["gender"] || "",
          age: profile["age"] || "",
          description: character.introduction || "",
          personality: profile["personality"] || ""
        }
      else
        %{name: "", gender: "", age: "", description: "", personality: ""}
      end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:mode, mode)
     |> assign(:form, to_form(form_data, as: "character"))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center">
      <div class="absolute inset-0 bg-black/70" phx-click="close_character_modal" />
      <div class="glass-card p-6 w-full max-w-lg relative z-10">
        <h2 class="text-lg font-bold text-[var(--glass-text-primary)] mb-4">
          {if @mode == :create,
            do: dgettext("projects", "Create Character"),
            else: dgettext("projects", "Edit Character")}
        </h2>

        <.form for={@form} phx-submit="save_character" phx-target={@myself} class="space-y-4">
          <div>
            <label class="text-xs text-[var(--glass-text-tertiary)] mb-1 block">
              {dgettext("projects", "Name")}
            </label>
            <input
              type="text"
              name="character[name]"
              value={@form[:name].value}
              class="glass-input w-full"
              required
              autofocus
            />
          </div>

          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="text-xs text-[var(--glass-text-tertiary)] mb-1 block">
                {dgettext("projects", "Gender")}
              </label>
              <select name="character[gender]" class="glass-input w-full">
                <option value="">—</option>
                <option value="male" selected={@form[:gender].value == "male"}>Male</option>
                <option value="female" selected={@form[:gender].value == "female"}>Female</option>
                <option value="other" selected={@form[:gender].value == "other"}>Other</option>
              </select>
            </div>
            <div>
              <label class="text-xs text-[var(--glass-text-tertiary)] mb-1 block">
                {dgettext("projects", "Age")}
              </label>
              <input
                type="text"
                name="character[age]"
                value={@form[:age].value}
                class="glass-input w-full"
                placeholder="25"
              />
            </div>
          </div>

          <div>
            <label class="text-xs text-[var(--glass-text-tertiary)] mb-1 block">
              {dgettext("projects", "Description")}
            </label>
            <textarea
              name="character[description]"
              class="glass-input w-full h-20 resize-none"
              placeholder="Physical appearance, clothing, distinctive features..."
            ><%= @form[:description].value %></textarea>
          </div>

          <div>
            <label class="text-xs text-[var(--glass-text-tertiary)] mb-1 block">
              {dgettext("projects", "Personality")}
            </label>
            <textarea
              name="character[personality]"
              class="glass-input w-full h-16 resize-none"
              placeholder="Personality traits, motivations, background..."
            ><%= @form[:personality].value %></textarea>
          </div>

          <div class="flex justify-end gap-2 pt-2">
            <button
              type="button"
              phx-click="close_character_modal"
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
  def handle_event("save_character", %{"character" => params}, socket) do
    project_id = socket.assigns.project_id

    # Map form fields to schema fields
    profile_data = %{
      "gender" => params["gender"],
      "age" => params["age"],
      "personality" => params["personality"]
    }

    attrs =
      params
      |> Map.put("introduction", params["description"])
      |> Map.put("profile_data", profile_data)
      |> Map.drop(["description", "gender", "age", "personality"])

    result =
      case socket.assigns.mode do
        :create ->
          Characters.create_character(Map.put(attrs, "project_id", project_id))

        :edit ->
          Characters.update_character(socket.assigns.character, attrs)
      end

    case result do
      {:ok, char} ->
        send(self(), {:character_saved, char})
        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, socket}
    end
  end
end
