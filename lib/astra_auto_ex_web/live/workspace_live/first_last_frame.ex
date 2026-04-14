defmodule AstraAutoExWeb.WorkspaceLive.FirstLastFrame do
  @moduledoc """
  First/Last Frame transition UI component.
  Shows adjacent panel pair with transition prompt and generation controls.
  """
  use AstraAutoExWeb, :live_component

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:custom_prompt, "")
     |> assign(:generating, false)}
  end

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="glass-card p-4 space-y-4">
      <div class="flex items-center gap-2 mb-2">
        <h4 class="text-sm font-semibold text-[var(--glass-text-primary)]">首尾帧过渡</h4>
        <span class="glass-chip text-[10px]">面板 {@panel_index + 1} → {@panel_index + 2}</span>
      </div>

      <%!-- Side-by-side frame preview --%>
      <div class="flex items-center gap-3">
        <%!-- First frame (current panel) --%>
        <div class="flex-1">
          <div class="text-[10px] text-[var(--glass-text-tertiary)] mb-1">第一帧</div>
          <div class="aspect-video bg-[var(--glass-bg-muted)] rounded-lg overflow-hidden">
            <%= if @current_panel.image_url do %>
              <img src={@current_panel.image_url} class="w-full h-full object-cover" />
            <% else %>
              <div class="w-full h-full flex items-center justify-center text-[var(--glass-text-tertiary)]">
                无图
              </div>
            <% end %>
          </div>
        </div>

        <%!-- Arrow --%>
        <div class="flex-shrink-0 text-[var(--glass-accent-from)]">
          <svg class="w-8 h-8" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" d="M13 7l5 5m0 0l-5 5m5-5H6" />
          </svg>
        </div>

        <%!-- Last frame (next panel) --%>
        <div class="flex-1">
          <div class="text-[10px] text-[var(--glass-text-tertiary)] mb-1">末帧</div>
          <div class="aspect-video bg-[var(--glass-bg-muted)] rounded-lg overflow-hidden">
            <%= if @next_panel.image_url do %>
              <img src={@next_panel.image_url} class="w-full h-full object-cover" />
            <% else %>
              <div class="w-full h-full flex items-center justify-center text-[var(--glass-text-tertiary)]">
                无图
              </div>
            <% end %>
          </div>
        </div>
      </div>

      <%!-- Transition prompt --%>
      <div>
        <label class="text-xs text-[var(--glass-text-tertiary)] mb-1 block">过渡描述（留空自动生成）</label>
        <textarea
          name="fl_prompt"
          rows="2"
          phx-change="update_fl_prompt"
          phx-target={@myself}
          class="glass-input w-full text-sm resize-none"
          placeholder="描述从第一帧到末帧的镜头运动和过渡方式..."
        ><%= @custom_prompt %></textarea>
      </div>

      <%!-- Auto-generated hint --%>
      <div class="text-xs text-[var(--glass-text-tertiary)] bg-[var(--glass-bg-muted)] rounded-lg p-2 opacity-60">
        自动描述：{auto_prompt(@current_panel, @next_panel)}
      </div>

      <%!-- Generate button --%>
      <div class="flex items-center justify-between">
        <span class="text-xs text-[var(--glass-text-tertiary)]">
          模型需支持 firstlastframe 能力
        </span>
        <button
          type="button"
          phx-click="generate_fl_video"
          phx-target={@myself}
          disabled={@generating}
          class="glass-btn glass-btn-primary text-xs py-1.5 px-4 flex items-center gap-1.5"
        >
          <%= if @generating do %>
            <svg class="w-3.5 h-3.5 animate-spin" fill="none" viewBox="0 0 24 24">
              <circle
                class="opacity-25"
                cx="12"
                cy="12"
                r="10"
                stroke="currentColor"
                stroke-width="4"
              />
              <path
                class="opacity-75"
                fill="currentColor"
                d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"
              />
            </svg>
            生成中...
          <% else %>
            生成过渡视频
          <% end %>
        </button>
      </div>

      <%!-- FL video result --%>
      <%= if @current_panel.fl_video_url do %>
        <div class="mt-2">
          <div class="text-xs text-green-400 mb-1">过渡视频已生成</div>
          <video
            src={@current_panel.fl_video_url}
            controls
            class="w-full rounded-lg aspect-video bg-black"
          />
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("update_fl_prompt", %{"fl_prompt" => prompt}, socket) do
    {:noreply, assign(socket, :custom_prompt, prompt)}
  end

  def handle_event("generate_fl_video", _, socket) do
    send(
      self(),
      {:generate_fl_video,
       %{
         panel_id: socket.assigns.current_panel.id,
         next_panel_id: socket.assigns.next_panel.id,
         custom_prompt: socket.assigns.custom_prompt
       }}
    )

    {:noreply, assign(socket, :generating, true)}
  end

  defp auto_prompt(current, next) do
    first_desc = Map.get(current, :description, "") || ""
    last_desc = Map.get(next, :description, "") || ""

    cond do
      last_desc == "" ->
        first_desc

      Map.get(current, :location) == Map.get(next, :location) ->
        "#{String.slice(first_desc, 0..30)}... 镜头自然过渡：#{String.slice(last_desc, 0..30)}..."

      true ->
        "#{String.slice(first_desc, 0..30)}... 场景转换至：#{String.slice(last_desc, 0..30)}..."
    end
  end
end
