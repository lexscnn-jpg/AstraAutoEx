defmodule AstraAutoExWeb.ProjectsLive.Index do
  use AstraAutoExWeb, :live_view

  alias AstraAutoEx.Projects
  alias AstraAutoEx.Production

  @page_size 8

  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_scope.user.id
    projects = Projects.list_projects(user_id)

    {:ok,
     socket
     |> assign(:page_title, dgettext("projects", "All Projects"))
     |> assign(:projects, projects)
     |> assign(:filtered, projects)
     |> assign(:search, "")
     |> assign(:page, 1)
     |> assign(:confirm_delete, nil)}
  end

  @impl true
  def render(assigns) do
    page_projects = paginate(assigns.filtered, assigns.page)
    total_pages = max(1, ceil(length(assigns.filtered) / @page_size))
    assigns = assign(assigns, page_projects: page_projects, total_pages: total_pages)

    ~H"""
    <div class="glass-page min-h-screen">
      <div class="max-w-6xl mx-auto px-6 py-8">
        <div class="flex items-center justify-between mb-8">
          <div>
            <h1 class="text-2xl font-bold text-[var(--glass-text-primary)]">
              {dgettext("projects", "All Projects")}
            </h1>
            
            <p class="text-sm text-[var(--glass-text-tertiary)] mt-1">共 {length(@projects)} 个项目</p>
          </div>
           <a href={~p"/home"} class="glass-btn glass-btn-primary px-4 py-2 text-sm">+ 新建项目</a>
        </div>
        <!-- Search -->
        <div class="mb-6">
          <input
            type="text"
            value={@search}
            phx-change="search"
            phx-debounce="300"
            name="q"
            placeholder={dgettext("projects", "Search projects...")}
            class="glass-input w-full max-w-md text-sm"
          />
        </div>
        <!-- Project Grid -->
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
          <%= for project <- @page_projects do %>
            <div class="glass-card p-5 group hover:ring-1 hover:ring-[var(--glass-accent-from)]/30 transition-all">
              <a href={~p"/projects/#{project.id}"} class="block">
                <h3 class="text-sm font-semibold text-[var(--glass-text-primary)] truncate">
                  {project.name}
                </h3>
                
                <p class="text-xs text-[var(--glass-text-tertiary)] mt-1 line-clamp-2 min-h-[2rem]">
                  {project.description || "无描述"}
                </p>
              </a>
              <!-- Stats -->
              <div class="flex items-center gap-3 mt-3 text-xs text-[var(--glass-text-tertiary)]">
                <span title="剧集">📺 {episode_count(project)}</span>
                <span title="图片">🖼 {image_count(project)}</span>
                <span title="视频">🎬 {video_count(project)}</span>
              </div>
              <!-- Completion bar -->
              <div class="mt-3">
                <div class="flex items-center justify-between text-xs text-[var(--glass-text-tertiary)] mb-1">
                  <span>完成度</span> <span>{completion(project)}%</span>
                </div>
                
                <div class="w-full h-1.5 bg-[var(--glass-bg-muted)] rounded-full overflow-hidden">
                  <div
                    class="h-full bg-gradient-to-r from-[var(--glass-accent-from)] to-[var(--glass-accent-to)] rounded-full transition-all"
                    style={"width: #{completion(project)}%"}
                  />
                </div>
              </div>
              <!-- Footer -->
              <div class="flex items-center justify-between mt-3 pt-3 border-t border-[var(--glass-stroke-base)]">
                <span class="text-xs text-[var(--glass-text-tertiary)]">
                  {format_time(project.updated_at)}
                </span>
                <button
                  type="button"
                  phx-click="confirm_delete"
                  phx-value-id={project.id}
                  class="opacity-0 group-hover:opacity-100 text-xs text-red-400 hover:text-red-300 transition-all"
                >
                  删除
                </button>
              </div>
            </div>
          <% end %>
        </div>
        
        <%= if @page_projects == [] do %>
          <div class="text-center py-16 text-[var(--glass-text-tertiary)]">
            <div class="text-4xl mb-3">📂</div>
            
            <p>暂无项目</p>
            
            <a href={~p"/home"} class="glass-btn glass-btn-primary px-6 py-2 mt-4 inline-block">
              创建第一个项目
            </a>
          </div>
        <% end %>
        <!-- Pagination -->
        <%= if @total_pages > 1 do %>
          <div class="flex items-center justify-center gap-2 mt-8">
            <button
              type="button"
              phx-click="page"
              phx-value-page={max(1, @page - 1)}
              disabled={@page == 1}
              class="glass-btn px-3 py-1.5 text-sm disabled:opacity-30"
            >
              ←
            </button>
            <span class="text-sm text-[var(--glass-text-secondary)]">{@page} / {@total_pages}</span>
            <button
              type="button"
              phx-click="page"
              phx-value-page={min(@total_pages, @page + 1)}
              disabled={@page == @total_pages}
              class="glass-btn px-3 py-1.5 text-sm disabled:opacity-30"
            >
              →
            </button>
          </div>
        <% end %>
        <!-- Delete Confirmation -->
        <%= if @confirm_delete do %>
          <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm">
            <div class="glass-card p-6 max-w-sm mx-4">
              <h3 class="text-lg font-semibold text-[var(--glass-text-primary)] mb-2">确认删除</h3>
              
              <p class="text-sm text-[var(--glass-text-secondary)] mb-4">确定要删除此项目吗？此操作不可撤销。</p>
              
              <div class="flex justify-end gap-3">
                <button
                  type="button"
                  phx-click="cancel_delete"
                  class="glass-btn px-4 py-2 text-sm"
                >
                  取消
                </button>
                <button
                  type="button"
                  phx-click="delete_project"
                  phx-value-id={@confirm_delete}
                  class="px-4 py-2 text-sm bg-red-500/20 text-red-400 rounded-lg hover:bg-red-500/30"
                >
                  删除
                </button>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    filtered = filter_projects(socket.assigns.projects, query)
    {:noreply, assign(socket, filtered: filtered, search: query, page: 1)}
  end

  def handle_event("page", %{"page" => page}, socket) do
    {:noreply, assign(socket, :page, String.to_integer(page))}
  end

  def handle_event("confirm_delete", %{"id" => id}, socket) do
    {:noreply, assign(socket, :confirm_delete, id)}
  end

  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, :confirm_delete, nil)}
  end

  def handle_event("delete_project", %{"id" => id}, socket) do
    user_id = socket.assigns.current_scope.user.id

    case Projects.get_project!(id, user_id) |> Projects.delete_project() do
      {:ok, _} ->
        projects = Projects.list_projects(user_id)

        {:noreply,
         socket
         |> assign(:projects, projects)
         |> assign(:filtered, filter_projects(projects, socket.assigns.search))
         |> assign(:confirm_delete, nil)
         |> put_flash(:info, "项目已删除")}

      {:error, _} ->
        {:noreply,
         socket
         |> assign(:confirm_delete, nil)
         |> put_flash(:error, "删除失败")}
    end
  end

  defp paginate(items, page) do
    items
    |> Enum.drop((page - 1) * @page_size)
    |> Enum.take(@page_size)
  end

  defp filter_projects(projects, "") do
    projects
  end

  defp filter_projects(projects, query) do
    q = String.downcase(query)

    Enum.filter(projects, fn p ->
      String.contains?(String.downcase(p.name || ""), q) or
        String.contains?(String.downcase(p.description || ""), q)
    end)
  end

  defp episode_count(project) do
    try do
      Production.list_episodes(project.id) |> length()
    rescue
      _ -> 0
    end
  end

  defp image_count(project) do
    try do
      Production.list_episodes(project.id)
      |> Enum.flat_map(fn ep ->
        Production.list_storyboards(ep.id)
        |> Enum.flat_map(&Production.list_panels(&1.id))
      end)
      |> Enum.count(&(&1.image_url != nil))
    rescue
      _ -> 0
    end
  end

  defp video_count(project) do
    try do
      Production.list_episodes(project.id)
      |> Enum.flat_map(fn ep ->
        Production.list_storyboards(ep.id)
        |> Enum.flat_map(&Production.list_panels(&1.id))
      end)
      |> Enum.count(&(&1.video_url != nil))
    rescue
      _ -> 0
    end
  end

  defp completion(project) do
    try do
      panels =
        Production.list_episodes(project.id)
        |> Enum.flat_map(fn ep ->
          Production.list_storyboards(ep.id)
          |> Enum.flat_map(&Production.list_panels(&1.id))
        end)

      total = length(panels)

      if total == 0 do
        0
      else
        done = Enum.count(panels, &(&1.video_url != nil))
        round(done / total * 100)
      end
    rescue
      _ -> 0
    end
  end

  defp format_time(nil), do: ""

  defp format_time(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)

    cond do
      diff < 60 -> "刚刚"
      diff < 3600 -> "#{div(diff, 60)} 分钟前"
      diff < 86400 -> "#{div(diff, 3600)} 小时前"
      diff < 604_800 -> "#{div(diff, 86400)} 天前"
      true -> Calendar.strftime(datetime, "%Y-%m-%d")
    end
  end
end
