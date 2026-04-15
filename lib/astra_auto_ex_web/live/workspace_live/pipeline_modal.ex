defmodule AstraAutoExWeb.WorkspaceLive.PipelineModal do
  use AstraAutoExWeb, :live_component

  @pipeline_steps [
    %{key: "analyze", label: "分析故事结构", icon: "sparkles"},
    %{key: "script", label: "生成剧本", icon: "document"},
    %{key: "entities", label: "提取角色/场景", icon: "users"},
    %{key: "storyboard", label: "生成分镜", icon: "film"},
    %{key: "generate", label: "生成素材", icon: "image"}
  ]

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:progress, 0)
     |> assign(:current_step, 0)
     |> assign(:steps, @pipeline_steps)
     |> assign(:elapsed_seconds, 0)
     |> assign(:timer_ref, nil)
     |> assign(:status_idx, 0)}
  end

  @impl true
  def update(%{active: true} = assigns, socket) do
    socket = assign(socket, assigns)

    socket =
      if is_nil(socket.assigns.timer_ref) do
        {:ok, ref} = :timer.send_interval(1000, self(), {:pipeline_tick, assigns.id})
        assign(socket, :timer_ref, ref)
      else
        socket
      end

    {:ok, socket}
  end

  def update(assigns, socket) do
    if socket.assigns[:timer_ref] do
      :timer.cancel(socket.assigns.timer_ref)
    end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:timer_ref, nil)
     |> assign(:progress, 0)
     |> assign(:current_step, 0)
     |> assign(:elapsed_seconds, 0)
     |> assign(:status_idx, 0)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div :if={@active} class="fixed inset-0 z-50 flex items-center justify-center">
        <%!-- Backdrop with subtle animated particles --%>
        <div class="absolute inset-0 bg-black/70 backdrop-blur-md" />

        <%!-- Modal card --%>
        <div class="relative glass-card p-8 max-w-lg w-full mx-4 overflow-hidden">
          <%!-- Animated gradient border --%>
          <div
            class="absolute inset-0 rounded-2xl p-px bg-gradient-to-r from-[var(--glass-accent-from)] via-transparent to-[var(--glass-accent-to)] opacity-30 animate-pulse"
            style="animation-duration: 3s"
          />

          <div class="relative">
            <%!-- Header with spinning logo --%>
            <div class="text-center mb-8">
              <div class="inline-flex items-center justify-center w-16 h-16 rounded-2xl mb-4 relative bg-gradient-to-br from-[var(--glass-accent-from)]/20 to-[var(--glass-accent-to)]/20">
                <div
                  class="absolute inset-0 rounded-2xl border border-[var(--glass-accent-from)]/30 animate-spin"
                  style="animation-duration: 8s"
                />
                <svg
                  class="w-7 h-7 text-[var(--glass-accent-from)]"
                  fill="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path d="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09zM18.259 8.715L18 9.75l-.259-1.035a3.375 3.375 0 00-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 002.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 002.455 2.456L21.75 6l-1.036.259a3.375 3.375 0 00-2.455 2.456z" />
                </svg>
              </div>
              <h3 class="text-xl font-bold text-[var(--glass-text-primary)]">AI 创作管线</h3>
              <p class="text-xs text-[var(--glass-text-tertiary)] mt-1">正在为您生成精彩内容</p>
            </div>

            <%!-- Pipeline steps --%>
            <div class="space-y-3 mb-8">
              <%= for {step, idx} <- Enum.with_index(@steps) do %>
                <div class={[
                  "flex items-center gap-3 px-4 py-2.5 rounded-xl transition-all duration-500",
                  cond do
                    idx < @current_step ->
                      "bg-green-500/10"

                    idx == @current_step ->
                      "bg-[var(--glass-accent-from)]/10 ring-1 ring-[var(--glass-accent-from)]/20"

                    true ->
                      "opacity-40"
                  end
                ]}>
                  <%!-- Step indicator --%>
                  <div class={[
                    "w-7 h-7 rounded-lg flex items-center justify-center flex-shrink-0 transition-all",
                    cond do
                      idx < @current_step ->
                        "bg-green-500/20 text-green-400"

                      idx == @current_step ->
                        "bg-[var(--glass-accent-from)]/20 text-[var(--glass-accent-from)]"

                      true ->
                        "bg-[var(--glass-bg-muted)] text-[var(--glass-text-tertiary)]"
                    end
                  ]}>
                    <%= if idx < @current_step do %>
                      <svg
                        class="w-4 h-4"
                        fill="none"
                        stroke="currentColor"
                        stroke-width="2"
                        viewBox="0 0 24 24"
                      >
                        <path d="M5 13l4 4L19 7" />
                      </svg>
                    <% else %>
                      <%= if idx == @current_step do %>
                        <div class="w-3 h-3 rounded-full bg-[var(--glass-accent-from)] animate-pulse" />
                      <% else %>
                        <span class="text-xs font-medium">{idx + 1}</span>
                      <% end %>
                    <% end %>
                  </div>

                  <%!-- Step label --%>
                  <span class={[
                    "text-sm font-medium transition-colors",
                    cond do
                      idx < @current_step -> "text-green-400"
                      idx == @current_step -> "text-[var(--glass-text-primary)]"
                      true -> "text-[var(--glass-text-tertiary)]"
                    end
                  ]}>
                    {step.label}
                  </span>

                  <%!-- Status --%>
                  <span
                    :if={idx < @current_step}
                    class="ml-auto text-[10px] text-green-400 font-medium"
                  >
                    完成
                  </span>
                  <span
                    :if={idx == @current_step}
                    class="ml-auto text-[10px] text-[var(--glass-accent-from)] font-medium animate-pulse"
                  >
                    进行中...
                  </span>
                </div>
              <% end %>
            </div>

            <%!-- Progress bar --%>
            <div class="w-full h-1.5 bg-[var(--glass-bg-muted)] rounded-full overflow-hidden mb-4">
              <div
                class="h-full bg-gradient-to-r from-[var(--glass-accent-from)] to-[var(--glass-accent-to)] rounded-full transition-all duration-700 ease-out"
                style={"width: #{@progress}%"}
              />
            </div>

            <%!-- Status message --%>
            <div
              :if={@status_messages != []}
              class="text-center mb-4"
            >
              <p class="text-xs text-[var(--glass-accent-from)] animate-pulse font-medium">
                {Enum.at(@status_messages, @status_idx, "")}
              </p>
            </div>
            <%!-- Footer --%>
            <div class="flex items-center justify-between">
              <p class="text-xs text-[var(--glass-text-tertiary)]">
                已用时 {format_elapsed(@elapsed_seconds)}
              </p>
              <p class="text-xs text-[var(--glass-text-tertiary)]">
                {@progress}%
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("pipeline_tick", _, socket) do
    elapsed = socket.assigns.elapsed_seconds + 1
    # Advance step every ~10 seconds, cap progress
    current_step = min(div(elapsed, 10), length(socket.assigns.steps) - 1)
    progress = min(elapsed * 2, 95)

    # Cycle through status messages for current step
    status_msgs = socket.assigns.status_messages || []

    status_idx =
      if status_msgs != [],
        do: rem(div(elapsed, 3), length(status_msgs)),
        else: 0

    {:noreply,
     socket
     |> assign(:elapsed_seconds, elapsed)
     |> assign(:current_step, current_step)
     |> assign(:progress, progress)
     |> assign(:status_idx, status_idx)}
  end

  defp format_elapsed(seconds) do
    min = div(seconds, 60)
    sec = rem(seconds, 60)
    if min > 0, do: "#{min}分#{sec}秒", else: "#{sec}秒"
  end
end
