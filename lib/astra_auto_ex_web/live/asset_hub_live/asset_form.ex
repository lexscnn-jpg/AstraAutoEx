defmodule AstraAutoExWeb.AssetHubLive.AssetForm do
  @moduledoc "Unified modal form for creating/editing all 5 asset types."
  use AstraAutoExWeb, :live_component

  alias AstraAutoEx.AssetHub

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:name, "")
     |> assign(:description, "")
     |> assign(:gender, "")
     |> assign(:language, "zh")
     |> assign(:category, "")
     |> assign(:aliases, "")
     |> assign(:prop_type, "")
     |> assign(:candidate_count, 1)
     |> assign(:saving, false)
     |> assign(:error, nil)}
  end

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    # Pre-fill for edit mode
    socket =
      if assigns[:editing] do
        item = assigns.editing

        socket
        |> assign(:name, Map.get(item, :name, ""))
        |> assign(
          :description,
          Map.get(item, :description, "") || Map.get(item, :introduction, "") || ""
        )
        |> assign(:gender, Map.get(item, :gender, ""))
        |> assign(:aliases, (Map.get(item, :aliases, []) || []) |> Enum.join(", "))
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm">
      <div class="glass-card p-6 max-w-lg w-full mx-4 max-h-[80vh] overflow-y-auto">
        <div class="flex items-center justify-between mb-4">
          <h3 class="text-lg font-semibold text-[var(--glass-text-primary)]">
            {form_title(@asset_type, @editing)}
          </h3>
          <button
            type="button"
            phx-click="close_asset_form"
            class="text-[var(--glass-text-tertiary)] hover:text-[var(--glass-text-primary)]"
          >
            <svg
              class="w-5 h-5"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              viewBox="0 0 24 24"
            >
              <path d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <form phx-submit="save_asset" phx-target={@myself} class="space-y-4">
          <input type="hidden" name="asset_type" value={@asset_type} />

          <%!-- Name (all types) --%>
          <div>
            <label class="block text-xs text-[var(--glass-text-tertiary)] mb-1">名称 *</label>
            <input
              type="text"
              name="name"
              value={@name}
              phx-change="update_field"
              phx-target={@myself}
              required
              class="glass-input w-full text-sm"
              placeholder="输入名称..."
            />
          </div>

          <%!-- Character-specific fields --%>
          <%= if @asset_type == "character" do %>
            <div>
              <label class="block text-xs text-[var(--glass-text-tertiary)] mb-1">别名（逗号分隔）</label>
              <input
                type="text"
                name="aliases"
                value={@aliases}
                phx-change="update_field"
                phx-target={@myself}
                class="glass-input w-full text-sm"
                placeholder="别名1, 别名2..."
              />
            </div>
            <div class="grid grid-cols-2 gap-3">
              <div>
                <label class="block text-xs text-[var(--glass-text-tertiary)] mb-1">性别</label>
                <select
                  name="gender"
                  class="glass-input w-full text-sm"
                  phx-change="update_field"
                  phx-target={@myself}
                >
                  <option value="">未指定</option>
                  <option value="male" selected={@gender == "male"}>男</option>
                  <option value="female" selected={@gender == "female"}>女</option>
                </select>
              </div>
              <div>
                <label class="block text-xs text-[var(--glass-text-tertiary)] mb-1">候选数量（抽卡）</label>
                <select
                  name="candidate_count"
                  class="glass-input w-full text-sm"
                  phx-change="update_field"
                  phx-target={@myself}
                >
                  <%= for n <- 1..4 do %>
                    <option value={n} selected={@candidate_count == n}>{n} 张</option>
                  <% end %>
                </select>
              </div>
            </div>
          <% end %>

          <%!-- Prop-specific --%>
          <%= if @asset_type == "prop" do %>
            <div>
              <label class="block text-xs text-[var(--glass-text-tertiary)] mb-1">道具类型</label>
              <select
                name="prop_type"
                class="glass-input w-full text-sm"
                phx-change="update_field"
                phx-target={@myself}
              >
                <option value="">通用</option>
                <option value="weapon" selected={@prop_type == "weapon"}>武器</option>
                <option value="tool" selected={@prop_type == "tool"}>工具</option>
                <option value="accessory" selected={@prop_type == "accessory"}>配饰</option>
                <option value="vehicle" selected={@prop_type == "vehicle"}>载具</option>
                <option value="food" selected={@prop_type == "food"}>食物</option>
              </select>
            </div>
          <% end %>

          <%!-- Voice-specific --%>
          <%= if @asset_type == "voice" do %>
            <div class="grid grid-cols-2 gap-3">
              <div>
                <label class="block text-xs text-[var(--glass-text-tertiary)] mb-1">性别</label>
                <select
                  name="gender"
                  class="glass-input w-full text-sm"
                  phx-change="update_field"
                  phx-target={@myself}
                >
                  <option value="male" selected={@gender == "male"}>男</option>
                  <option value="female" selected={@gender == "female"}>女</option>
                </select>
              </div>
              <div>
                <label class="block text-xs text-[var(--glass-text-tertiary)] mb-1">语言</label>
                <select
                  name="language"
                  class="glass-input w-full text-sm"
                  phx-change="update_field"
                  phx-target={@myself}
                >
                  <option value="zh" selected={@language == "zh"}>中文</option>
                  <option value="en" selected={@language == "en"}>English</option>
                  <option value="ja" selected={@language == "ja"}>日本語</option>
                </select>
              </div>
            </div>
          <% end %>

          <%!-- BGM-specific --%>
          <%= if @asset_type == "bgm" do %>
            <div>
              <label class="block text-xs text-[var(--glass-text-tertiary)] mb-1">类别</label>
              <select
                name="category"
                class="glass-input w-full text-sm"
                phx-change="update_field"
                phx-target={@myself}
              >
                <option value="">通用</option>
                <option value="epic">史诗</option>
                <option value="romantic">浪漫</option>
                <option value="suspense">悬疑</option>
                <option value="comedy">喜剧</option>
                <option value="sad">悲伤</option>
                <option value="action">动作</option>
              </select>
            </div>
            <div class="flex items-center gap-2">
              <input type="checkbox" name="is_instrumental" value="true" class="glass-input" />
              <label class="text-xs text-[var(--glass-text-secondary)]">纯音乐（无人声）</label>
            </div>
          <% end %>

          <%!-- Description (all types) --%>
          <div>
            <label class="block text-xs text-[var(--glass-text-tertiary)] mb-1">描述</label>
            <textarea
              name="description"
              rows="3"
              phx-change="update_field"
              phx-target={@myself}
              class="glass-input w-full text-sm resize-none"
              placeholder={desc_placeholder(@asset_type)}
            ><%= @description %></textarea>
          </div>

          <%!-- Error --%>
          <div :if={@error} class="text-xs text-red-400">{@error}</div>

          <%!-- Actions --%>
          <div class="flex items-center justify-between pt-2">
            <div class="text-xs text-[var(--glass-text-tertiary)]">
              <%= if @asset_type in ["character", "location", "prop"] do %>
                保存后可生成参考图
              <% end %>
            </div>
            <div class="flex gap-2">
              <button type="button" phx-click="close_asset_form" class="glass-btn px-4 py-2 text-sm">
                取消
              </button>
              <button
                type="submit"
                class="glass-btn glass-btn-primary px-4 py-2 text-sm"
                disabled={@saving}
              >
                {if @editing, do: "更新", else: "创建"}
              </button>
            </div>
          </div>
        </form>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("update_field", params, socket) do
    socket =
      socket
      |> maybe_assign(params, "name", :name)
      |> maybe_assign(params, "description", :description)
      |> maybe_assign(params, "gender", :gender)
      |> maybe_assign(params, "language", :language)
      |> maybe_assign(params, "category", :category)
      |> maybe_assign(params, "aliases", :aliases)
      |> maybe_assign(params, "prop_type", :prop_type)
      |> maybe_assign_int(params, "candidate_count", :candidate_count)

    {:noreply, socket}
  end

  def handle_event("save_asset", params, socket) do
    user_id = socket.assigns.user_id
    type = params["asset_type"]

    result =
      case type do
        "character" ->
          aliases =
            (params["aliases"] || "")
            |> String.split(",")
            |> Enum.map(&String.trim/1)
            |> Enum.reject(&(&1 == ""))

          AssetHub.create_global_character(%{
            user_id: user_id,
            name: params["name"],
            introduction: params["description"],
            aliases: aliases
          })

        "location" ->
          AssetHub.create_global_location(%{
            user_id: user_id,
            name: params["name"],
            summary: params["description"]
          })

        "prop" ->
          AssetHub.create_global_prop(%{
            user_id: user_id,
            name: params["name"],
            description: params["description"],
            prop_type: params["prop_type"]
          })

        "voice" ->
          AssetHub.create_global_voice(%{
            user_id: user_id,
            name: params["name"],
            description: params["description"],
            gender: params["gender"],
            language: params["language"]
          })

        "bgm" ->
          AssetHub.create_global_bgm(%{
            user_id: user_id,
            name: params["name"],
            description: params["description"],
            category: params["category"],
            is_instrumental: params["is_instrumental"] == "true"
          })

        "sfx" ->
          AssetHub.create_global_sfx(%{
            user_id: user_id,
            name: params["name"],
            description: params["description"],
            category: params["category"]
          })

        _ ->
          {:error, "Unknown asset type"}
      end

    case result do
      {:ok, _asset} ->
        send(self(), {:asset_created, type})
        {:noreply, socket}

      {:error, changeset} when is_struct(changeset) ->
        {:noreply, assign(socket, :error, "保存失败：请检查必填字段")}

      {:error, msg} ->
        {:noreply, assign(socket, :error, "错误：#{msg}")}
    end
  end

  defp maybe_assign(socket, params, key, assign_key) do
    if Map.has_key?(params, key), do: assign(socket, assign_key, params[key]), else: socket
  end

  defp maybe_assign_int(socket, params, key, assign_key) do
    if Map.has_key?(params, key) do
      assign(socket, assign_key, String.to_integer(params[key]))
    else
      socket
    end
  end

  defp form_title("character", nil), do: "创建角色"
  defp form_title("character", _), do: "编辑角色"
  defp form_title("location", nil), do: "创建场景"
  defp form_title("location", _), do: "编辑场景"
  defp form_title("prop", nil), do: "创建道具"
  defp form_title("prop", _), do: "编辑道具"
  defp form_title("voice", nil), do: "创建音色"
  defp form_title("voice", _), do: "编辑音色"
  defp form_title("bgm", nil), do: "创建背景音乐"
  defp form_title("bgm", _), do: "编辑背景音乐"
  defp form_title("sfx", nil), do: "创建音效"
  defp form_title("sfx", _), do: "编辑音效"
  defp form_title(_, nil), do: "创建资产"
  defp form_title(_, _), do: "编辑资产"

  defp desc_placeholder("character"), do: "角色简介、外貌、性格描述..."
  defp desc_placeholder("location"), do: "场景描述、氛围、特征..."
  defp desc_placeholder("prop"), do: "道具外观、材质、用途..."
  defp desc_placeholder("voice"), do: "声音特点、语调描述..."
  defp desc_placeholder("bgm"), do: "音乐风格、情绪描述（用于AI生成）..."
  defp desc_placeholder("sfx"), do: "音效描述..."
  defp desc_placeholder(_), do: "描述..."
end
