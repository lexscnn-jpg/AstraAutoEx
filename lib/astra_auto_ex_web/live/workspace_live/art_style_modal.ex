defmodule AstraAutoExWeb.WorkspaceLive.ArtStyleModal do
  @moduledoc "Custom art style editor modal with preset templates."
  use AstraAutoExWeb, :live_component

  alias AstraAutoEx.AI.ArtStyles

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:custom_prompt, "")
     |> assign(:selected_template, nil)}
  end

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)
    prompt = assigns[:current_prompt] || ""
    {:ok, assign(socket, :custom_prompt, prompt)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center">
      <div class="absolute inset-0 bg-black/60 backdrop-blur-sm" phx-click="close_art_style_modal" />
      <div class="glass-card p-6 w-full max-w-2xl relative z-10 shadow-2xl max-h-[85vh] overflow-y-auto">
        <div class="flex items-center justify-between mb-5">
          <div>
            <h3 class="text-lg font-bold text-[var(--glass-text-primary)]">自定义画风</h3>
            <p class="text-xs text-[var(--glass-text-tertiary)]">选择预置模板并修改核心描述</p>
          </div>
          <button phx-click="close_art_style_modal" class="text-[var(--glass-text-tertiary)] hover:text-[var(--glass-text-primary)]">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M6 18L18 6M6 6l12 12" /></svg>
          </button>
        </div>

        <%!-- Template grid --%>
        <div class="mb-4">
          <label class="text-xs text-[var(--glass-text-tertiary)] mb-2 block">选择模板（点击自动填入提示词，你只需修改核心内容）</label>
          <div class="grid grid-cols-3 gap-2">
            <%= for style <- ArtStyles.all_styles() do %>
              <button
                type="button"
                phx-click="select_template"
                phx-value-value={style.value}
                phx-target={@myself}
                class={"p-2 rounded-lg text-xs text-left transition-all " <>
                  if(@selected_template == style.value,
                    do: "bg-[var(--glass-accent-from)]/20 text-[var(--glass-accent-from)] ring-1 ring-[var(--glass-accent-from)]/30",
                    else: "bg-[var(--glass-bg-muted)] text-[var(--glass-text-secondary)] hover:bg-[var(--glass-bg-muted)]/80")}
              >
                <div class="font-medium">{style.label}</div>
                <div class="text-[10px] text-[var(--glass-text-tertiary)] mt-0.5 line-clamp-1">{String.slice(style.prompt_zh, 0..30)}...</div>
              </button>
            <% end %>
          </div>
        </div>

        <%!-- Custom prompt editor --%>
        <div class="mb-4">
          <label class="text-xs text-[var(--glass-text-tertiary)] mb-1 block">画风提示词（修改核心描述即可）</label>
          <textarea
            name="custom_prompt"
            rows="6"
            phx-change="update_custom_prompt"
            phx-target={@myself}
            class="glass-input w-full text-sm resize-none"
            placeholder="在此编辑画风提示词..."
          ><%= @custom_prompt %></textarea>
          <p class="text-[10px] text-[var(--glass-text-tertiary)] mt-1">
            提示词将应用于所有图像生成（角色参考图、场景图、分镜图）
          </p>
        </div>

        <%!-- Actions --%>
        <div class="flex justify-end gap-3">
          <button phx-click="close_art_style_modal" class="glass-btn px-4 py-2 text-sm">取消</button>
          <button
            phx-click="apply_custom_art_style"
            phx-value-prompt={@custom_prompt}
            class="glass-btn glass-btn-primary px-6 py-2 text-sm"
          >
            应用画风
          </button>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("select_template", %{"value" => value}, socket) do
    prompt =
      case Enum.find(ArtStyles.all_styles(), &(&1.value == value)) do
        nil -> socket.assigns.custom_prompt
        style -> style.prompt_zh
      end

    {:noreply,
     socket
     |> assign(:selected_template, value)
     |> assign(:custom_prompt, prompt)}
  end

  def handle_event("update_custom_prompt", %{"custom_prompt" => prompt}, socket) do
    {:noreply, assign(socket, :custom_prompt, prompt)}
  end
end
