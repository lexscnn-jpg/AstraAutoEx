defmodule AstraAutoExWeb.AssetHubLive.Index do
  @moduledoc "Asset Hub — manage characters, locations, props, voices, SFX, BGM across projects."
  use AstraAutoExWeb, :live_view
  alias AstraAutoEx.AssetHub

  @tabs ~w(all characters locations props voices sfx bgm)

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    {:ok,
     socket
     |> assign(:tab, "all")
     |> assign(:scope, "global")
     |> assign(:characters, AssetHub.list_global_characters(user.id))
     |> assign(:locations, AssetHub.list_global_locations(user.id))
     |> assign(:voices, AssetHub.list_global_voices(user.id))
     |> assign(:props, [])
     |> assign(:sfx, [])
     |> assign(:bgm, [])
     |> assign(:search, "")
     |> assign(:page_title, dgettext("projects", "Asset Hub"))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="container mx-auto px-4 py-6">
        <%!-- Header --%>
        <div class="mb-5">
          <h1 class="text-2xl font-bold text-[var(--glass-text-primary)]">
            {dgettext("projects", "Asset Hub")}
          </h1>
          <p class="text-sm text-[var(--glass-text-tertiary)] mt-1">
            {dgettext("projects", "Manage your global characters, locations, and media assets.")}
          </p>
          <p class="text-xs text-[var(--glass-text-tertiary)] mt-1 flex items-center gap-1">
            <svg
              class="w-3.5 h-3.5"
              fill="none"
              stroke="currentColor"
              stroke-width="1.5"
              viewBox="0 0 24 24"
            >
              <circle cx="12" cy="12" r="10" /><path d="M12 16v-4" /><path d="M12 8h.01" />
            </svg>
            {dgettext(
              "projects",
              "Assets use default models. To change, go to"
            )}
            <a href={~p"/profile"} class="text-[var(--glass-accent-from)] hover:underline">
              {dgettext("default", "Settings")}
            </a>
          </p>
        </div>

        <div class="flex gap-5">
          <%!-- Left sidebar: Folders --%>
          <aside class="w-52 flex-shrink-0">
            <div class="glass-surface rounded-xl p-4">
              <div class="flex items-center justify-between mb-3">
                <span class="text-sm font-semibold text-[var(--glass-text-primary)]">
                  {dgettext("projects", "Folders")}
                </span>
                <button class="w-6 h-6 rounded-full bg-[var(--glass-accent-from)] text-white flex items-center justify-center text-xs hover:opacity-80 transition-opacity">
                  +
                </button>
              </div>

              <div class="space-y-1">
                <button
                  phx-click="set_scope"
                  phx-value-scope="global"
                  class={[
                    "w-full flex items-center gap-2 px-3 py-2 rounded-lg text-sm transition-all text-left",
                    if(@scope == "global",
                      do:
                        "bg-[var(--glass-accent-from)]/10 text-[var(--glass-accent-from)] font-medium",
                      else: "text-[var(--glass-text-secondary)] hover:bg-[var(--glass-bg-muted)]"
                    )
                  ]}
                >
                  <svg
                    class="w-4 h-4"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="1.5"
                    viewBox="0 0 24 24"
                  >
                    <path d="M22 19a2 2 0 01-2 2H4a2 2 0 01-2-2V5a2 2 0 012-2h5l2 3h9a2 2 0 012 2z" />
                  </svg>
                  {dgettext("projects", "All Assets")}
                </button>
                <button
                  phx-click="set_scope"
                  phx-value-scope="project"
                  class={[
                    "w-full flex items-center gap-2 px-3 py-2 rounded-lg text-sm transition-all text-left",
                    if(@scope == "project",
                      do:
                        "bg-[var(--glass-accent-from)]/10 text-[var(--glass-accent-from)] font-medium",
                      else: "text-[var(--glass-text-secondary)] hover:bg-[var(--glass-bg-muted)]"
                    )
                  ]}
                >
                  <svg
                    class="w-4 h-4"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="1.5"
                    viewBox="0 0 24 24"
                  >
                    <rect x="2" y="3" width="20" height="14" rx="2" /><path d="M8 21h8" /><path d="M12 17v4" />
                  </svg>
                  {dgettext("projects", "Project Assets")}
                </button>
              </div>

              <p class="text-[10px] text-[var(--glass-text-tertiary)] mt-3 opacity-60">
                {dgettext("projects", "No folders yet")}
              </p>
            </div>
          </aside>

          <%!-- Main content --%>
          <div class="flex-1 min-w-0">
            <%!-- Top bar: tabs + actions --%>
            <div class="flex items-center justify-between mb-4">
              <div class="flex gap-1 p-1 rounded-xl bg-[var(--glass-bg-muted)]">
                <%= for tab <- ~w(all characters locations props voices sfx bgm) do %>
                  <button
                    phx-click="switch_tab"
                    phx-value-tab={tab}
                    class={[
                      "px-3 py-1.5 rounded-lg text-xs font-medium transition-all",
                      if(@tab == tab,
                        do: "bg-white shadow-sm text-[var(--glass-text-primary)]",
                        else:
                          "text-[var(--glass-text-tertiary)] hover:text-[var(--glass-text-primary)]"
                      )
                    ]}
                  >
                    {tab_label(tab)}
                  </button>
                <% end %>
              </div>

              <div class="flex items-center gap-2">
                <input
                  type="text"
                  phx-change="search"
                  phx-debounce="300"
                  name="search"
                  value={@search}
                  placeholder={dgettext("projects", "Search assets...")}
                  class="glass-input px-3 py-1.5 text-xs w-40"
                />
                <button class="glass-btn glass-btn-ghost text-xs py-1.5 px-3 flex items-center gap-1">
                  <svg
                    class="w-3.5 h-3.5"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="1.5"
                    viewBox="0 0 24 24"
                  >
                    <path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4" /><polyline points="7 10 12 15 17 10" /><line
                      x1="12"
                      y1="15"
                      x2="12"
                      y2="3"
                    />
                  </svg>
                  {dgettext("projects", "Export")}
                </button>
                <button
                  phx-click="create_asset"
                  class="glass-btn glass-btn-primary text-xs py-1.5 px-4 flex items-center gap-1"
                >
                  + {dgettext("projects", "New Asset")}
                </button>
              </div>
            </div>

            <%!-- Asset grid --%>
            <div class="glass-surface rounded-xl p-6 min-h-[400px]">
              <%= if all_items_for_tab(@tab, assigns) == [] do %>
                <div class="text-center py-16">
                  <div class="text-4xl text-[var(--glass-text-tertiary)] opacity-30 mb-4">+</div>
                  <p class="text-sm font-medium text-[var(--glass-text-secondary)] mb-1">
                    {dgettext("projects", "No assets yet")}
                  </p>
                  <p class="text-xs text-[var(--glass-text-tertiary)] mb-5">
                    {dgettext("projects", "Click the button above to add characters or scenes.")}
                  </p>
                  <button
                    phx-click="create_asset"
                    class="glass-btn glass-btn-primary text-sm py-2 px-5 inline-flex items-center gap-1"
                  >
                    + {dgettext("projects", "New Asset")}
                  </button>
                </div>
              <% else %>
                <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-4">
                  <%= for item <- all_items_for_tab(@tab, assigns) do %>
                    <.asset_card item={item} />
                  <% end %>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp asset_card(assigns) do
    ~H"""
    <div class="glass-card overflow-hidden group cursor-pointer hover:shadow-lg transition-all">
      <div class="aspect-square bg-[var(--glass-bg-muted)] flex items-center justify-center relative">
        <%= cond do %>
          <% Map.get(@item, :image_url) && Map.get(@item, :image_url) != "" -> %>
            <img src={@item.image_url} class="w-full h-full object-cover" />
          <% Map.get(@item, :type) in ["sfx", "bgm"] -> %>
            <svg
              class="w-10 h-10 text-[var(--glass-text-tertiary)] opacity-40"
              fill="none"
              stroke="currentColor"
              stroke-width="1.5"
              viewBox="0 0 24 24"
            >
              <path d="M9 18V5l12-2v13" /><circle cx="6" cy="18" r="3" /><circle
                cx="18"
                cy="16"
                r="3"
              />
            </svg>
          <% true -> %>
            <span class="text-3xl text-[var(--glass-text-tertiary)] opacity-30">
              {String.first(Map.get(@item, :name, "?") || "?")}
            </span>
        <% end %>
        <span class="absolute top-2 right-2 glass-chip text-[10px] bg-black/40 text-white">
          {Map.get(@item, :type, "asset")}
        </span>
      </div>
      <div class="p-3">
        <h3 class="text-sm font-medium text-[var(--glass-text-primary)] truncate">
          {Map.get(@item, :name, "")}
        </h3>
        <p class="text-xs text-[var(--glass-text-tertiary)] mt-0.5 line-clamp-1">
          {Map.get(@item, :description, "") || Map.get(@item, :introduction, "") || ""}
        </p>
      </div>
    </div>
    """
  end

  # ── Events ──

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) when tab in @tabs do
    {:noreply, assign(socket, :tab, tab)}
  end

  def handle_event("set_scope", %{"scope" => scope}, socket) when scope in ~w(global project) do
    {:noreply, assign(socket, :scope, scope)}
  end

  def handle_event("search", %{"search" => search}, socket) do
    {:noreply, assign(socket, :search, search)}
  end

  def handle_event("create_asset", _, socket) do
    {:noreply,
     put_flash(socket, :info, dgettext("projects", "Asset creation dialog coming soon."))}
  end

  # ── Helpers ──

  defp tab_label("all"), do: dgettext("projects", "All Assets")
  defp tab_label("characters"), do: dgettext("projects", "Characters")
  defp tab_label("locations"), do: dgettext("projects", "Locations")
  defp tab_label("props"), do: dgettext("projects", "Props")
  defp tab_label("voices"), do: dgettext("projects", "Voices")
  defp tab_label("sfx"), do: dgettext("projects", "SFX")
  defp tab_label("bgm"), do: dgettext("projects", "BGM")

  defp all_items_for_tab(tab, assigns) do
    items =
      case tab do
        "all" ->
          tag_items(assigns.characters, "character") ++
            tag_items(assigns.locations, "location") ++
            tag_items(assigns.props, "prop") ++
            tag_items(assigns.voices, "voice") ++
            tag_items(assigns.sfx, "sfx") ++
            tag_items(assigns.bgm, "bgm")

        "characters" ->
          tag_items(assigns.characters, "character")

        "locations" ->
          tag_items(assigns.locations, "location")

        "props" ->
          tag_items(assigns.props, "prop")

        "voices" ->
          tag_items(assigns.voices, "voice")

        "sfx" ->
          tag_items(assigns.sfx, "sfx")

        "bgm" ->
          tag_items(assigns.bgm, "bgm")
      end

    filter_items(items, assigns.search)
  end

  defp tag_items(items, type) do
    Enum.map(items, fn item -> Map.put(item, :type, type) end)
  end

  defp filter_items(items, ""), do: items

  defp filter_items(items, search) do
    term = String.downcase(search)

    Enum.filter(items, fn item ->
      name = Map.get(item, :name, "") || ""
      desc = Map.get(item, :description, "") || Map.get(item, :introduction, "") || ""

      String.contains?(String.downcase(name), term) or
        String.contains?(String.downcase(desc), term)
    end)
  end
end
