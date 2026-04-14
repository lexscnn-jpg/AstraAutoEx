defmodule AstraAutoExWeb.HomeLive do
  use AstraAutoExWeb, :live_view

  alias AstraAutoEx.{Projects, Production}
  alias AstraAutoEx.Workers.Handlers.Helpers

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    projects = Projects.list_projects(user.id)

    {:ok,
     socket
     |> assign(:projects, projects)
     |> assign(:show_modal, false)
     |> assign(:search, "")
     |> assign(:ai_status_messages, ai_status_messages())
     |> assign(
       :project_form,
       to_form(
         Projects.change_project(%Projects.Project{})
         |> Ecto.Changeset.put_change(:user_id, user.id),
         as: "project"
       )
     )
     # Quick create state
     |> assign(:story_input, "")
     |> assign(:aspect_ratio, "16:9")
     |> assign(:art_style, "realistic")
     |> assign(:show_art_dropdown, false)
     # AI write modal state
     |> assign(:show_ai_modal, false)
     |> assign(:ai_phase, :input)
     |> assign(:ai_prompt, "")
     |> assign(:ai_outline, "")
     |> assign(:ai_episode_count, 0)
     |> assign(:ai_status_index, 0)
     |> assign(:ai_timer_ref, nil)
     # File upload
     |> allow_upload(:story_file,
       accept: ~w(.txt .md),
       max_entries: 1,
       max_file_size: 2_000_000,
       auto_upload: true,
       progress: &handle_progress/3
     )
     |> assign(:page_title, dgettext("projects", "My Projects"))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="min-h-[calc(100vh-52px)] flex flex-col">
        <%!-- ═══════════ Hero Section with ViewFinder Frame ═══════════ --%>
        <section class="relative flex-shrink-0 px-6 pt-8 pb-4">
          <%!-- ViewFinder corner brackets (breathing animation) --%>
          <div class="max-w-5xl mx-auto relative">
            <div
              class="absolute -top-2 -left-2 w-6 h-6 border-t-2 border-l-2 border-[var(--glass-stroke-base)] rounded-tl-sm opacity-40 animate-pulse"
              style="animation-duration: 8s"
            >
            </div>
            
            <div
              class="absolute -top-2 -right-2 w-6 h-6 border-t-2 border-r-2 border-[var(--glass-stroke-base)] rounded-tr-sm opacity-40 animate-pulse"
              style="animation-duration: 8s"
            >
            </div>
            
            <div
              class="absolute -bottom-2 -left-2 w-6 h-6 border-b-2 border-l-2 border-[var(--glass-stroke-base)] rounded-bl-sm opacity-40 animate-pulse"
              style="animation-duration: 8s"
            >
            </div>
            
            <div
              class="absolute -bottom-2 -right-2 w-6 h-6 border-b-2 border-r-2 border-[var(--glass-stroke-base)] rounded-br-sm opacity-40 animate-pulse"
              style="animation-duration: 8s"
            >
            </div>
             <%!-- REC indicator --%>
            <div class="absolute top-1 right-4 flex items-center gap-1.5 opacity-40">
              <span class="w-2 h-2 rounded-full bg-red-500 animate-pulse"></span>
              <span class="text-[10px] text-red-400 font-mono tracking-wider">REC</span>
            </div>
             <%!-- Title with animations --%>
            <div class="text-center py-6">
              <h1 class="text-3xl font-extrabold text-[var(--glass-text-primary)] tracking-tight twh-focus-pull">
                {dgettext("landing", "AstrAuto Drama")}
              </h1>
              
              <p
                id="hero-typewriter"
                phx-hook="TypewriterHero"
                data-text={
                  dgettext(
                    "projects",
                    "Describe your story and let AI generate cinematic short dramas"
                  )
                }
                class="text-sm text-[var(--glass-text-tertiary)] mt-2 font-mono"
              >
                >_ <span data-typewriter-target></span><span class="animate-pulse">|</span>
              </p>
            </div>
             <%!-- Story Composer --%>
            <form phx-change="validate_quick_create" phx-submit="start_create">
              <div class="glass-surface rounded-2xl p-5 shadow-sm">
                <div phx-drop-target={@uploads.story_file.ref} class="relative">
                  <textarea
                    name="story_input"
                    value={@story_input}
                    class="w-full resize-none bg-transparent text-base leading-relaxed text-[var(--glass-text-primary)] placeholder:text-[var(--glass-text-tertiary)] focus:outline-none"
                    style="min-height: 160px"
                    placeholder="在此输入你的一句话故事创意，小说片段或剧本大纲...（支持粘贴，拖拽上传）"
                    phx-debounce="300"
                  />
                  <.live_file_input upload={@uploads.story_file} class="hidden" />
                  <div
                    :if={@story_input == ""}
                    class="absolute bottom-2 right-2 flex items-center gap-1 text-xs text-[var(--glass-text-tertiary)]"
                  >
                    <label
                      for={@uploads.story_file.ref}
                      class="flex items-center gap-1 cursor-pointer hover:text-[var(--glass-text-secondary)] transition-colors opacity-70 hover:opacity-100"
                    >
                      <svg
                        class="w-3.5 h-3.5"
                        fill="none"
                        stroke="currentColor"
                        stroke-width="1.5"
                        viewBox="0 0 24 24"
                      >
                        <path d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5m-13.5-9L12 3m0 0l4.5 4.5M12 3v13.5" />
                      </svg> {dgettext("projects", "Drop .txt/.md file")}
                    </label>
                  </div>
                </div>
                 <%!-- Upload entries --%>
                <%= for entry <- @uploads.story_file.entries do %>
                  <div class="flex items-center gap-2 mt-2 text-xs text-[var(--glass-text-secondary)]">
                    <span>{entry.client_name}</span>
                    <div class="flex-1 h-1 bg-[var(--glass-bg-muted)] rounded-full">
                      <div
                        class="h-full bg-gradient-to-r from-[var(--glass-accent-from)] to-[var(--glass-accent-to)] rounded-full transition-all"
                        style={"width: #{entry.progress}%"}
                      />
                    </div>
                    
                    <button
                      type="button"
                      phx-click="cancel_upload"
                      phx-value-ref={entry.ref}
                      class="text-[var(--glass-text-tertiary)] hover:text-red-400"
                    >
                      &times;
                    </button>
                  </div>
                <% end %>
                
                <%= for err <- upload_errors(@uploads.story_file) do %>
                  <p class="text-xs text-red-400 mt-1">{upload_error_to_string(err)}</p>
                <% end %>
                 <%!-- Bottom toolbar --%>
                <div class="flex items-center justify-between pt-3 mt-3 border-t border-[var(--glass-stroke-soft)]">
                  <div class="flex items-center gap-3">
                    <div class="flex items-center gap-1.5 text-[var(--glass-text-tertiary)]">
                      <svg
                        class="w-4 h-4"
                        fill="none"
                        stroke="currentColor"
                        stroke-width="1.5"
                        viewBox="0 0 24 24"
                      >
                        <rect x="2" y="4" width="20" height="16" rx="2" />
                      </svg>
                      <select
                        phx-change="select_aspect_ratio"
                        name="ratio"
                        class="bg-transparent text-sm text-[var(--glass-text-primary)] border-none focus:ring-0 py-0 pl-0 pr-5 cursor-pointer"
                      >
                        <%= for {r, label} <- [{"16:9", "16:9 横屏·长视频"}, {"9:16", "9:16 竖屏·短剧"}, {"1:1", "1:1 方形·封面"}, {"3:2", "3:2 横屏·风景"}, {"2:3", "2:3 竖屏·海报"}, {"4:3", "4:3 横屏·传统"}, {"3:4", "3:4 竖屏·直播"}, {"5:4", "5:4 横屏·广告"}, {"4:5", "4:5 竖屏·信息流"}, {"21:9", "21:9 超宽·电影"}] do %>
                          <option value={r} selected={@aspect_ratio == r}>{label}</option>
                        <% end %>
                      </select>
                    </div>
                    
                    <div class="w-px h-4 bg-[var(--glass-stroke-soft)]"></div>
                    
                    <div class="flex items-center gap-1.5 text-[var(--glass-text-tertiary)] relative">
                      <svg
                        class="w-4 h-4"
                        fill="none"
                        stroke="currentColor"
                        stroke-width="1.5"
                        viewBox="0 0 24 24"
                      >
                        <path d="M9.53 16.122a3 3 0 00-5.78 1.128 2.25 2.25 0 01-2.4 2.245 4.5 4.5 0 008.4-2.245c0-.399-.078-.78-.22-1.128zm0 0a15.998 15.998 0 003.388-1.62m-5.043-.025a15.994 15.994 0 011.622-3.395m3.42 3.42a15.995 15.995 0 004.764-4.648l3.876-5.814a1.151 1.151 0 00-1.597-1.597L14.146 6.32a15.996 15.996 0 00-4.649 4.763m3.42 3.42a6.776 6.776 0 00-3.42-3.42" />
                      </svg>
                      <select
                        phx-change="select_art_style"
                        name="art_style"
                        class="bg-transparent text-sm text-[var(--glass-text-primary)] border-none focus:ring-0 py-0 pl-0 pr-5 cursor-pointer"
                      >
                        <%= for {label, value} <- AstraAutoEx.AI.ArtStyles.style_options() do %>
                          <option value={value} selected={@art_style == value}>{label}</option>
                        <% end %>
                      </select>
                    </div>
                  </div>
                   <%!-- Custom art style prompt (when "custom" selected) --%>
                  <div :if={@art_style == "custom"} class="w-full mt-2">
                    <textarea
                      name="art_style_prompt"
                      rows="2"
                      phx-change="update_art_style_prompt"
                      phx-debounce="500"
                      class="glass-input w-full text-xs resize-none border-[var(--glass-stroke-soft)]"
                      placeholder="输入自定义画风描述..."
                    ><%= assigns[:art_style_prompt] || "" %></textarea>
                  </div>
                  
                  <div class="flex items-center gap-3">
                    <button
                      type="button"
                      phx-click="open_ai_modal"
                      class="text-sm text-[var(--glass-accent-from)] hover:text-[var(--glass-accent-to)] transition-colors flex items-center gap-1.5"
                    >
                      <svg
                        class="w-4 h-4"
                        fill="none"
                        stroke="currentColor"
                        stroke-width="1.5"
                        viewBox="0 0 24 24"
                      >
                        <path d="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09z" />
                      </svg> {dgettext("projects", "AI Write")}
                    </button>
                    <button
                      type="submit"
                      class="glass-btn glass-btn-primary text-sm py-2 px-6 flex items-center gap-2"
                      disabled={String.trim(@story_input) == ""}
                    >
                      {dgettext("projects", "Start Creating")}
                      <svg
                        class="w-4 h-4"
                        fill="none"
                        stroke="currentColor"
                        stroke-width="2"
                        viewBox="0 0 24 24"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          d="M13 7l5 5m0 0l-5 5m5-5H6"
                        />
                      </svg>
                    </button>
                  </div>
                </div>
              </div>
            </form>
          </div>
        </section>
        
        <%!-- ═══════════ Recent Projects ═══════════ --%>
        <section class="px-6 py-6 flex-1">
          <div class="max-w-5xl mx-auto">
            <div class="flex items-center justify-between mb-4">
              <h2 class="text-lg font-bold text-[var(--glass-text-primary)]">
                {dgettext("projects", "Recent Projects")}
              </h2>
              
              <.link
                navigate={~p"/projects"}
                class="text-xs text-[var(--glass-accent-from)] hover:text-[var(--glass-accent-to)] transition-colors"
              >
                {dgettext("projects", "View All Projects")} →
              </.link>
            </div>
            
            <%= if length(@projects) > 0 do %>
              <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                <%= for project <- Enum.take(@projects, 4) do %>
                  <.link navigate={~p"/projects/#{project.id}"} class="block no-underline group">
                    <div class="glass-card p-4 hover:shadow-lg hover:-translate-y-0.5 transition-all cursor-pointer">
                      <h3 class="text-sm font-bold text-[var(--glass-text-primary)] group-hover:text-[var(--glass-accent-from)] truncate">
                        {project.name}
                      </h3>
                      
                      <p
                        :if={project.description && project.description != ""}
                        class="text-xs text-[var(--glass-text-tertiary)] mt-1.5 line-clamp-2 flex items-start gap-1"
                      >
                        <svg
                          class="w-3 h-3 mt-0.5 flex-shrink-0 opacity-40"
                          fill="none"
                          stroke="currentColor"
                          stroke-width="1.5"
                          viewBox="0 0 24 24"
                        >
                          <path d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m2.25 0H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z" />
                        </svg> <span>{project.description}</span>
                      </p>
                      
                      <div class="flex items-center gap-1.5 mt-3 text-[var(--glass-text-tertiary)]">
                        <svg
                          class="w-3.5 h-3.5 opacity-50"
                          fill="none"
                          stroke="currentColor"
                          stroke-width="1.5"
                          viewBox="0 0 24 24"
                        >
                          <path d="M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z" />
                        </svg>
                        <span class="text-[10px]">
                          {Calendar.strftime(project.updated_at, "%Y-%m-%d %H:%M")}
                        </span>
                      </div>
                    </div>
                  </.link>
                <% end %>
              </div>
            <% else %>
              <div class="glass-surface rounded-xl p-12 text-center">
                <p class="text-[var(--glass-text-tertiary)]">
                  {dgettext("projects", "No projects yet. Start your first creation!")}
                </p>
              </div>
            <% end %>
          </div>
        </section>
      </div>
       <%!-- ═══════════ AI Write Modal ═══════════ --%>
      <%= if @show_ai_modal do %>
        <div class="fixed inset-0 z-50 flex items-center justify-center">
          <div class="absolute inset-0 bg-black/60 backdrop-blur-sm" phx-click="close_ai_modal" />
          <div class="glass-card p-6 w-full max-w-lg relative z-10 shadow-2xl">
            <div class="flex items-center justify-between mb-5">
              <div class="flex items-center gap-3">
                <div class="w-10 h-10 rounded-xl bg-gradient-to-br from-purple-500 to-blue-500 flex items-center justify-center shadow-lg">
                  <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" stroke-width="1.5" viewBox="0 0 24 24">
                    <path d="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09z" />
                  </svg>
                </div>
                <div>
                  <h3 class="text-lg font-bold text-[var(--glass-text-primary)]">AI 创作助手</h3>
                  <p class="text-xs text-[var(--glass-text-tertiary)]">输入你的创意，AI 自动生成 65-80 集剧本大纲</p>
                </div>
              </div>
              <button type="button" phx-click="close_ai_modal" class="text-[var(--glass-text-tertiary)] hover:text-[var(--glass-text-primary)]">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                  <path d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>
             <%!-- Phase: Input --%>
            <div :if={@ai_phase == :input} class="space-y-4">
              <h4 class="text-sm font-semibold text-[var(--glass-text-primary)]">输入你的创意内容</h4>
              <textarea
                phx-change="update_ai_prompt"
                phx-debounce="300"
                name="ai_prompt"
                value={@ai_prompt}
                rows="6"
                class="glass-input w-full resize-none"
                placeholder={"输入关键词、IP名称、故事灵感...\n\n例如：\n• 古代宫廷 复仇 悬疑 女主角\n• 根据陈情令改编\n• 现代霸总+替身新娘+复仇逆袭"}
              />
              <p class="text-xs text-[var(--glass-text-tertiary)] bg-[var(--glass-bg-muted)] rounded-lg p-2.5">
                AI 将生成完整多集短剧大纲（65-80集），你可以审阅修改后再确认
              </p>
              <div class="flex items-center justify-between">
                <button
                  type="button"
                  phx-click="view_prompt_template"
                  class="text-xs text-[var(--glass-text-tertiary)] hover:text-[var(--glass-accent-from)] transition-colors flex items-center gap-1"
                >
                  <svg
                    class="w-3.5 h-3.5"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="1.5"
                    viewBox="0 0 24 24"
                  >
                    <path d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z" />
                  </svg> {dgettext("projects", "Prompt")}
                </button>
                <button
                  type="button"
                  phx-click="generate_ai_outline"
                  disabled={String.trim(@ai_prompt) == ""}
                  class="glass-btn glass-btn-primary px-6 py-2 text-sm disabled:opacity-40 flex items-center gap-1.5"
                >
                  <svg
                    class="w-4 h-4"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="1.5"
                    viewBox="0 0 24 24"
                  >
                    <path d="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09z" />
                  </svg> {dgettext("projects", "Generate Outline")}
                </button>
              </div>
            </div>
             <%!-- Phase: Loading --%>
            <div :if={@ai_phase == :loading} class="py-12 text-center space-y-6">
              <div class="inline-block relative">
                <div class="w-14 h-14 rounded-full border-4 border-[var(--glass-stroke-base)] border-t-[var(--glass-accent-from)] animate-spin">
                </div>
                
                <svg
                  class="w-6 h-6 absolute top-4 left-4 text-[var(--glass-accent-from)] animate-pulse"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="1.5"
                  viewBox="0 0 24 24"
                >
                  <path d="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09z" />
                </svg>
              </div>
              
              <p class="text-sm text-[var(--glass-text-secondary)] animate-pulse">
                {Enum.at(@ai_status_messages, @ai_status_index)}
              </p>
            </div>
             <%!-- Phase: Outline --%>
            <div :if={@ai_phase == :outline} class="space-y-4">
              <div class="flex items-center justify-between">
                <span class="text-sm text-[var(--glass-text-secondary)]">
                  {dgettext("projects", "Generated Outline")}
                </span>
                <span class="glass-chip glass-chip-info text-[10px]">
                  {dgettext("projects", "%{count} episodes", count: @ai_episode_count)}
                </span>
              </div>
              
              <textarea
                phx-change="update_ai_outline"
                phx-debounce="300"
                name="ai_outline"
                value={@ai_outline}
                rows="12"
                class="glass-input w-full resize-none font-mono text-xs"
              />
              <div class="flex justify-end gap-2">
                <button
                  type="button"
                  phx-click="regenerate_ai_outline"
                  class="glass-btn glass-btn-ghost px-4 py-2 text-sm"
                >
                  {dgettext("projects", "Regenerate")}
                </button>
                <button
                  type="button"
                  phx-click="confirm_ai_outline"
                  class="glass-btn glass-btn-primary px-6 py-2 text-sm"
                >
                  {dgettext("projects", "Use This Outline")}
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </Layouts.app>
    """
  end

  # ── Existing events ────────────────────────────────────────────────────

  @impl true
  def handle_event("open_modal", _params, socket) do
    {:noreply, assign(socket, :show_modal, true)}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, :show_modal, false)}
  end

  def handle_event("search", %{"search" => search}, socket) do
    {:noreply, assign(socket, :search, search)}
  end

  def handle_event("create_project", %{"project" => params}, socket) do
    user = socket.assigns.current_scope.user

    case Projects.create_project(user.id, params) do
      {:ok, project} ->
        {:noreply,
         socket
         |> assign(:projects, Projects.list_projects(user.id))
         |> assign(:show_modal, false)
         |> push_navigate(to: ~p"/projects/#{project.id}")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:project_form, to_form(changeset, as: "project"))
         |> put_flash(:error, dgettext("default", "Error"))}
    end
  end

  def handle_event("delete_project", %{"id" => id}, socket) do
    user = socket.assigns.current_scope.user
    project = Projects.get_project!(id, user.id)
    {:ok, _} = Projects.delete_project(project)
    {:noreply, assign(socket, :projects, Projects.list_projects(user.id))}
  end

  # ── Quick Create events ────────────────────────────────────────────────

  def handle_event("validate_quick_create", %{"story_input" => story_input}, socket) do
    {:noreply, assign(socket, :story_input, story_input)}
  end

  def handle_event("validate_quick_create", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("select_aspect_ratio", %{"ratio" => ratio}, socket) do
    {:noreply, assign(socket, :aspect_ratio, ratio)}
  end

  def handle_event("select_art_style", %{"art_style" => style}, socket) do
    {:noreply, assign(socket, :art_style, style)}
  end

  def handle_event("update_art_style_prompt", %{"art_style_prompt" => prompt}, socket) do
    {:noreply, assign(socket, :art_style_prompt, prompt)}
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :story_file, ref)}
  end

  def handle_event("start_create", %{"story_input" => story_input}, socket) do
    user = socket.assigns.current_scope.user
    story = String.trim(story_input)

    if story == "" do
      {:noreply, put_flash(socket, :error, dgettext("projects", "Please enter a story first"))}
    else
      # Auto-generate project name from the first line / first 30 chars
      name =
        story
        |> String.split("\n", parts: 2)
        |> List.first()
        |> String.slice(0..29)
        |> String.trim()

      params = %{
        "name" => name,
        "description" => String.slice(story, 0..500),
        "type" => "short_drama",
        "aspect_ratio" => socket.assigns.aspect_ratio
      }

      case Projects.create_project(user.id, params) do
        {:ok, project} ->
          # Create first episode with story text preserved
          Production.create_episode(%{
            project_id: project.id,
            user_id: user.id,
            episode_number: 1,
            title: "#{name} 第1集",
            novel_text: story
          })

          {:noreply,
           socket
           |> assign(:projects, Projects.list_projects(user.id))
           |> push_navigate(to: ~p"/projects/#{project.id}")}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, dgettext("default", "Error"))}
      end
    end
  end

  def handle_event("view_prompt_template", _params, socket) do
    alias AstraAutoEx.AI.PromptCatalog

    preview =
      case PromptCatalog.get_template("np_ai_story_outline", "zh") do
        {:ok, text} -> String.slice(text, 0..200) <> "..."
        _ -> "Prompt template not found"
      end

    {:noreply, put_flash(socket, :info, preview)}
  end

  # ── AI Write Modal events ──────────────────────────────────────────────

  def handle_event("open_ai_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_ai_modal, true)
     |> assign(:ai_phase, :input)
     |> assign(:ai_prompt, "")
     |> assign(:ai_outline, "")
     |> assign(:ai_episode_count, 0)}
  end

  def handle_event("close_ai_modal", _params, socket) do
    cancel_ai_timer(socket)
    {:noreply, assign(socket, :show_ai_modal, false)}
  end

  def handle_event("update_ai_prompt", %{"ai_prompt" => prompt}, socket) do
    {:noreply, assign(socket, :ai_prompt, prompt)}
  end

  def handle_event("update_ai_outline", %{"ai_outline" => outline}, socket) do
    {:noreply,
     socket
     |> assign(:ai_outline, outline)
     |> assign(:ai_episode_count, count_episodes(outline))}
  end

  def handle_event("generate_ai_outline", _params, socket) do
    prompt = String.trim(socket.assigns.ai_prompt)

    if prompt == "" do
      {:noreply, socket}
    else
      timer_ref = Process.send_after(self(), :rotate_ai_status, 3_000)

      socket =
        socket
        |> assign(:ai_phase, :loading)
        |> assign(:ai_status_index, 0)
        |> assign(:ai_timer_ref, timer_ref)

      user = socket.assigns.current_scope.user
      pid = self()

      Task.start(fn ->
        dispatch_ai_outline(user.id, prompt, pid)
      end)

      {:noreply, socket}
    end
  end

  def handle_event("regenerate_ai_outline", _params, socket) do
    timer_ref = Process.send_after(self(), :rotate_ai_status, 3_000)

    socket =
      socket
      |> assign(:ai_phase, :loading)
      |> assign(:ai_status_index, 0)
      |> assign(:ai_timer_ref, timer_ref)

    user = socket.assigns.current_scope.user
    prompt = socket.assigns.ai_prompt
    pid = self()

    Task.start(fn ->
      dispatch_ai_outline(user.id, prompt, pid)
    end)

    {:noreply, socket}
  end

  def handle_event("confirm_ai_outline", _params, socket) do
    socket =
      socket
      |> assign(:story_input, socket.assigns.ai_outline)
      |> assign(:show_ai_modal, false)

    {:noreply, socket}
  end

  # ── Handle info (async AI + timer + file upload) ───────────────────────

  @impl true
  def handle_info(:rotate_ai_status, socket) do
    if socket.assigns.ai_phase == :loading do
      next_index =
        rem(socket.assigns.ai_status_index + 1, length(socket.assigns.ai_status_messages))

      timer_ref = Process.send_after(self(), :rotate_ai_status, 3_000)

      {:noreply,
       socket
       |> assign(:ai_status_index, next_index)
       |> assign(:ai_timer_ref, timer_ref)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:ai_write_result, text}, socket) do
    cancel_ai_timer(socket)

    {:noreply,
     socket
     |> assign(:ai_phase, :outline)
     |> assign(:ai_outline, text)
     |> assign(:ai_episode_count, count_episodes(text))}
  end

  def handle_info({:ai_write_error, reason}, socket) do
    cancel_ai_timer(socket)

    {:noreply,
     socket
     |> assign(:ai_phase, :input)
     |> put_flash(
       :error,
       dgettext("projects", "AI generation failed: %{reason}", reason: inspect(reason))
     )}
  end

  # ── File upload consume callback ───────────────────────────────────────

  def handle_progress(:story_file, entry, socket) do
    if entry.done? do
      content =
        consume_uploaded_entry(socket, entry, fn %{path: path} ->
          {:ok, File.read!(path)}
        end)

      {:noreply, assign(socket, :story_input, content)}
    else
      {:noreply, socket}
    end
  end

  # ── Private helpers ────────────────────────────────────────────────────

  defp dispatch_ai_outline(user_id, prompt, pid) do
    model_config = Helpers.get_model_config(user_id, nil, :llm)
    provider = model_config["provider"]

    instruction = """
    You are a professional short drama screenwriter. Based on the following creative idea,
    generate a complete story outline including:
    1. Title
    2. Logline (one sentence summary)
    3. Three-act structure with key events per act
    4. Episode count recommendation
    5. Character summaries
    6. Key plot twists and hooks

    Creative idea:
    #{String.slice(prompt, 0..4000)}

    Respond in the same language as the creative idea. Format as readable text, not JSON.
    """

    request = %{
      model: model_config["model"],
      contents: [%{"parts" => [%{"text" => instruction}]}]
    }

    case Helpers.chat(user_id, provider, request) do
      {:ok, text} -> send(pid, {:ai_write_result, text})
      {:error, reason} -> send(pid, {:ai_write_error, reason})
    end
  end

  defp cancel_ai_timer(socket) do
    if ref = socket.assigns[:ai_timer_ref] do
      Process.cancel_timer(ref)
    end
  end

  defp count_episodes(text) do
    # Try to detect episode count from outline text
    episode_pattern = ~r/(?:episode|集|第\d+集|ep\s*\.?\s*\d+)/i
    matches = Regex.scan(episode_pattern, text)
    length(matches)
  end

  # filtered_projects and status_color removed — full listing moved to /home route

  defp upload_error_to_string(:too_large), do: dgettext("projects", "File too large (max 2MB)")

  defp upload_error_to_string(:not_accepted),
    do: dgettext("projects", "Only .txt and .md files accepted")

  defp upload_error_to_string(:too_many_files),
    do: dgettext("projects", "Only one file at a time")

  defp upload_error_to_string(err), do: inspect(err)

  defp ai_status_messages do
    [
      dgettext("projects", "Preparing..."),
      dgettext("projects", "Thinking..."),
      dgettext("projects", "Creating..."),
      dgettext("projects", "Polishing..."),
      dgettext("projects", "Almost done...")
    ]
  end
end
