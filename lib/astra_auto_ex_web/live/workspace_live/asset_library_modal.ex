defmodule AstraAutoExWeb.WorkspaceLive.AssetLibraryModal do
  @moduledoc "Unified asset library modal: characters, locations, props in one panel."
  use AstraAutoExWeb, :live_component

  alias AstraAutoEx.{Characters, Locations}

  @impl true
  def mount(socket) do
    {:ok, assign(socket, active_tab: :all, editing_character: nil)}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(assigns, socket) do
    {:ok, socket |> assign(assigns)}
  end

  # -------------------------------------------------------------------
  # Render
  # -------------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center">
      <div class="absolute inset-0 bg-black/60 backdrop-blur-sm" phx-click="close_asset_library" />

      <div class="relative z-10 bg-white rounded-2xl shadow-2xl w-full max-w-4xl max-h-[85vh] flex flex-col overflow-hidden">
        <%!-- Header --%>
        <div class="flex items-center justify-between px-6 py-4 border-b border-gray-100">
          <div class="flex items-center gap-2">
            <div class="w-2 h-2 rounded-full bg-blue-500" />
            <h2 class="text-lg font-bold text-gray-900">
              {dgettext("assets", "Asset Library")}
            </h2>
          </div>
          <button
            phx-click="close_asset_library"
            class="text-gray-400 hover:text-gray-600 transition-colors"
          >
            <svg
              class="w-5 h-5"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              viewBox="0 0 24 24"
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <%!-- Toolbar --%>
        <.toolbar
          characters={@characters}
          locations={@locations}
          myself={@myself}
        />

        <%!-- Tab filter --%>
        <.tab_bar
          active_tab={@active_tab}
          character_count={length(@characters)}
          location_count={length(@locations)}
          myself={@myself}
        />

        <%!-- Content area --%>
        <div class="flex-1 overflow-y-auto px-6 py-4 space-y-6">
          <.character_section
            :if={@active_tab in [:all, :characters]}
            characters={@characters}
            myself={@myself}
          />
          <.location_section
            :if={@active_tab in [:all, :locations]}
            locations={@locations}
            myself={@myself}
          />
          <.prop_section :if={@active_tab in [:all, :props]} />
        </div>
      </div>
    </div>
    """
  end

  # -------------------------------------------------------------------
  # Sub-components
  # -------------------------------------------------------------------

  defp toolbar(assigns) do
    total = length(assigns.characters) + length(assigns.locations)
    char_count = length(assigns.characters)
    loc_count = length(assigns.locations)

    assigns =
      assigns
      |> assign(:total, total)
      |> assign(:char_count, char_count)
      |> assign(:loc_count, loc_count)

    ~H"""
    <div class="px-6 py-3 border-b border-gray-100 flex flex-wrap items-center gap-3">
      <span class="text-sm font-medium text-gray-600">
        {dgettext("assets", "Asset Management")}
      </span>
      <span class="text-xs text-gray-400">|</span>
      <span class="text-xs text-gray-500">
        {dgettext(
          "assets",
          "Total %{total} assets (%{chars} characters + %{locs} locations + 0 props)",
          total: @total,
          chars: @char_count,
          locs: @loc_count
        )}
      </span>

      <div class="ml-auto flex items-center gap-2">
        <button
          phx-click="analyze_all_entities"
          class="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium text-blue-600 bg-blue-50 rounded-lg hover:bg-blue-100 transition-colors"
        >
          <svg
            class="w-3.5 h-3.5"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z"
            />
          </svg>
          {dgettext("assets", "Global Analyze")}
        </button>
        <button
          phx-click="generate_all_entity_images"
          class="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium text-white bg-blue-500 rounded-lg hover:bg-blue-600 transition-colors"
        >
          <svg
            class="w-3.5 h-3.5"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M2.25 15.75l5.159-5.159a2.25 2.25 0 013.182 0l5.159 5.159m-1.5-1.5l1.409-1.41a2.25 2.25 0 013.182 0l2.909 2.91M3.75 21h16.5"
            />
          </svg>
          {dgettext("assets", "Generate All Images")}
        </button>
      </div>
    </div>
    """
  end

  defp tab_bar(assigns) do
    total = assigns.character_count + assigns.location_count
    assigns = assign(assigns, :total, total)

    ~H"""
    <div class="px-6 pt-3 flex gap-1">
      <.tab_btn
        label={dgettext("assets", "All (%{count})", count: @total)}
        active={@active_tab == :all}
        tab={:all}
        myself={@myself}
      />
      <.tab_btn
        label={dgettext("assets", "Characters (%{count})", count: @character_count)}
        active={@active_tab == :characters}
        tab={:characters}
        myself={@myself}
      />
      <.tab_btn
        label={dgettext("assets", "Locations (%{count})", count: @location_count)}
        active={@active_tab == :locations}
        tab={:locations}
        myself={@myself}
      />
      <.tab_btn
        label={dgettext("assets", "Props (%{count})", count: 0)}
        active={@active_tab == :props}
        tab={:props}
        myself={@myself}
      />
    </div>
    """
  end

  defp tab_btn(assigns) do
    ~H"""
    <button
      phx-click="switch_asset_tab"
      phx-value-tab={@tab}
      phx-target={@myself}
      class={[
        "px-4 py-2 text-xs font-medium rounded-t-lg transition-colors",
        if(@active,
          do: "bg-blue-50 text-blue-600 border-b-2 border-blue-500",
          else: "text-gray-500 hover:text-gray-700 hover:bg-gray-50"
        )
      ]}
    >
      {@label}
    </button>
    """
  end

  # -------------------------------------------------------------------
  # Character section
  # -------------------------------------------------------------------

  defp character_section(assigns) do
    appearance_count =
      Enum.reduce(assigns.characters, 0, fn c, acc -> acc + length(c.appearances || []) end)

    unconfirmed = Enum.count(assigns.characters, fn c -> !c.profile_confirmed end)
    assigns = assign(assigns, appearance_count: appearance_count, unconfirmed: unconfirmed)

    ~H"""
    <div>
      <div class="flex items-center justify-between mb-3">
        <div class="flex items-center gap-2">
          <span class="text-base">&#x1f9d1;</span>
          <h3 class="text-sm font-bold text-gray-800">
            {dgettext("assets", "Character Assets")}
          </h3>
          <span class="text-xs text-gray-400">
            {dgettext("assets", "%{character_count} characters, %{appearance_count} appearances",
              character_count: length(@characters),
              appearance_count: @appearance_count
            )}
          </span>
        </div>
        <button
          phx-click="add_character_from_library"
          phx-target={@myself}
          class="inline-flex items-center gap-1 px-3 py-1.5 text-xs font-medium text-blue-600 bg-blue-50 rounded-lg hover:bg-blue-100 transition-colors"
        >
          + {dgettext("assets", "Add Character")}
        </button>
      </div>

      <%!-- AI casting hint --%>
      <div
        :if={@unconfirmed > 0}
        class="flex items-center justify-between mb-3 px-3 py-2 bg-amber-50 rounded-lg"
      >
        <span class="text-xs text-amber-700">
          {dgettext("assets", "AI Casting Complete")} &mdash; {dgettext(
            "assets",
            "Confirm profiles to auto-generate appearances"
          )}
        </span>
        <button
          phx-click="confirm_all_characters"
          phx-target={@myself}
          class="px-3 py-1 text-xs font-medium text-amber-700 bg-amber-100 rounded-lg hover:bg-amber-200 transition-colors"
        >
          {dgettext("assets", "Confirm All (%{count})", count: @unconfirmed)}
        </button>
      </div>

      <%= if Enum.empty?(@characters) do %>
        <div class="text-center py-8 text-sm text-gray-400">
          {dgettext("assets", "No Characters")}
        </div>
      <% else %>
        <div class="space-y-3">
          <.character_card :for={char <- @characters} character={char} myself={@myself} />
        </div>
      <% end %>
    </div>
    """
  end

  defp character_card(assigns) do
    profile = assigns.character.profile_data || %{}
    first_img = first_appearance_image(assigns.character)

    assigns =
      assigns
      |> assign(:profile, profile)
      |> assign(:first_img, first_img)
      |> assign(:role_level, profile["role_level"] || profile["importance_level"])

    ~H"""
    <div class="flex gap-4 p-4 bg-gray-50 rounded-xl border border-gray-100 hover:border-blue-200 transition-colors">
      <div class="flex-1 min-w-0">
        <div class="flex items-center gap-2 mb-2">
          <span class="text-sm font-bold text-gray-800 truncate">{@character.name}</span>
          <.delete_btn
            event="delete_character_from_library"
            id={@character.id}
            myself={@myself}
            confirm={dgettext("assets", "Delete character confirm")}
          />
        </div>
        <div :if={@role_level} class="flex items-center gap-2 mb-2">
          <.role_badge level={@role_level} />
          <span :if={@profile["archetype"]} class="text-xs text-gray-500">
            {@profile["archetype"]}
          </span>
        </div>
        <div class="grid grid-cols-2 gap-x-4 gap-y-1 text-xs text-gray-500">
          <.pf :if={@profile["gender"]} l={dgettext("assets", "Gender")} v={@profile["gender"]} />
          <.pf :if={@profile["age"]} l={dgettext("assets", "Age")} v={@profile["age"]} />
          <.pf :if={@profile["era"]} l={dgettext("assets", "Era")} v={@profile["era"]} />
          <.pf
            :if={@profile["social_class"]}
            l={dgettext("assets", "Social Class")}
            v={@profile["social_class"]}
          />
          <.pf
            :if={@profile["occupation"]}
            l={dgettext("assets", "Occupation")}
            v={@profile["occupation"]}
          />
        </div>
      </div>
      <.thumb src={@first_img} alt={@character.name} icon="person" />
    </div>
    """
  end

  defp role_badge(assigns) do
    {bg, text} = role_level_colors(assigns.level)
    assigns = assign(assigns, bg: bg, text: text, label: role_level_label(assigns.level))

    ~H"""
    <span class={"inline-flex items-center px-2 py-0.5 rounded text-xs font-semibold #{@bg} #{@text}"}>
      {@label}
    </span>
    """
  end

  defp pf(assigns) do
    ~H"""
    <div class="flex items-center gap-1">
      <span class="text-gray-400">{@l}:</span><span class="text-gray-600">{@v}</span>
    </div>
    """
  end

  # -------------------------------------------------------------------
  # Location section
  # -------------------------------------------------------------------

  defp location_section(assigns) do
    ~H"""
    <div>
      <div class="flex items-center justify-between mb-3">
        <div class="flex items-center gap-2">
          <span class="text-base">&#x1f3e0;</span>
          <h3 class="text-sm font-bold text-gray-800">
            {dgettext("assets", "Location Assets")}
          </h3>
          <span class="text-xs text-gray-400">
            {dgettext("assets", "%{count} locations", count: length(@locations))}
          </span>
        </div>
        <button
          phx-click="add_location_from_library"
          phx-target={@myself}
          class="inline-flex items-center gap-1 px-3 py-1.5 text-xs font-medium text-blue-600 bg-blue-50 rounded-lg hover:bg-blue-100 transition-colors"
        >
          + {dgettext("assets", "Add Location")}
        </button>
      </div>

      <%= if Enum.empty?(@locations) do %>
        <div class="text-center py-8 text-sm text-gray-400">
          {dgettext("assets", "No Locations")}
        </div>
      <% else %>
        <div class="space-y-3">
          <.location_card :for={loc <- @locations} location={loc} myself={@myself} />
        </div>
      <% end %>
    </div>
    """
  end

  defp location_card(assigns) do
    first_img = first_location_image(assigns.location)
    assigns = assign(assigns, :first_img, first_img)

    ~H"""
    <div class="flex gap-4 p-4 bg-gray-50 rounded-xl border border-gray-100 hover:border-blue-200 transition-colors">
      <div class="flex-1 min-w-0">
        <div class="flex items-center gap-2 mb-1">
          <span class="text-sm font-bold text-gray-800 truncate">{@location.name}</span>
          <.delete_btn
            event="delete_location_from_library"
            id={@location.id}
            myself={@myself}
            confirm={dgettext("assets", "Delete location confirm")}
          />
        </div>
        <p :if={@location.summary} class="text-xs text-gray-500 line-clamp-2">{@location.summary}</p>
      </div>
      <.thumb src={@first_img} alt={@location.name} icon="building" />
    </div>
    """
  end

  # -------------------------------------------------------------------
  # Prop section (placeholder)
  # -------------------------------------------------------------------

  defp prop_section(assigns) do
    ~H"""
    <div>
      <div class="flex items-center gap-2 mb-3">
        <span class="text-base">&#x1f3af;</span>
        <h3 class="text-sm font-bold text-gray-800">
          {dgettext("assets", "Prop Assets")}
        </h3>
        <span class="text-xs text-gray-400">
          {dgettext("assets", "%{count} props", count: 0)}
        </span>
      </div>
      <div class="text-center py-8 text-sm text-gray-400">
        {dgettext("assets", "Coming soon")}
      </div>
    </div>
    """
  end

  # -------------------------------------------------------------------
  # Shared sub-components
  # -------------------------------------------------------------------

  defp delete_btn(assigns) do
    ~H"""
    <button
      phx-click={@event}
      phx-value-id={@id}
      phx-target={@myself}
      data-confirm={@confirm}
      class="text-gray-300 hover:text-red-400 transition-colors ml-auto"
    >
      <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916"
        />
      </svg>
    </button>
    """
  end

  defp thumb(assigns) do
    ~H"""
    <div class="w-24 h-24 flex-shrink-0 rounded-lg overflow-hidden bg-gray-200 flex items-center justify-center">
      <%= if @src do %>
        <img src={@src} alt={@alt} class="w-full h-full object-cover" />
      <% else %>
        <svg
          class="w-8 h-8 text-gray-300"
          fill="none"
          stroke="currentColor"
          stroke-width="1.5"
          viewBox="0 0 24 24"
        >
          <%= if @icon == "person" do %>
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0"
            />
          <% else %>
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M2.25 21h19.5M3.75 3v18m16.5-18v18M5.625 7.5h.008v.008h-.008V7.5zm0 3h.008v.008h-.008v-.008zm0 3h.008v.008h-.008v-.008z"
            />
          <% end %>
        </svg>
      <% end %>
    </div>
    """
  end

  # -------------------------------------------------------------------
  # Events
  # -------------------------------------------------------------------

  @impl true
  def handle_event("switch_asset_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, String.to_existing_atom(tab))}
  end

  def handle_event("add_character_from_library", _, socket) do
    send(self(), :open_character_modal)
    {:noreply, socket}
  end

  def handle_event("add_location_from_library", _, socket) do
    send(self(), :open_location_modal)
    {:noreply, socket}
  end

  def handle_event("delete_character_from_library", %{"id" => id}, socket) do
    char = Characters.get_character!(id)
    Characters.delete_character(char)
    send(self(), :reload_characters)
    {:noreply, socket}
  end

  def handle_event("delete_location_from_library", %{"id" => id}, socket) do
    loc = Locations.get_location!(id)
    Locations.delete_location(loc)
    send(self(), :reload_locations)
    {:noreply, socket}
  end

  def handle_event("confirm_all_characters", _, socket) do
    Enum.each(socket.assigns.characters, fn char ->
      unless char.profile_confirmed do
        Characters.update_character(char, %{profile_confirmed: true})
      end
    end)

    send(self(), :reload_characters)
    {:noreply, socket}
  end

  # -------------------------------------------------------------------
  # Helpers
  # -------------------------------------------------------------------

  @spec first_appearance_image(map()) :: String.t() | nil
  defp first_appearance_image(%{appearances: appearances}) when is_list(appearances) do
    case appearances do
      [first | _] -> first.image_url
      _ -> nil
    end
  end

  defp first_appearance_image(_), do: nil

  @spec first_location_image(map()) :: String.t() | nil
  defp first_location_image(%{images: images}) when is_list(images) do
    case images do
      [first | _] -> first.image_url
      _ -> nil
    end
  end

  defp first_location_image(_), do: nil

  @spec role_level_colors(String.t() | nil) :: {String.t(), String.t()}
  defp role_level_colors("S"), do: {"bg-red-100", "text-red-700"}
  defp role_level_colors("A"), do: {"bg-orange-100", "text-orange-700"}
  defp role_level_colors("B"), do: {"bg-yellow-100", "text-yellow-700"}
  defp role_level_colors("C"), do: {"bg-green-100", "text-green-700"}
  defp role_level_colors("D"), do: {"bg-gray-100", "text-gray-600"}
  defp role_level_colors(_), do: {"bg-gray-100", "text-gray-600"}

  @spec role_level_label(String.t() | nil) :: String.t()
  defp role_level_label("S"), do: dgettext("assets", "Importance S")
  defp role_level_label("A"), do: dgettext("assets", "Importance A")
  defp role_level_label("B"), do: dgettext("assets", "Importance B")
  defp role_level_label("C"), do: dgettext("assets", "Importance C")
  defp role_level_label("D"), do: dgettext("assets", "Importance D")
  defp role_level_label(_), do: ""
end
