defmodule AstraAutoExWeb.WorkspaceLive.PipelineModal do
  use AstraAutoExWeb, :live_component

  @status_messages ["准备中...", "思考中...", "写作中...", "润色中...", "即将完成..."]

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:progress, 0)
     |> assign(:status_index, 0)
     |> assign(:elapsed_seconds, 0)
     |> assign(:timer_ref, nil)}
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
     |> assign(:elapsed_seconds, 0)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div :if={@active} class="fixed inset-0 z-50 flex items-center justify-center">
      <%!-- Backdrop --%>
      <div class="absolute inset-0 bg-black/60 backdrop-blur-sm" />

      <%!-- Modal --%>
      <div class="relative glass-card p-8 max-w-md w-full mx-4 text-center">
        <%!-- Spinner --%>
        <div class="inline-flex items-center justify-center w-20 h-20 rounded-full mb-6 relative">
          <div class="absolute inset-0 rounded-full border-2 border-transparent border-t-[var(--glass-accent-from)] border-r-[var(--glass-accent-to)] animate-spin" />
          <svg class="w-8 h-8 text-[var(--glass-accent-from)]" fill="currentColor" viewBox="0 0 24 24">
            <path d="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09zM18.259 8.715L18 9.75l-.259-1.035a3.375 3.375 0 00-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 002.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 002.455 2.456L21.75 6l-1.036.259a3.375 3.375 0 00-2.455 2.456z" />
          </svg>
        </div>

        <%!-- Status text --%>
        <p class="text-lg font-semibold text-[var(--glass-text-primary)] mb-2">
          {Enum.at(@status_messages, @status_index, "处理中...")}
        </p>

        <%!-- Progress bar --%>
        <div class="w-full h-2 bg-[var(--glass-bg-muted)] rounded-full overflow-hidden mb-3">
          <div
            class="h-full bg-gradient-to-r from-[var(--glass-accent-from)] to-[var(--glass-accent-to)] rounded-full transition-all duration-500"
            style={"width: #{@progress}%"}
          />
        </div>

        <%!-- Elapsed time --%>
        <p class="text-xs text-[var(--glass-text-tertiary)]">
          已用时 {format_elapsed(@elapsed_seconds)}
        </p>
      </div>
    </div>
    """
  end

  defp format_elapsed(seconds) do
    min = div(seconds, 60)
    sec = rem(seconds, 60)
    if min > 0, do: "#{min}分#{sec}秒", else: "#{sec}秒"
  end

  defp status_messages, do: @status_messages
end
