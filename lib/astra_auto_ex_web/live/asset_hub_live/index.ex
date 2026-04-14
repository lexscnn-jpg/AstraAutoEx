defmodule AstraAutoExWeb.AssetHubLive.Index do
  @moduledoc "Asset Hub — manage characters, locations, props, voices, SFX, BGM across projects."
  use AstraAutoExWeb, :live_view
  alias AstraAutoEx.{AssetHub, Projects, Characters, Locations}

  @tabs ~w(all characters locations props voices sfx bgm)

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    {:ok,
     socket
     |> assign(:tab, "all")
     |> assign(:scope, "global")
     |> assign(:user_projects, Projects.list_projects(user.id))
     |> assign(:selected_project_id, nil)
     |> assign(:project_characters, [])
     |> assign(:project_locations, [])
     |> assign(:characters, AssetHub.list_global_characters(user.id))
     |> assign(:locations, AssetHub.list_global_locations(user.id))
     |> assign(:voices, AssetHub.list_global_voices(user.id))
     |> assign(:props, AssetHub.list_global_props(user.id))
     |> assign(:sfx, AssetHub.list_global_sfx(user.id))
     |> assign(:bgm, AssetHub.list_global_bgm(user.id))
     |> assign(:show_asset_form, false)
     |> assign(:asset_form_type, "character")
     |> assign(:editing_asset, nil)
     |> assign(:confirm_delete_id, nil)
     |> assign(:confirm_delete_type, nil)
     |> assign(:search, "")
     |> assign(:detail_asset, nil)
     |> assign(:detail_type, nil)
     |> assign(:generating_ids, MapSet.new())
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
          <%!-- Left sidebar: Scope + Projects --%>
          <aside class="w-52 flex-shrink-0 hidden lg:block space-y-3">
            <div class="glass-surface rounded-xl p-4">
              <div class="flex items-center justify-between mb-3">
                <span class="text-sm font-semibold text-[var(--glass-text-primary)]">
                  {dgettext("projects", "Scope")}
                </span>
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
                  {dgettext("projects", "Global Assets")}
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
            </div>

            <%!-- Project list (shown when scope=project) --%>
            <div :if={@scope == "project"} class="glass-surface rounded-xl p-4">
              <div class="flex items-center justify-between mb-3">
                <span class="text-xs font-semibold text-[var(--glass-text-primary)]">
                  {dgettext("projects", "My Projects")}
                </span>
                <span class="text-[10px] text-[var(--glass-text-tertiary)]">
                  {length(@user_projects)}
                </span>
              </div>

              <%= if @user_projects == [] do %>
                <p class="text-[10px] text-[var(--glass-text-tertiary)] opacity-60">
                  {dgettext("projects", "No projects yet. Create one from the workspace.")}
                </p>
              <% else %>
                <div class="space-y-0.5 max-h-[320px] overflow-y-auto">
                  <%= for project <- @user_projects do %>
                    <button
                      phx-click="select_project"
                      phx-value-id={project.id}
                      class={[
                        "w-full flex items-center gap-2 px-2.5 py-2 rounded-lg text-xs transition-all text-left",
                        if(to_string(@selected_project_id) == to_string(project.id),
                          do:
                            "bg-[var(--glass-accent-from)]/10 text-[var(--glass-accent-from)] font-medium",
                          else: "text-[var(--glass-text-secondary)] hover:bg-[var(--glass-bg-muted)]"
                        )
                      ]}
                    >
                      <svg
                        class="w-3.5 h-3.5 flex-shrink-0"
                        fill="none"
                        stroke="currentColor"
                        stroke-width="1.5"
                        viewBox="0 0 24 24"
                      >
                        <path d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z" />
                      </svg>
                      <span class="truncate">{project.name}</span>
                    </button>
                  <% end %>
                </div>
              <% end %>
            </div>
          </aside>
          <%!-- Main content --%>
          <div class="flex-1 min-w-0">
            <%!-- Top bar: tabs + actions --%>
            <div class="flex items-center justify-between mb-4 flex-wrap gap-2">
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
                    <span class="ml-1 text-[10px] opacity-50">{tab_count(tab, assigns)}</span>
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
                <button
                  phx-click="generate_all"
                  class="glass-btn glass-btn-ghost text-xs py-1.5 px-3 flex items-center gap-1"
                  title="为当前标签页所有无图资产批量生成"
                >
                  <svg
                    class="w-3.5 h-3.5"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="1.5"
                    viewBox="0 0 24 24"
                  >
                    <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z" />
                  </svg>
                  全部生成
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
                    <.asset_card
                      item={item}
                      generating={MapSet.member?(@generating_ids, item.id)}
                    />
                  <% end %>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>
      <%!-- Asset Form Modal --%>
      <.live_component
        :if={@show_asset_form}
        module={AstraAutoExWeb.AssetHubLive.AssetForm}
        id="asset-form"
        asset_type={@asset_form_type}
        editing={@editing_asset}
        user_id={@current_scope.user.id}
      /> <%!-- Asset Detail Panel --%>
      <.live_component
        :if={@detail_asset != nil}
        module={AstraAutoExWeb.AssetHubLive.AssetDetail}
        id="asset-detail"
        asset={@detail_asset}
        asset_type={@detail_type}
        user_id={@current_scope.user.id}
      /> <%!-- Delete Confirmation --%>
      <%= if @confirm_delete_id do %>
        <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm">
          <div class="glass-card p-6 max-w-sm mx-4">
            <h3 class="text-lg font-semibold text-[var(--glass-text-primary)] mb-2">确认删除</h3>

            <p class="text-sm text-[var(--glass-text-secondary)] mb-4">确定要删除此资产吗？此操作不可撤销。</p>

            <div class="flex justify-end gap-3">
              <button phx-click="cancel_delete" class="glass-btn px-4 py-2 text-sm">取消</button>
              <button
                phx-click="confirm_delete"
                class="px-4 py-2 text-sm bg-red-500/20 text-red-400 rounded-lg hover:bg-red-500/30"
              >
                删除
              </button>
            </div>
          </div>
        </div>
      <% end %>
    </Layouts.app>
    """
  end

  # ── Asset Card Component ──

  defp asset_card(assigns) do
    ~H"""
    <div
      class="glass-card overflow-hidden group cursor-pointer hover:shadow-lg transition-all relative"
      phx-click="open_detail"
      phx-value-id={@item.id}
      phx-value-type={@item.type}
    >
      <div class="aspect-square bg-[var(--glass-bg-muted)] flex items-center justify-center relative overflow-hidden">
        <%= cond do %>
          <% has_image?(@item) -> %>
            <img src={get_image(@item)} class="w-full h-full object-cover" />
          <% @item.type in ["sfx", "bgm"] -> %>
            <div class="flex flex-col items-center gap-1">
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
              <%= if Map.get(@item, :audio_url) do %>
                <span class="text-[9px] text-green-400 bg-green-500/20 px-1.5 py-0.5 rounded">
                  已生成
                </span>
              <% end %>
            </div>
          <% @item.type == "voice" -> %>
            <svg
              class="w-10 h-10 text-[var(--glass-text-tertiary)] opacity-40"
              fill="none"
              stroke="currentColor"
              stroke-width="1.5"
              viewBox="0 0 24 24"
            >
              <path d="M12 1a3 3 0 00-3 3v8a3 3 0 006 0V4a3 3 0 00-3-3z" /><path d="M19 10v2a7 7 0 01-14 0v-2" /><line
                x1="12"
                y1="19"
                x2="12"
                y2="23"
              /><line x1="8" y1="23" x2="16" y2="23" />
            </svg>
          <% true -> %>
            <span class="text-3xl text-[var(--glass-text-tertiary)] opacity-30">
              {String.first(Map.get(@item, :name, "?") || "?")}
            </span>
        <% end %>
        <%!-- Type badge --%>
        <span class={"absolute top-2 left-2 text-[10px] px-1.5 py-0.5 rounded font-medium #{type_badge(@item.type)}"}>
          {type_label_short(@item.type)}
        </span>
        <%!-- Generating spinner overlay --%>
        <div :if={@generating} class="absolute inset-0 bg-black/50 flex items-center justify-center">
          <div class="w-6 h-6 border-2 border-[var(--glass-accent-from)] border-t-transparent rounded-full animate-spin" />
        </div>
        <%!-- Hover action overlay --%>
        <div class="absolute inset-0 bg-black/0 group-hover:bg-black/40 transition-all flex items-end justify-center pb-2 opacity-0 group-hover:opacity-100">
          <div class="flex gap-1" phx-click-away="noop">
            <%= if @item.type in ["character", "location", "prop"] do %>
              <button
                phx-click="quick_generate"
                phx-value-id={@item.id}
                phx-value-type={@item.type}
                class="bg-white/90 text-gray-800 text-[10px] px-2 py-1 rounded hover:bg-white transition-colors"
                title={if has_image?(@item), do: "重新生成", else: "生成参考图"}
              >
                <svg
                  class="w-3 h-3 inline"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  viewBox="0 0 24 24"
                >
                  <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z" />
                </svg>
              </button>
            <% end %>

            <button
              phx-click="edit_from_card"
              phx-value-id={@item.id}
              phx-value-type={@item.type}
              class="bg-white/90 text-gray-800 text-[10px] px-2 py-1 rounded hover:bg-white transition-colors"
              title="编辑"
            >
              <svg
                class="w-3 h-3 inline"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                viewBox="0 0 24 24"
              >
                <path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7" />
                <path d="M18.5 2.5a2.121 2.121 0 013 3L12 15l-4 1 1-4 9.5-9.5z" />
              </svg>
            </button>
            <button
              phx-click="delete_asset"
              phx-value-id={@item.id}
              phx-value-type={@item.type}
              class="bg-red-500/80 text-white text-[10px] px-2 py-1 rounded hover:bg-red-500 transition-colors"
              title="删除"
            >
              <svg
                class="w-3 h-3 inline"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                viewBox="0 0 24 24"
              >
                <path d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
              </svg>
            </button>
          </div>
        </div>
      </div>

      <div class="p-3">
        <h3 class="text-sm font-medium text-[var(--glass-text-primary)] truncate">
          {Map.get(@item, :name, "")}
        </h3>

        <p class="text-xs text-[var(--glass-text-tertiary)] mt-0.5 line-clamp-1">
          {Map.get(@item, :description, "") || Map.get(@item, :introduction, "") ||
            Map.get(@item, :summary, "") || ""}
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

  def handle_event("set_scope", %{"scope" => "global"}, socket) do
    {:noreply,
     socket
     |> assign(:scope, "global")
     |> assign(:selected_project_id, nil)
     |> assign(:project_characters, [])
     |> assign(:project_locations, [])}
  end

  def handle_event("set_scope", %{"scope" => "project"}, socket) do
    {:noreply, assign(socket, :scope, "project")}
  end

  def handle_event("select_project", %{"id" => id}, socket) do
    project_id = String.to_integer(id)
    chars = Characters.list_characters(project_id)
    locs = Locations.list_locations(project_id)

    {:noreply,
     socket
     |> assign(:selected_project_id, project_id)
     |> assign(:project_characters, chars)
     |> assign(:project_locations, locs)}
  end

  def handle_event("search", %{"search" => search}, socket) do
    {:noreply, assign(socket, :search, search)}
  end

  def handle_event("create_asset", _, socket) do
    type =
      case socket.assigns.tab do
        "characters" -> "character"
        "locations" -> "location"
        "props" -> "prop"
        "voices" -> "voice"
        "sfx" -> "sfx"
        "bgm" -> "bgm"
        _ -> "character"
      end

    {:noreply,
     socket
     |> assign(:show_asset_form, true)
     |> assign(:asset_form_type, type)
     |> assign(:editing_asset, nil)}
  end

  def handle_event("close_asset_form", _, socket) do
    {:noreply, assign(socket, :show_asset_form, false)}
  end

  # ── Detail view ──

  def handle_event("open_detail", %{"id" => id, "type" => type}, socket) do
    asset = find_asset(socket.assigns, id, type)

    if asset do
      {:noreply, assign(socket, detail_asset: asset, detail_type: type)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("close_detail", _, socket) do
    {:noreply, assign(socket, detail_asset: nil, detail_type: nil)}
  end

  # ── Edit from card or detail ──

  def handle_event("edit_from_card", %{"id" => id, "type" => type}, socket) do
    asset = find_asset(socket.assigns, id, type)

    {:noreply,
     socket
     |> assign(:show_asset_form, true)
     |> assign(:asset_form_type, type)
     |> assign(:editing_asset, asset)}
  end

  def handle_event("edit_asset", %{"id" => id, "type" => type}, socket) do
    asset = find_asset(socket.assigns, id, type)

    {:noreply,
     socket
     |> assign(:show_asset_form, true)
     |> assign(:asset_form_type, type)
     |> assign(:editing_asset, asset)
     |> assign(:detail_asset, nil)}
  end

  # ── Quick generate from card overlay ──

  def handle_event("quick_generate", %{"id" => id, "type" => type}, socket) do
    asset = find_asset(socket.assigns, id, type)
    user_id = socket.assigns.current_scope.user.id

    if asset && type in ["character", "location", "prop"] do
      generating_ids = MapSet.put(socket.assigns.generating_ids, id)
      socket = assign(socket, :generating_ids, generating_ids)

      parent = self()

      Task.start(fn ->
        result =
          case type do
            "character" ->
              AstraAutoEx.AssetHub.Generator.generate_character_image(user_id, asset)

            "location" ->
              AstraAutoEx.AssetHub.Generator.generate_location_image(user_id, asset)

            "prop" ->
              AstraAutoEx.AssetHub.Generator.generate_prop_image(user_id, asset)
          end

        send(parent, {:generation_complete, id, result})
      end)

      {:noreply, put_flash(socket, :info, "正在生成参考图，请稍候...")}
    else
      {:noreply, socket}
    end
  end

  # ── Batch generate all ──

  def handle_event("generate_all", _, socket) do
    user_id = socket.assigns.current_scope.user.id
    tab = socket.assigns.tab
    items = all_items_for_tab(tab, socket.assigns)

    # Filter to items that need generation (visual types without images)
    to_generate =
      items
      |> Enum.filter(fn item ->
        item.type in ["character", "location", "prop"] && !has_image?(item)
      end)

    if to_generate == [] do
      {:noreply, put_flash(socket, :info, "所有资产已有参考图，无需生成")}
    else
      ids = Enum.map(to_generate, & &1.id) |> MapSet.new()
      generating_ids = MapSet.union(socket.assigns.generating_ids, ids)

      root_pid = self()

      Enum.each(to_generate, fn item ->
        asset = find_asset(socket.assigns, item.id, item.type)

        Task.start(fn ->
          result =
            case item.type do
              "character" ->
                AstraAutoEx.AssetHub.Generator.generate_character_image(user_id, asset)

              "location" ->
                AstraAutoEx.AssetHub.Generator.generate_location_image(user_id, asset)

              "prop" ->
                AstraAutoEx.AssetHub.Generator.generate_prop_image(user_id, asset)
            end

          send(root_pid, {:generation_complete, item.id, result})
        end)
      end)

      {:noreply,
       socket
       |> assign(:generating_ids, generating_ids)
       |> put_flash(:info, "正在为 #{MapSet.size(ids)} 个资产生成参考图...")}
    end
  end

  # ── Delete ──

  def handle_event("delete_asset", %{"id" => id, "type" => type}, socket) do
    {:noreply, assign(socket, confirm_delete_id: id, confirm_delete_type: type)}
  end

  def handle_event("confirm_delete", _, socket) do
    user_id = socket.assigns.current_scope.user.id

    try do
      case socket.assigns.confirm_delete_type do
        "character" ->
          AssetHub.get_global_character!(socket.assigns.confirm_delete_id)
          |> AssetHub.delete_global_character()

        "location" ->
          AssetHub.get_global_location!(socket.assigns.confirm_delete_id)
          |> AssetHub.delete_global_location()

        "prop" ->
          AssetHub.get_global_prop!(socket.assigns.confirm_delete_id)
          |> AssetHub.delete_global_prop()

        "voice" ->
          AssetHub.get_global_voice!(socket.assigns.confirm_delete_id)
          |> AssetHub.delete_global_voice()

        "sfx" ->
          AssetHub.get_global_sfx!(socket.assigns.confirm_delete_id)
          |> AssetHub.delete_global_sfx()

        "bgm" ->
          AssetHub.get_global_bgm!(socket.assigns.confirm_delete_id)
          |> AssetHub.delete_global_bgm()

        _ ->
          {:ok, nil}
      end

      {:noreply,
       socket
       |> reload_assets(user_id)
       |> assign(:confirm_delete_id, nil)
       |> assign(:detail_asset, nil)
       |> put_flash(:info, "已删除")}
    rescue
      _ -> {:noreply, assign(socket, :confirm_delete_id, nil) |> put_flash(:error, "删除失败")}
    end
  end

  def handle_event("cancel_delete", _, socket) do
    {:noreply, assign(socket, confirm_delete_id: nil)}
  end

  # ── Callbacks ──

  @impl true
  def handle_info({:asset_created, _type}, socket) do
    user_id = socket.assigns.current_scope.user.id

    {:noreply,
     socket
     |> reload_assets(user_id)
     |> assign(:show_asset_form, false)
     |> put_flash(:info, "资产创建成功！")}
  end

  def handle_info({:asset_updated, _type}, socket) do
    user_id = socket.assigns.current_scope.user.id

    {:noreply,
     socket
     |> reload_assets(user_id)
     |> refresh_detail()}
  end

  def handle_info({:generation_complete, asset_id, result}, socket) do
    user_id = socket.assigns.current_scope.user.id
    generating_ids = MapSet.delete(socket.assigns.generating_ids, asset_id)

    socket =
      case result do
        {:ok, _} ->
          socket
          |> reload_assets(user_id)
          |> refresh_detail()
          |> put_flash(:info, "参考图生成成功")

        {:error, reason} ->
          put_flash(socket, :error, "生成失败：#{inspect(reason)}")
      end

    {:noreply, assign(socket, :generating_ids, generating_ids)}
  end

  def handle_info({:refine_complete, _id, result}, socket) do
    user_id = socket.assigns.current_scope.user.id

    socket =
      case result do
        {:ok, _} ->
          socket
          |> reload_assets(user_id)
          |> refresh_detail()
          |> put_flash(:info, "精调完成")

        {:error, reason} ->
          put_flash(socket, :error, "精调失败：#{inspect(reason)}")
      end

    {:noreply, socket}
  end

  def handle_info({:music_complete, _id, result}, socket) do
    user_id = socket.assigns.current_scope.user.id

    socket =
      case result do
        {:ok, _} ->
          socket
          |> reload_assets(user_id)
          |> refresh_detail()
          |> put_flash(:info, "音乐生成成功")

        {:error, reason} ->
          put_flash(socket, :error, "音乐生成失败：#{inspect(reason)}")
      end

    {:noreply, socket}
  end

  # ── Helpers ──

  defp tab_label("all"), do: dgettext("projects", "All Assets")
  defp tab_label("characters"), do: dgettext("projects", "Characters")
  defp tab_label("locations"), do: dgettext("projects", "Locations")
  defp tab_label("props"), do: dgettext("projects", "Props")
  defp tab_label("voices"), do: dgettext("projects", "Voices")
  defp tab_label("sfx"), do: dgettext("projects", "SFX")
  defp tab_label("bgm"), do: dgettext("projects", "BGM")

  defp tab_count(tab, assigns) do
    length(all_items_for_tab(tab, assigns))
  end

  defp all_items_for_tab(tab, assigns) do
    items =
      if assigns.scope == "project" && assigns.selected_project_id do
        # Project-scoped: show project characters + locations only
        case tab do
          "all" ->
            tag_items(assigns.project_characters, "character") ++
              tag_items(assigns.project_locations, "location")

          "characters" ->
            tag_items(assigns.project_characters, "character")

          "locations" ->
            tag_items(assigns.project_locations, "location")

          _ ->
            []
        end
      else
        # Global scope: show all global assets
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

      desc =
        Map.get(item, :description, "") || Map.get(item, :introduction, "") ||
          Map.get(item, :summary, "") || ""

      String.contains?(String.downcase(name), term) or
        String.contains?(String.downcase(desc), term)
    end)
  end

  defp find_asset(assigns, id, type) do
    list =
      if assigns.scope == "project" && assigns.selected_project_id do
        case type do
          "character" -> assigns.project_characters
          "location" -> assigns.project_locations
          _ -> []
        end
      else
        case type do
          "character" -> assigns.characters
          "location" -> assigns.locations
          "prop" -> assigns.props
          "voice" -> assigns.voices
          "sfx" -> assigns.sfx
          "bgm" -> assigns.bgm
          _ -> []
        end
      end

    Enum.find(list, fn item -> to_string(item.id) == to_string(id) end)
  end

  defp has_image?(item) do
    case item.type do
      "character" ->
        case Map.get(item, :appearances, []) do
          [%{image_url: url} | _] when is_binary(url) and url != "" -> true
          _ -> false
        end

      "location" ->
        case Map.get(item, :images, []) do
          [%{image_url: url} | _] when is_binary(url) and url != "" -> true
          _ -> false
        end

      "prop" ->
        url = Map.get(item, :image_url)
        is_binary(url) and url != ""

      _ ->
        false
    end
  end

  defp get_image(item) do
    case item.type do
      "character" ->
        case Map.get(item, :appearances, []) do
          [%{image_url: url} | _] -> url
          _ -> nil
        end

      "location" ->
        case Map.get(item, :images, []) do
          [%{image_url: url} | _] -> url
          _ -> nil
        end

      "prop" ->
        Map.get(item, :image_url)

      _ ->
        nil
    end
  end

  defp type_badge("character"), do: "bg-blue-500/20 text-blue-400"
  defp type_badge("location"), do: "bg-green-500/20 text-green-400"
  defp type_badge("prop"), do: "bg-orange-500/20 text-orange-400"
  defp type_badge("voice"), do: "bg-purple-500/20 text-purple-400"
  defp type_badge("bgm"), do: "bg-pink-500/20 text-pink-400"
  defp type_badge("sfx"), do: "bg-yellow-500/20 text-yellow-400"
  defp type_badge(_), do: "bg-gray-500/20 text-gray-400"

  defp type_label_short("character"), do: "角色"
  defp type_label_short("location"), do: "场景"
  defp type_label_short("prop"), do: "道具"
  defp type_label_short("voice"), do: "音色"
  defp type_label_short("bgm"), do: "BGM"
  defp type_label_short("sfx"), do: "SFX"
  defp type_label_short(_), do: ""

  defp reload_assets(socket, user_id) do
    socket
    |> assign(:characters, AssetHub.list_global_characters(user_id))
    |> assign(:locations, AssetHub.list_global_locations(user_id))
    |> assign(:props, AssetHub.list_global_props(user_id))
    |> assign(:voices, AssetHub.list_global_voices(user_id))
    |> assign(:sfx, AssetHub.list_global_sfx(user_id))
    |> assign(:bgm, AssetHub.list_global_bgm(user_id))
  end

  defp refresh_detail(socket) do
    if socket.assigns.detail_asset && socket.assigns.detail_type do
      asset =
        find_asset(
          socket.assigns,
          socket.assigns.detail_asset.id,
          socket.assigns.detail_type
        )

      assign(socket, :detail_asset, asset)
    else
      socket
    end
  end
end
