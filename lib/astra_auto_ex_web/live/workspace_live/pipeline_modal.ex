defmodule AstraAutoExWeb.WorkspaceLive.PipelineModal do
  @moduledoc """
  Pipeline execution modal — wide two-column layout with step list,
  AI streaming output, and real-time progress tracking.
  """
  use AstraAutoExWeb, :live_component

  @default_steps [
    %{key: "analyze", label: "分析故事结构", status: :pending, elapsed_seconds: 0, progress: 0},
    %{key: "script", label: "生成剧本", status: :pending, elapsed_seconds: 0, progress: 0},
    %{key: "entities", label: "提取角色/场景", status: :pending, elapsed_seconds: 0, progress: 0},
    %{key: "storyboard", label: "生成分镜", status: :pending, elapsed_seconds: 0, progress: 0},
    %{key: "generate", label: "生成素材", status: :pending, elapsed_seconds: 0, progress: 0}
  ]

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok,
     socket
     |> assign(:elapsed_seconds, 0)
     |> assign(:timer_ref, nil)
     |> assign(:status_idx, 0)}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(%{active: true} = assigns, socket) do
    socket = assign(socket, assigns)

    socket =
      if is_nil(socket.assigns[:timer_ref]) do
        {:ok, ref} = :timer.send_interval(1000, self(), {:pipeline_tick, assigns.id})
        assign(socket, :timer_ref, ref)
      else
        socket
      end

    {:ok, apply_defaults(socket)}
  end

  def update(assigns, socket) do
    if socket.assigns[:timer_ref], do: :timer.cancel(socket.assigns.timer_ref)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:timer_ref, nil)
     |> assign(:elapsed_seconds, 0)
     |> assign(:status_idx, 0)
     |> apply_defaults()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div :if={@active} class="fixed inset-0 z-50 flex items-center justify-center">
        <%!-- Backdrop --%>
        <div class="absolute inset-0 bg-black/50 backdrop-blur-sm" />

        <%!-- Modal card — max-w-4xl, light background --%>
        <div class="relative w-full max-w-4xl mx-4 rounded-2xl shadow-2xl overflow-hidden
                    bg-white/95 dark:bg-[var(--glass-bg-surface)] border border-gray-200 dark:border-white/10">
          <%!-- === Header === --%>
          <div class="flex items-start justify-between px-6 pt-5 pb-3">
            <div class="flex items-center gap-3">
              <span class="inline-flex items-center px-2.5 py-1 rounded-lg text-xs font-semibold
                           bg-blue-100 text-blue-700 dark:bg-blue-500/20 dark:text-blue-300">
                阶段 {@current_step_index + 1}/{@total_steps}
              </span>
              <span class="text-sm text-gray-500 dark:text-[var(--glass-text-tertiary)]">
                {@current_step_label}
              </span>
            </div>
            <div class="flex items-center gap-2">
              <button
                phx-click="stop_pipeline"
                class="px-3 py-1.5 rounded-lg text-xs font-medium
                       bg-red-50 text-red-600 hover:bg-red-100
                       dark:bg-red-500/10 dark:text-red-400 dark:hover:bg-red-500/20
                       transition-colors"
              >
                停止
              </button>
              <button
                phx-click="minimize_pipeline"
                class="px-3 py-1.5 rounded-lg text-xs font-medium
                       bg-gray-100 text-gray-600 hover:bg-gray-200
                       dark:bg-white/5 dark:text-[var(--glass-text-secondary)] dark:hover:bg-white/10
                       transition-colors"
              >
                最小化
              </button>
            </div>
          </div>

          <%!-- Pipeline title + subtitle --%>
          <div class="px-6 pb-3">
            <h3 class="text-lg font-bold text-gray-900 dark:text-[var(--glass-text-primary)]">
              {@pipeline_name}
            </h3>
            <p class="text-sm text-gray-500 dark:text-[var(--glass-text-tertiary)] mt-0.5">
              {@current_step_label}
              <span
                :if={step_running?(@steps, @current_step_index)}
                class="text-blue-500 animate-pulse ml-2"
              >
                模型正在输出...
              </span>
            </p>
          </div>

          <%!-- Overall progress bar --%>
          <div class="mx-6 mb-4">
            <div class="w-full h-2 bg-gray-100 dark:bg-white/5 rounded-full overflow-hidden">
              <div
                class="h-full rounded-full bg-gradient-to-r from-blue-500 to-blue-400 transition-all duration-700 ease-out"
                style={"width: #{overall_progress(@steps, @total_steps)}%"}
              />
            </div>
          </div>

          <%!-- === Two-column body === --%>
          <div class="flex border-t border-gray-200 dark:border-white/10" style="min-height: 340px;">
            <%!-- Left column — step list --%>
            <div
              class="w-1/3 border-r border-gray-200 dark:border-white/10 p-4 space-y-2 overflow-y-auto"
              style="max-height: 340px;"
            >
              <%= for {step, idx} <- Enum.with_index(@steps) do %>
                <.step_card step={step} idx={idx} />
              <% end %>
            </div>

            <%!-- Right column — AI streaming output --%>
            <div class="w-2/3 flex flex-col">
              <div class="px-4 py-2.5 border-b border-gray-200 dark:border-white/10">
                <span class="text-xs font-semibold text-gray-600 dark:text-[var(--glass-text-secondary)]">
                  AI 实时输出 · {@current_step_label}
                </span>
              </div>
              <div
                id="pipeline-stream-output"
                phx-hook="ScrollBottom"
                class="flex-1 p-4 overflow-y-auto font-mono text-sm leading-relaxed
                       text-gray-700 dark:text-[var(--glass-text-secondary)]
                       whitespace-pre-wrap break-words"
                style="max-height: 296px;"
              >
                <%= if @streaming_output && @streaming_output != "" do %>
                  {@streaming_output}
                <% else %>
                  <span class="text-gray-400 dark:text-[var(--glass-text-tertiary)] italic">
                    等待 AI 输出...
                  </span>
                <% end %>
              </div>
            </div>
          </div>

          <%!-- === Footer status bar === --%>
          <div class="flex items-center justify-between px-6 py-3
                      border-t border-gray-200 dark:border-white/10
                      bg-gray-50 dark:bg-white/[0.02]">
            <p class="text-xs text-gray-500 dark:text-[var(--glass-text-tertiary)]">
              已用时 {format_elapsed(@elapsed_seconds)}
            </p>
            <span class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-medium
                         bg-blue-50 text-blue-600 dark:bg-blue-500/10 dark:text-blue-400">
              <span class="w-1.5 h-1.5 rounded-full bg-blue-500 animate-pulse" />
              {@active_task_count} 个任务运行中
            </span>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ── Step card sub-component ──────────────────────────────────────

  defp step_card(assigns) do
    ~H"""
    <div class={[
      "rounded-xl px-3 py-2.5 transition-all duration-300",
      step_card_classes(@step.status)
    ]}>
      <div class="flex items-center justify-between mb-1">
        <span class={[
          "text-sm font-medium",
          step_label_color(@step.status)
        ]}>
          {@idx + 1}. {@step.label}
        </span>
        <.step_badge status={@step.status} elapsed={@step.elapsed_seconds} />
      </div>
      <div class="w-full h-1 bg-gray-200 dark:bg-white/10 rounded-full overflow-hidden">
        <div
          class={[
            "h-full rounded-full transition-all duration-500",
            step_bar_color(@step.status)
          ]}
          style={"width: #{step_progress(@step)}%"}
        />
      </div>
    </div>
    """
  end

  defp step_badge(%{status: :running} = assigns) do
    ~H"""
    <span class="text-[10px] font-semibold px-1.5 py-0.5 rounded bg-blue-100 text-blue-600
                 dark:bg-blue-500/20 dark:text-blue-400 animate-pulse">
      进行中
    </span>
    """
  end

  defp step_badge(%{status: :completed} = assigns) do
    ~H"""
    <span class="text-[10px] font-semibold px-1.5 py-0.5 rounded
                 bg-green-100 text-green-600 dark:bg-green-500/20 dark:text-green-400">
      已完成 {@elapsed}s
    </span>
    """
  end

  defp step_badge(assigns) do
    ~H"""
    <span class="text-[10px] text-gray-400 dark:text-[var(--glass-text-tertiary)]">
      待开始
    </span>
    """
  end

  # ── Helpers ──────────────────────────────────────────────────────

  @impl true
  def handle_event("pipeline_tick", _, socket) do
    elapsed = socket.assigns.elapsed_seconds + 1
    steps = socket.assigns[:steps] || @default_steps
    total = length(steps)
    current = min(div(elapsed, 10), total - 1)

    updated_steps =
      steps
      |> Enum.with_index()
      |> Enum.map(fn {step, idx} ->
        cond do
          idx < current -> %{step | status: :completed, progress: 100, elapsed_seconds: 10}
          idx == current -> %{step | status: :running, progress: min(rem(elapsed, 10) * 10, 95)}
          true -> step
        end
      end)

    status_msgs = socket.assigns[:status_messages] || []
    status_idx = if status_msgs != [], do: rem(div(elapsed, 3), length(status_msgs)), else: 0

    current_label =
      case Enum.at(updated_steps, current) do
        %{label: l} -> l
        _ -> ""
      end

    {:noreply,
     socket
     |> assign(:elapsed_seconds, elapsed)
     |> assign(:current_step_index, current)
     |> assign(:steps, updated_steps)
     |> assign(:current_step_label, current_label)
     |> assign(:status_idx, status_idx)}
  end

  defp apply_defaults(socket) do
    a = socket.assigns
    steps = Map.get(a, :steps, @default_steps)
    total = Map.get(a, :total_steps, length(steps))
    current_idx = Map.get(a, :current_step_index, 0)

    current_label =
      Map.get_lazy(a, :current_step_label, fn ->
        case Enum.at(steps, current_idx) do
          %{label: l} -> l
          _ -> ""
        end
      end)

    socket
    |> assign_new(:pipeline_name, fn -> "AI 创作管线" end)
    |> assign(:steps, steps)
    |> assign(:total_steps, total)
    |> assign(:current_step_index, current_idx)
    |> assign(:current_step_label, current_label)
    |> assign_new(:streaming_output, fn -> "" end)
    |> assign_new(:active_task_count, fn -> 1 end)
  end

  @spec format_elapsed(non_neg_integer()) :: String.t()
  defp format_elapsed(seconds) do
    min = div(seconds, 60)
    sec = rem(seconds, 60)
    if min > 0, do: "#{min}分#{sec}秒", else: "#{sec}秒"
  end

  @spec overall_progress(list(), non_neg_integer()) :: non_neg_integer()
  defp overall_progress(steps, total) when total > 0 do
    completed = Enum.count(steps, &(&1.status == :completed))
    running_extra = if Enum.any?(steps, &(&1.status == :running)), do: 0.5, else: 0
    round((completed + running_extra) / total * 100)
  end

  defp overall_progress(_, _), do: 0

  defp step_running?(steps, idx) do
    case Enum.at(steps, idx) do
      %{status: :running} -> true
      _ -> false
    end
  end

  defp step_progress(%{status: :completed}), do: 100
  defp step_progress(%{progress: p}) when is_number(p), do: p
  defp step_progress(_), do: 0

  defp step_card_classes(:running),
    do: "border border-blue-300 dark:border-blue-500/40 bg-blue-50 dark:bg-blue-500/5"

  defp step_card_classes(:completed),
    do: "border border-green-200 dark:border-green-500/20 bg-green-50/50 dark:bg-green-500/5"

  defp step_card_classes(_),
    do: "border border-gray-200 dark:border-white/5 bg-gray-50 dark:bg-white/[0.02]"

  defp step_label_color(:running), do: "text-blue-700 dark:text-blue-300"
  defp step_label_color(:completed), do: "text-green-700 dark:text-green-400"
  defp step_label_color(_), do: "text-gray-400 dark:text-[var(--glass-text-tertiary)]"

  defp step_bar_color(:running), do: "bg-blue-500 animate-pulse"
  defp step_bar_color(:completed), do: "bg-green-500"
  defp step_bar_color(_), do: "bg-gray-300 dark:bg-white/10"
end
