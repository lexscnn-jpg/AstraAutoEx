defmodule AstraAutoExWeb.AssetHubLive.AssetDetail do
  @moduledoc "Detail panel for a single asset: image preview, generation actions, refinement, audio player."
  use AstraAutoExWeb, :live_component

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:generating, false)
     |> assign(:refining, false)
     |> assign(:refine_instruction, "")
     |> assign(:gen_error, nil)
     |> assign(:music_generating, false)}
  end

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm">
      <div class="glass-card p-0 w-full max-w-3xl mx-4 max-h-[85vh] overflow-hidden flex flex-col">
        <%!-- Header --%>
        <div class="flex items-center justify-between px-6 py-4 border-b border-[var(--glass-stroke-base)]">
          <div class="flex items-center gap-3">
            <span class={"px-2 py-0.5 rounded text-[10px] font-medium #{type_badge_color(@asset_type)}"}>
              {type_label(@asset_type)}
            </span>
            <h3 class="text-lg font-semibold text-[var(--glass-text-primary)]">
              {@asset.name}
            </h3>
          </div>
          <div class="flex items-center gap-2">
            <button
              phx-click="edit_asset"
              phx-value-id={@asset.id}
              phx-value-type={@asset_type}
              class="glass-btn glass-btn-ghost text-xs py-1.5 px-3"
            >
              <svg class="w-3.5 h-3.5 inline mr-1" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                <path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7" />
                <path d="M18.5 2.5a2.121 2.121 0 013 3L12 15l-4 1 1-4 9.5-9.5z" />
              </svg>
              编辑
            </button>
            <button
              phx-click="close_detail"
              class="text-[var(--glass-text-tertiary)] hover:text-[var(--glass-text-primary)] p-1"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                <path d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>
        </div>

        <%!-- Body --%>
        <div class="flex-1 overflow-y-auto">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-0">
            <%!-- Left: Image preview --%>
            <div class="bg-[var(--glass-bg-muted)] flex items-center justify-center min-h-[300px] relative">
              <%= if image_url(@asset_type, @asset) do %>
                <img
                  src={image_url(@asset_type, @asset)}
                  class="max-w-full max-h-[400px] object-contain"
                />
              <% else %>
                <%= if @asset_type in ["sfx", "bgm"] do %>
                  <.audio_placeholder asset={@asset} asset_type={@asset_type} />
                <% else %>
                  <div class="text-center py-12">
                    <div class="text-5xl text-[var(--glass-text-tertiary)] opacity-20 mb-3">
                      {String.first(@asset.name || "?")}
                    </div>
                    <p class="text-xs text-[var(--glass-text-tertiary)]">暂无参考图</p>
                  </div>
                <% end %>
              <% end %>

              <%!-- Generating overlay --%>
              <div :if={@generating} class="absolute inset-0 bg-black/60 flex items-center justify-center">
                <div class="text-center">
                  <div class="w-8 h-8 border-2 border-[var(--glass-accent-from)] border-t-transparent rounded-full animate-spin mx-auto mb-2" />
                  <p class="text-xs text-white/80">正在生成...</p>
                </div>
              </div>
            </div>

            <%!-- Right: Info + Actions --%>
            <div class="p-5 space-y-4">
              <%!-- Description --%>
              <div>
                <label class="text-[10px] uppercase tracking-wider text-[var(--glass-text-tertiary)] mb-1 block">
                  描述
                </label>
                <p class="text-sm text-[var(--glass-text-secondary)]">
                  {get_description(@asset_type, @asset) || "暂无描述"}
                </p>
              </div>

              <%!-- Type-specific info --%>
              <.type_info asset={@asset} asset_type={@asset_type} />

              <%!-- Error display --%>
              <div :if={@gen_error} class="text-xs text-red-400 bg-red-500/10 rounded-lg px-3 py-2">
                {@gen_error}
              </div>

              <%!-- Generation actions for visual assets --%>
              <%= if @asset_type in ["character", "location", "prop"] do %>
                <div class="space-y-2 pt-2 border-t border-[var(--glass-stroke-base)]">
                  <label class="text-[10px] uppercase tracking-wider text-[var(--glass-text-tertiary)] block">
                    图像生成
                  </label>
                  <div class="flex flex-wrap gap-2">
                    <button
                      phx-click="generate_image"
                      phx-target={@myself}
                      disabled={@generating}
                      class="glass-btn glass-btn-primary text-xs py-1.5 px-3 flex items-center gap-1"
                    >
                      <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                        <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z" />
                      </svg>
                      {if image_url(@asset_type, @asset), do: "重新生成", else: "生成参考图"}
                    </button>
                    <%= if image_url(@asset_type, @asset) do %>
                      <button
                        phx-click="delete_image"
                        phx-target={@myself}
                        class="glass-btn text-xs py-1.5 px-3 text-red-400 hover:bg-red-500/10"
                      >
                        删除图片
                      </button>
                    <% end %>
                  </div>

                  <%!-- Refinement (精调) --%>
                  <%= if image_url(@asset_type, @asset) do %>
                    <div class="mt-3">
                      <label class="text-[10px] uppercase tracking-wider text-[var(--glass-text-tertiary)] mb-1 block">
                        精调（指令式修改）
                      </label>
                      <div class="flex gap-2">
                        <input
                          type="text"
                          value={@refine_instruction}
                          phx-change="update_refine"
                          phx-target={@myself}
                          name="instruction"
                          placeholder="如：换成红色头发、添加一把剑..."
                          class="glass-input text-xs flex-1"
                        />
                        <button
                          phx-click="refine_image"
                          phx-target={@myself}
                          disabled={@refining || @refine_instruction == ""}
                          class="glass-btn glass-btn-primary text-xs py-1.5 px-3 whitespace-nowrap"
                        >
                          {if @refining, do: "修改中...", else: "精调"}
                        </button>
                      </div>
                      <%= if @asset_type == "prop" && @asset.previous_image_url do %>
                        <button
                          phx-click="undo_refine"
                          phx-target={@myself}
                          class="text-xs text-[var(--glass-accent-from)] hover:underline mt-1"
                        >
                          撤销上次修改
                        </button>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              <% end %>

              <%!-- Music generation for BGM --%>
              <%= if @asset_type == "bgm" do %>
                <div class="space-y-2 pt-2 border-t border-[var(--glass-stroke-base)]">
                  <label class="text-[10px] uppercase tracking-wider text-[var(--glass-text-tertiary)] block">
                    音乐生成（MiniMax music-2.6）
                  </label>
                  <button
                    phx-click="generate_music"
                    phx-target={@myself}
                    disabled={@music_generating}
                    class="glass-btn glass-btn-primary text-xs py-1.5 px-3 flex items-center gap-1"
                  >
                    <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                      <path d="M9 18V5l12-2v13" /><circle cx="6" cy="18" r="3" /><circle cx="18" cy="16" r="3" />
                    </svg>
                    {if @music_generating, do: "生成中...", else: if(@asset.audio_url, do: "重新生成", else: "AI 生成音乐")}
                  </button>
                  <%= if @asset.audio_url do %>
                    <audio controls class="w-full mt-2 h-8" src={@asset.audio_url} />
                  <% end %>
                </div>
              <% end %>

              <%!-- Audio player for SFX --%>
              <%= if @asset_type == "sfx" && @asset.audio_url do %>
                <div class="pt-2 border-t border-[var(--glass-stroke-base)]">
                  <label class="text-[10px] uppercase tracking-wider text-[var(--glass-text-tertiary)] mb-1 block">
                    音频预览
                  </label>
                  <audio controls class="w-full h-8" src={@asset.audio_url} />
                </div>
              <% end %>

              <%!-- Audio player for Voice --%>
              <%= if @asset_type == "voice" && @asset.custom_voice_url do %>
                <div class="pt-2 border-t border-[var(--glass-stroke-base)]">
                  <label class="text-[10px] uppercase tracking-wider text-[var(--glass-text-tertiary)] mb-1 block">
                    试听预览
                  </label>
                  <audio controls class="w-full h-8" src={@asset.custom_voice_url} />
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ── Events ──

  @impl true
  def handle_event("generate_image", _, socket) do
    asset = socket.assigns.asset
    asset_type = socket.assigns.asset_type
    user_id = socket.assigns.user_id

    socket = assign(socket, generating: true, gen_error: nil)

    # Spawn async generation — self() is the parent LiveView process
    parent = self()
    asset_id = asset.id

    Task.start(fn ->
      result =
        case asset_type do
          "character" -> AstraAutoEx.AssetHub.Generator.generate_character_image(user_id, asset)
          "location" -> AstraAutoEx.AssetHub.Generator.generate_location_image(user_id, asset)
          "prop" -> AstraAutoEx.AssetHub.Generator.generate_prop_image(user_id, asset)
          _ -> {:error, "Unsupported type"}
        end

      send(parent, {:generation_complete, asset_id, result})
    end)

    {:noreply, socket}
  end

  def handle_event("delete_image", _, socket) do
    asset = socket.assigns.asset
    asset_type = socket.assigns.asset_type

    case asset_type do
      "prop" ->
        AstraAutoEx.AssetHub.update_global_prop(asset, %{image_url: nil})

      "character" ->
        Enum.each(asset.appearances || [], fn app ->
          AstraAutoEx.AssetHub.GlobalCharacterAppearance.changeset(app, %{image_url: nil})
          |> AstraAutoEx.Repo.update()
        end)

      "location" ->
        Enum.each(asset.images || [], fn img ->
          AstraAutoEx.AssetHub.GlobalLocationImage.changeset(img, %{image_url: nil})
          |> AstraAutoEx.Repo.update()
        end)

      _ ->
        :ok
    end

    send(self(), {:asset_updated, asset_type})
    {:noreply, socket}
  end

  def handle_event("update_refine", %{"instruction" => instruction}, socket) do
    {:noreply, assign(socket, :refine_instruction, instruction)}
  end

  def handle_event("refine_image", _, socket) do
    asset = socket.assigns.asset
    asset_type = socket.assigns.asset_type
    user_id = socket.assigns.user_id
    instruction = socket.assigns.refine_instruction

    socket = assign(socket, refining: true, gen_error: nil)

    parent = self()

    Task.start(fn ->
      result = AstraAutoEx.AssetHub.Generator.refine_image(user_id, asset_type, asset, instruction)
      send(parent, {:refine_complete, asset.id, result})
    end)

    {:noreply, socket}
  end

  def handle_event("undo_refine", _, socket) do
    asset = socket.assigns.asset
    asset_type = socket.assigns.asset_type

    case AstraAutoEx.AssetHub.Generator.undo_refine(asset_type, asset) do
      {:ok, _} ->
        send(self(), {:asset_updated, asset_type})
        {:noreply, socket}

      {:error, msg} ->
        {:noreply, assign(socket, :gen_error, msg)}
    end
  end

  def handle_event("generate_music", _, socket) do
    bgm = socket.assigns.asset
    user_id = socket.assigns.user_id

    socket = assign(socket, music_generating: true, gen_error: nil)

    parent = self()

    Task.start(fn ->
      result = AstraAutoEx.AssetHub.Generator.generate_music(user_id, bgm)
      send(parent, {:music_complete, bgm.id, result})
    end)

    {:noreply, socket}
  end

  # ── Private Components ──

  defp audio_placeholder(assigns) do
    ~H"""
    <div class="text-center py-12">
      <svg class="w-16 h-16 mx-auto text-[var(--glass-text-tertiary)] opacity-30 mb-3" fill="none" stroke="currentColor" stroke-width="1" viewBox="0 0 24 24">
        <path d="M9 18V5l12-2v13" /><circle cx="6" cy="18" r="3" /><circle cx="18" cy="16" r="3" />
      </svg>
      <%= if @asset.audio_url do %>
        <audio controls class="mx-auto" src={@asset.audio_url} />
      <% else %>
        <p class="text-xs text-[var(--glass-text-tertiary)]">
          {if @asset_type == "bgm", do: "点击右侧生成音乐", else: "暂无音频"}
        </p>
      <% end %>
    </div>
    """
  end

  defp type_info(%{asset_type: "character"} = assigns) do
    ~H"""
    <div class="grid grid-cols-2 gap-3 text-xs">
      <div>
        <span class="text-[var(--glass-text-tertiary)]">别名</span>
        <p class="text-[var(--glass-text-secondary)]">{@asset.aliases || "无"}</p>
      </div>
      <div>
        <span class="text-[var(--glass-text-tertiary)]">音色</span>
        <p class="text-[var(--glass-text-secondary)]">{@asset.voice_id || "未分配"}</p>
      </div>
    </div>
    """
  end

  defp type_info(%{asset_type: "prop"} = assigns) do
    ~H"""
    <div class="text-xs">
      <span class="text-[var(--glass-text-tertiary)]">类型</span>
      <p class="text-[var(--glass-text-secondary)]">{prop_label(@asset.prop_type)}</p>
    </div>
    """
  end

  defp type_info(%{asset_type: "voice"} = assigns) do
    ~H"""
    <div class="grid grid-cols-2 gap-3 text-xs">
      <div>
        <span class="text-[var(--glass-text-tertiary)]">性别</span>
        <p class="text-[var(--glass-text-secondary)]">{gender_label(@asset.gender)}</p>
      </div>
      <div>
        <span class="text-[var(--glass-text-tertiary)]">语言</span>
        <p class="text-[var(--glass-text-secondary)]">{lang_label(@asset.language)}</p>
      </div>
    </div>
    """
  end

  defp type_info(%{asset_type: "bgm"} = assigns) do
    ~H"""
    <div class="grid grid-cols-2 gap-3 text-xs">
      <div>
        <span class="text-[var(--glass-text-tertiary)]">类别</span>
        <p class="text-[var(--glass-text-secondary)]">{bgm_category(@asset.category)}</p>
      </div>
      <div>
        <span class="text-[var(--glass-text-tertiary)]">类型</span>
        <p class="text-[var(--glass-text-secondary)]">{if @asset.is_instrumental, do: "纯音乐", else: "含人声"}</p>
      </div>
    </div>
    """
  end

  defp type_info(assigns) do
    ~H"""
    <div></div>
    """
  end

  # ── Helpers ──

  defp image_url("character", asset) do
    case asset.appearances do
      [%{image_url: url} | _] when is_binary(url) and url != "" -> url
      _ -> nil
    end
  end

  defp image_url("location", asset) do
    case asset.images do
      [%{image_url: url} | _] when is_binary(url) and url != "" -> url
      _ -> nil
    end
  end

  defp image_url("prop", asset), do: if(asset.image_url && asset.image_url != "", do: asset.image_url)
  defp image_url(_, _), do: nil

  defp get_description("character", a), do: a.introduction
  defp get_description("location", a), do: a.summary || Map.get(a, :description, nil)
  defp get_description(_, a), do: a.description

  defp type_badge_color("character"), do: "bg-blue-500/20 text-blue-400"
  defp type_badge_color("location"), do: "bg-green-500/20 text-green-400"
  defp type_badge_color("prop"), do: "bg-orange-500/20 text-orange-400"
  defp type_badge_color("voice"), do: "bg-purple-500/20 text-purple-400"
  defp type_badge_color("bgm"), do: "bg-pink-500/20 text-pink-400"
  defp type_badge_color("sfx"), do: "bg-yellow-500/20 text-yellow-400"
  defp type_badge_color(_), do: "bg-gray-500/20 text-gray-400"

  defp type_label("character"), do: "角色"
  defp type_label("location"), do: "场景"
  defp type_label("prop"), do: "道具"
  defp type_label("voice"), do: "音色"
  defp type_label("bgm"), do: "BGM"
  defp type_label("sfx"), do: "音效"
  defp type_label(_), do: "资产"

  defp prop_label("weapon"), do: "武器"
  defp prop_label("tool"), do: "工具"
  defp prop_label("accessory"), do: "配饰"
  defp prop_label("vehicle"), do: "载具"
  defp prop_label("food"), do: "食物"
  defp prop_label(_), do: "通用"

  defp gender_label("male"), do: "男"
  defp gender_label("female"), do: "女"
  defp gender_label(_), do: "未指定"

  defp lang_label("zh"), do: "中文"
  defp lang_label("en"), do: "English"
  defp lang_label("ja"), do: "日本語"
  defp lang_label(_), do: "未知"

  defp bgm_category("epic"), do: "史诗"
  defp bgm_category("romantic"), do: "浪漫"
  defp bgm_category("suspense"), do: "悬疑"
  defp bgm_category("comedy"), do: "喜剧"
  defp bgm_category("sad"), do: "悲伤"
  defp bgm_category("action"), do: "动作"
  defp bgm_category(_), do: "通用"
end
