defmodule AstraAutoExWeb.ShortDramaLive do
  @moduledoc """
  Short-drama 8-step pipeline UI.

  Each card represents one step:
    1. 选题定位 (sd_topic_selection)
    2. 故事大纲 (sd_story_outline)
    3. 角色开发 (sd_character_dev)
    4. 分集目录 (sd_episode_directory)
    5. 分集剧本 (sd_episode_script)
    6. 质量自检 (sd_quality_review)
    7. 合规审核 (sd_compliance_check)
    8. 出海适配 (sd_overseas_adapt)

  Each step is backed by `AstraAutoEx.Workers.Handlers.ShortDrama` and can be
  triggered independently. The page subscribes to the project's PubSub topic
  to reflect live task progress.
  """

  use AstraAutoExWeb, :live_view

  alias AstraAutoEx.{Projects, Tasks}

  @steps [
    %{type: "sd_topic_selection", title: "选题定位", icon: "🎯", desc: "赛道分析 + 爆款套路 + 差异化定位"},
    %{type: "sd_story_outline", title: "故事大纲", icon: "📖", desc: "三幕结构 + 核心冲突 + 主线副线"},
    %{type: "sd_character_dev", title: "角色开发", icon: "👥", desc: "主角小传 + 人物弧光 + 角色关系图"},
    %{type: "sd_episode_directory", title: "分集目录", icon: "📋", desc: "80-100 集分集标题 + 单集核心事件"},
    %{type: "sd_episode_script", title: "分集剧本", icon: "✍️", desc: "场景编号 + 对白 + 动作描述 + 转场"},
    %{type: "sd_quality_review", title: "质量自检", icon: "🔍", desc: "钩子密度 + 爽点检测 + 反转评估"},
    %{type: "sd_compliance_check", title: "合规审核", icon: "🛡️", desc: "敏感词扫描 + 政策红线检查"},
    %{type: "sd_overseas_adapt", title: "出海适配", icon: "🌐", desc: "文化转译 + 台词本地化 + 字幕优化"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    projects = Projects.list_projects(user.id)
    default_project = List.first(projects)

    if connected?(socket) and default_project do
      Phoenix.PubSub.subscribe(AstraAutoEx.PubSub, "project:#{default_project.id}")
    end

    tasks_by_type = load_tasks(default_project)

    {:ok,
     socket
     |> assign(:projects, projects)
     |> assign(:selected_project, default_project)
     |> assign(:topic_keyword, "")
     |> assign(:steps, @steps)
     |> assign(:tasks_by_type, tasks_by_type)
     |> assign(:expanded, MapSet.new())
     |> assign(:page_title, "短剧创作")}
  end

  # Dependency chain: steps 1-5 are sequential; 6-8 unlock once step 5 is done.
  @prerequisites %{
    "sd_topic_selection" => nil,
    "sd_story_outline" => "sd_topic_selection",
    "sd_character_dev" => "sd_story_outline",
    "sd_episode_directory" => "sd_character_dev",
    "sd_episode_script" => "sd_episode_directory",
    "sd_quality_review" => "sd_episode_script",
    "sd_compliance_check" => "sd_episode_script",
    "sd_overseas_adapt" => "sd_episode_script"
  }

  defp step_locked?(type, tasks_by_type) do
    case Map.get(@prerequisites, type) do
      nil ->
        false

      prereq ->
        case Map.get(tasks_by_type, prereq) do
          %{status: "completed"} -> false
          _ -> true
        end
    end
  end

  defp format_result(nil), do: ""

  defp format_result(result) when is_map(result) do
    # Handle the common handler output shape %{"step" => ..., "result" => %{"raw" => "..."}}
    case result do
      %{"result" => %{"raw" => raw}} when is_binary(raw) ->
        raw |> String.slice(0..1999)

      %{"raw" => raw} when is_binary(raw) ->
        raw |> String.slice(0..1999)

      _ ->
        Jason.encode!(result, pretty: true) |> String.slice(0..1999)
    end
  end

  defp format_result(other), do: inspect(other) |> String.slice(0..1999)

  @impl true
  def handle_event("select_project", %{"project_id" => project_id}, socket) do
    project = Enum.find(socket.assigns.projects, &(to_string(&1.id) == project_id))

    if connected?(socket) and project do
      Phoenix.PubSub.subscribe(AstraAutoEx.PubSub, "project:#{project.id}")
    end

    {:noreply,
     socket
     |> assign(:selected_project, project)
     |> assign(:tasks_by_type, load_tasks(project))}
  end

  def handle_event("update_topic", %{"topic_keyword" => keyword}, socket) do
    {:noreply, assign(socket, :topic_keyword, keyword)}
  end

  def handle_event("toggle_result", %{"type" => step_type}, socket) do
    expanded = socket.assigns.expanded

    new_expanded =
      if MapSet.member?(expanded, step_type),
        do: MapSet.delete(expanded, step_type),
        else: MapSet.put(expanded, step_type)

    {:noreply, assign(socket, :expanded, new_expanded)}
  end

  def handle_event("run_step", %{"type" => step_type}, socket) do
    project = socket.assigns.selected_project

    cond do
      is_nil(project) ->
        {:noreply, put_flash(socket, :error, "请先选择或创建一个项目")}

      step_type == "sd_topic_selection" and String.trim(socket.assigns.topic_keyword) == "" ->
        {:noreply, put_flash(socket, :error, "请输入选题关键词")}

      true ->
        user_id = socket.assigns.current_scope.user.id

        payload =
          %{"project_id" => project.id}
          |> maybe_put("topic_keyword", socket.assigns.topic_keyword)

        case Tasks.create_task(%{
               user_id: user_id,
               project_id: project.id,
               type: step_type,
               target_type: "project",
               target_id: to_string(project.id),
               payload: payload
             }) do
          {:ok, _task} ->
            {:noreply,
             socket
             |> assign(:tasks_by_type, load_tasks(project))
             |> put_flash(:info, "已启动：#{step_title(step_type)}")}

          {:error, _cs} ->
            {:noreply, put_flash(socket, :error, "启动失败")}
        end
    end
  end

  @sd_types ~w(sd_topic_selection sd_story_outline sd_character_dev sd_episode_directory sd_episode_script sd_quality_review sd_compliance_check sd_overseas_adapt)

  @impl true
  def handle_info({:task_event, %{task_type: type}}, socket) do
    # Any event for a short-drama task type → refresh
    if type in @sd_types and socket.assigns.selected_project do
      {:noreply, assign(socket, :tasks_by_type, load_tasks(socket.assigns.selected_project))}
    else
      {:noreply, socket}
    end
  end

  def handle_info(_other, socket), do: {:noreply, socket}

  # ── Helpers ──

  defp maybe_put(map, _k, ""), do: map
  defp maybe_put(map, k, v), do: Map.put(map, k, v)

  defp load_tasks(nil), do: %{}

  defp load_tasks(project) do
    Tasks.list_project_tasks(project.id, [])
    |> Enum.filter(&String.starts_with?(&1.type, "sd_"))
    |> Enum.group_by(& &1.type)
    |> Map.new(fn {type, tasks} -> {type, Enum.max_by(tasks, & &1.inserted_at)} end)
  end

  defp step_title(type) do
    @steps |> Enum.find(&(&1.type == type)) |> Map.get(:title, type)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="min-h-[calc(100vh-52px)] max-w-6xl mx-auto px-6 py-8">
        <%!-- Header --%>
        <div class="mb-6">
          <h1 class="text-2xl font-bold text-[var(--glass-text-primary)] mb-1">短剧创作工作台</h1>
          <p class="text-sm text-[var(--glass-text-tertiary)]">
            8 步全流程：从选题到出海，每步独立可跑，结果持久化
          </p>
        </div>

        <%!-- Project + keyword bar --%>
        <div class="glass-surface rounded-2xl p-5 mb-6 flex flex-col sm:flex-row items-start sm:items-center gap-4">
          <div class="flex items-center gap-2 flex-1 min-w-0">
            <span class="text-xs text-[var(--glass-text-tertiary)] whitespace-nowrap">目标项目</span>
            <select
              phx-change="select_project"
              name="project_id"
              class="glass-input text-sm py-1.5 pl-2 pr-6 flex-1 min-w-0"
            >
              <option :if={@projects == []} value="">请先创建项目</option>
              <%= for p <- @projects do %>
                <option value={p.id} selected={@selected_project && @selected_project.id == p.id}>
                  {String.slice(p.name || "未命名", 0..30)}
                </option>
              <% end %>
            </select>
          </div>

          <div class="flex items-center gap-2 flex-1 min-w-0 sm:border-l sm:border-[var(--glass-stroke-soft)] sm:pl-4">
            <span class="text-xs text-[var(--glass-text-tertiary)] whitespace-nowrap">选题关键词</span>
            <form phx-change="update_topic" class="flex-1 min-w-0">
              <input
                type="text"
                name="topic_keyword"
                value={@topic_keyword}
                phx-debounce="300"
                placeholder="例：现代霸总 / 古代修仙 / 重生复仇"
                class="glass-input text-sm w-full py-1.5 px-2"
              />
            </form>
          </div>
        </div>

        <%!-- Step grid --%>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <%= for {step, idx} <- Enum.with_index(@steps) do %>
            <% task = Map.get(@tasks_by_type, step.type) %>
            <% locked = step_locked?(step.type, @tasks_by_type) %>
            <div class={[
              "glass-surface rounded-xl p-5 transition-all",
              task && task.status == "processing" &&
                "ring-2 ring-[var(--glass-accent-from)] ring-offset-0",
              locked && "opacity-60"
            ]}>
              <div class="flex items-start gap-3">
                <div class="w-10 h-10 rounded-lg bg-[var(--glass-bg-muted)] flex items-center justify-center flex-shrink-0 text-xl">
                  {step.icon}
                </div>

                <div class="flex-1 min-w-0">
                  <div class="flex items-center gap-2 mb-1">
                    <span class="text-[10px] font-mono text-[var(--glass-text-tertiary)]">
                      {String.pad_leading(to_string(idx + 1), 2, "0")}
                    </span>
                    <h3 class="text-sm font-bold text-[var(--glass-text-primary)]">
                      {step.title}
                    </h3>
                    <.status_chip task={task} />
                    <span
                      :if={locked}
                      class="text-[10px] px-2 py-0.5 rounded-full bg-[var(--glass-bg-muted)] text-[var(--glass-text-tertiary)]"
                      title="请先完成前置步骤"
                    >
                      🔒 锁定
                    </span>
                  </div>

                  <p class="text-xs text-[var(--glass-text-tertiary)] mb-3 leading-snug">
                    {step.desc}
                  </p>

                  <div class="flex items-center gap-2 mb-3">
                    <button
                      phx-click="run_step"
                      phx-value-type={step.type}
                      disabled={(task && task.status == "processing") || locked}
                      class="glass-btn glass-btn-primary text-xs py-1.5 px-3 disabled:opacity-40 disabled:cursor-not-allowed"
                    >
                      {if task && task.status == "completed", do: "重新运行", else: "运行"}
                    </button>

                    <span
                      :if={task && task.status == "processing"}
                      class="text-[10px] text-[var(--glass-text-tertiary)]"
                    >
                      进度 {task.progress}%
                    </span>

                    <span
                      :if={task && task.status == "failed"}
                      class="text-[10px] text-red-400"
                      title={task.error_message || ""}
                    >
                      失败
                    </span>

                    <button
                      :if={task && task.status == "completed" && task.result}
                      type="button"
                      phx-click="toggle_result"
                      phx-value-type={step.type}
                      class="text-[10px] ml-auto text-[var(--glass-accent-from)] hover:underline"
                    >
                      {if MapSet.member?(@expanded, step.type), do: "收起结果 ▲", else: "查看结果 ▼"}
                    </button>
                  </div>

                  <%!-- Result preview (collapsed by default) --%>
                  <div
                    :if={task && MapSet.member?(@expanded, step.type) && task.result}
                    class="mt-2 p-3 rounded-lg bg-[var(--glass-bg-muted)] text-[11px] text-[var(--glass-text-secondary)] font-mono leading-relaxed max-h-60 overflow-y-auto whitespace-pre-wrap"
                  >
                    {format_result(task.result)}
                  </div>
                </div>
              </div>
            </div>
          <% end %>
        </div>

        <%!-- Footer hint --%>
        <div class="mt-8 text-center text-xs text-[var(--glass-text-tertiary)]">
          提示：步骤 1-5 是递进依赖（需顺序运行）；6-8 可在任意步骤完成后独立触发。
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp status_chip(assigns) do
    ~H"""
    <span
      :if={@task}
      class={[
        "text-[10px] px-2 py-0.5 rounded-full font-medium",
        @task.status == "completed" && "bg-green-500/15 text-green-400",
        @task.status == "processing" && "bg-blue-500/15 text-blue-400",
        @task.status == "failed" && "bg-red-500/15 text-red-400",
        @task.status == "queued" && "bg-[var(--glass-bg-muted)] text-[var(--glass-text-tertiary)]"
      ]}
    >
      {status_label(@task.status)}
    </span>
    """
  end

  defp status_label("completed"), do: "已完成"
  defp status_label("processing"), do: "运行中"
  defp status_label("failed"), do: "失败"
  defp status_label("queued"), do: "排队中"
  defp status_label(other), do: other
end
