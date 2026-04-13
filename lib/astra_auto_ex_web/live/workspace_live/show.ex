defmodule AstraAutoExWeb.WorkspaceLive.Show do
  use AstraAutoExWeb, :live_view

  alias AstraAutoEx.{Projects, Characters, Locations, Production, Tasks}

  @stages ~w(story script storyboard film compose)

  @impl true
  def mount(%{"id" => project_id}, _session, socket) do
    user_id = socket.assigns.current_scope.user.id
    project = Projects.get_project!(project_id, user_id)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(AstraAutoEx.PubSub, "project:#{project_id}")
    end

    episodes = Production.list_episodes(project_id)
    current_episode = List.first(episodes)

    {:ok,
     socket
     |> assign(:project, project)
     |> assign(:stage, "story")
     |> assign(:stages, @stages)
     |> assign(:characters, Characters.list_characters(project_id))
     |> assign(:locations, Locations.list_locations(project_id))
     |> assign(:episodes, episodes)
     |> assign(:current_episode, current_episode)
     |> assign(:storyboards, load_storyboards(current_episode))
     |> assign(:active_tasks, Tasks.list_project_tasks(project_id, status: "processing"))
     |> assign(:novel_text, "")
     |> assign(:show_assistant, false)
     |> assign(:editing_panel, nil)
     |> assign(:show_character_modal, false)
     |> assign(:show_location_modal, false)
     |> assign(:show_voice_picker, false)
     |> assign(:editing_character, nil)
     |> assign(:editing_location, nil)
     |> assign(:voice_picker_target, nil)
     |> assign(:voice_lines, load_voice_lines(current_episode))
     |> assign(:task_progress, %{})
     |> assign(:viewing_prompt, nil)
     |> assign(:aspect_ratio, project.aspect_ratio || "16:9")
     |> assign(:art_style, "realistic")
     |> assign(:compose_transition, "crossfade")
     |> assign(:compose_transition_ms, "500")
     |> assign(:compose_subtitle, "both")
     |> assign(:compose_bgm, "none")
     |> assign(:selected_panels, MapSet.new())
     |> assign(:page_title, project.name)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="min-h-[calc(100vh-52px)] flex flex-col">
        <%!-- Top bar: Episode selector | Stage tabs | Action buttons --%>
        <div class="flex items-center justify-between px-4 py-2 border-b border-[var(--glass-stroke-base)]">
          <%!-- Left: Episode selector --%>
          <div class="flex items-center gap-2">
            <span class="glass-chip glass-chip-info text-xs font-semibold py-1 px-2">
              {dgettext("projects", "Episodes")}
            </span>
            <div class="flex items-center gap-1">
              <span class="text-sm font-semibold text-[var(--glass-text-primary)]">
                {@project.name}
              </span>
              <select
                :if={length(@episodes) > 0}
                class="glass-input text-xs py-1 pl-2 pr-6 ml-1"
                phx-change="select_episode"
              >
                <%= for ep <- @episodes do %>
                  <option
                    value={ep.id}
                    selected={@current_episode && @current_episode.id == ep.id}
                  >
                    {ep.title || "Episode #{ep.episode_number}"}
                  </option>
                <% end %>
              </select>
            </div>
          </div>

          <%!-- Center: Stage tabs --%>
          <div class="flex items-center gap-0.5 p-1 rounded-xl bg-[var(--glass-bg-muted)]">
            <%= for stage <- @stages do %>
              <button
                phx-click="switch_stage"
                phx-value-stage={stage}
                class={[
                  "relative px-4 py-1.5 rounded-lg text-sm font-medium transition-all",
                  if(@stage == stage,
                    do:
                      "text-[var(--glass-accent-from)] after:absolute after:bottom-0 after:left-1/2 after:-translate-x-1/2 after:w-5 after:h-0.5 after:bg-[var(--glass-accent-from)] after:rounded-full",
                    else: "text-[var(--glass-text-tertiary)] hover:text-[var(--glass-text-primary)]"
                  )
                ]}
              >
                {stage_label(stage)}
              </button>
            <% end %>
          </div>

          <%!-- Right: Action buttons --%>
          <div class="flex items-center gap-2">
            <a
              href={~p"/asset-hub"}
              class="glass-btn glass-btn-ghost text-xs py-1.5 px-3 flex items-center gap-1.5"
            >
              <svg
                class="w-4 h-4"
                fill="none"
                stroke="currentColor"
                stroke-width="1.5"
                viewBox="0 0 24 24"
              >
                <path d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4" />
              </svg>
              {dgettext("projects", "Assets")}
            </a>
            <button
              phx-click="toggle_assistant"
              class="glass-btn glass-btn-ghost text-xs py-1.5 px-3 flex items-center gap-1.5"
            >
              <svg
                class="w-4 h-4"
                fill="none"
                stroke="currentColor"
                stroke-width="1.5"
                viewBox="0 0 24 24"
              >
                <path d="M10.343 3.94c.09-.542.56-.94 1.11-.94h1.093c.55 0 1.02.398 1.11.94l.149.894c.07.424.384.764.78.93s.844.1 1.208-.137l.757-.507a1.125 1.125 0 011.37.17l.773.773c.394.394.5.978.17 1.37l-.507.758c-.236.363-.267.827-.137 1.208.13.396.506.71.93.78l.894.149c.542.09.94.56.94 1.11v1.093c0 .55-.398 1.02-.94 1.11l-.894.149c-.424.07-.764.384-.93.78s-.1.844.137 1.208l.507.757c.33.392.224.976-.17 1.37l-.773.773a1.125 1.125 0 01-1.37.17l-.757-.507c-.364-.236-.828-.267-1.208-.137-.396.13-.71.506-.78.93l-.15.894c-.09.542-.56.94-1.11.94h-1.093c-.55 0-1.02-.398-1.11-.94l-.149-.894c-.07-.424-.384-.764-.78-.93s-.844-.1-1.208.137l-.757.507a1.125 1.125 0 01-1.37-.17l-.773-.773a1.125 1.125 0 01-.17-1.37l.507-.758c.236-.363.267-.827.137-1.208-.13-.396-.506-.71-.93-.78l-.894-.149c-.542-.09-.94-.56-.94-1.11v-1.093c0-.55.398-1.02.94-1.11l.894-.149c.424-.07.764-.384.93-.78s.1-.844-.138-1.208l-.507-.757a1.125 1.125 0 01.17-1.37l.773-.773a1.125 1.125 0 011.37-.17l.758.507c.363.236.827.267 1.208.137.396-.13.71-.506.78-.93l.15-.894z" /><circle
                  cx="12"
                  cy="12"
                  r="3"
                />
              </svg>
              {dgettext("projects", "Config")}
            </button>
            <button
              phx-click="toggle_assistant"
              class="glass-btn glass-btn-ghost text-xs py-1.5 px-2"
              title={dgettext("projects", "Refresh")}
            >
              <svg
                class="w-4 h-4"
                fill="none"
                stroke="currentColor"
                stroke-width="1.5"
                viewBox="0 0 24 24"
              >
                <path d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0l3.181 3.183a8.25 8.25 0 0013.803-3.7M4.031 9.865a8.25 8.25 0 0113.803-3.7l3.181 3.182" />
              </svg>
            </button>
          </div>
        </div>

        <%!-- Episode info bar --%>
        <div
          :if={@current_episode}
          class="text-center py-3 border-b border-[var(--glass-stroke-soft)]"
        >
          <p class="text-sm font-semibold text-[var(--glass-text-primary)]">
            {dgettext("projects", "Currently editing:")}
            {@current_episode.title || "Episode #{@current_episode.episode_number}"}
          </p>
          <p class="text-xs text-[var(--glass-text-tertiary)]">
            {dgettext(
              "projects",
              "The production pipeline below applies to this episode only."
            )}
          </p>
        </div>

        <%!-- Main content --%>
        <main class="flex-1 overflow-y-auto">
          <div class="max-w-6xl mx-auto px-6 py-6">
            <%= case @stage do %>
              <% "story" -> %>
                <.config_stage
                  project={@project}
                  novel_text={@novel_text}
                  aspect_ratio={@aspect_ratio}
                  art_style={@art_style}
                />
              <% "script" -> %>
                <.script_stage
                  episodes={@episodes}
                  current_episode={@current_episode}
                  characters={@characters}
                  locations={@locations}
                />
              <% "storyboard" -> %>
                <.storyboard_stage
                  current_episode={@current_episode}
                  storyboards={@storyboards}
                  editing_panel={@editing_panel}
                  task_progress={@task_progress}
                  project={@project}
                  current_scope={@current_scope}
                />
              <% "film" -> %>
                <.video_stage
                  current_episode={@current_episode}
                  storyboards={@storyboards}
                  voice_lines={@voice_lines}
                />
              <% "compose" -> %>
                <.compose_stage
                  current_episode={@current_episode}
                  storyboards={@storyboards}
                  voice_lines={@voice_lines}
                  active_tasks={@active_tasks}
                  selected_panels={@selected_panels}
                  compose_transition={@compose_transition}
                  compose_transition_ms={@compose_transition_ms}
                  compose_subtitle={@compose_subtitle}
                  compose_bgm={@compose_bgm}
                />
            <% end %>
          </div>
        </main>
      </div>

      <%!-- AI Assistant Drawer --%>
      <aside
        :if={@show_assistant}
        class="fixed top-[52px] right-0 bottom-0 w-80 glass-surface border-l border-[var(--glass-stroke-base)] flex flex-col z-40 shadow-2xl"
      >
        <.live_component
          module={AstraAutoExWeb.AssistantLive.Panel}
          id="assistant-panel"
          project={@project}
          current_scope={@current_scope}
        />
      </aside>

      <%!-- Prompt Viewer Modal --%>
      <.prompt_viewer_modal :if={@viewing_prompt} prompt={@viewing_prompt} />
    </Layouts.app>
    """
  end

  defp prompt_btn(assigns) do
    ~H"""
    <button
      phx-click="view_pipeline_prompt"
      phx-value-id={@id}
      class="inline-flex items-center gap-1 text-xs text-[var(--glass-accent-from)] hover:text-[var(--glass-accent-to)] transition-colors cursor-pointer"
      title={@id}
    >
      <svg
        class="w-3.5 h-3.5"
        fill="none"
        stroke="currentColor"
        stroke-width="1.5"
        viewBox="0 0 24 24"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z"
        />
      </svg>
      {dgettext("projects", "Prompt")}
    </button>
    """
  end

  defp prompt_viewer_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center">
      <div class="absolute inset-0 bg-black/60" phx-click="close_prompt_viewer" />
      <div class="glass-card p-6 w-full max-w-2xl relative z-10 max-h-[80vh] overflow-hidden flex flex-col">
        <div class="flex items-center justify-between mb-4">
          <div>
            <h3 class="text-lg font-bold text-[var(--glass-text-primary)]">{@prompt.label}</h3>
            <code class="text-xs text-[var(--glass-text-tertiary)]">{@prompt.id}</code>
          </div>
          <button
            phx-click="close_prompt_viewer"
            class="text-[var(--glass-text-tertiary)] hover:text-[var(--glass-text-primary)] text-xl"
          >
            &times;
          </button>
        </div>
        <div class="flex-1 overflow-y-auto">
          <label class="text-xs text-[var(--glass-text-tertiary)] mb-1 block">
            {dgettext("projects", "System Prompt Template")}
          </label>
          <pre class="glass-input w-full text-xs font-mono whitespace-pre-wrap p-4 max-h-[55vh] overflow-y-auto"><%= @prompt.text %></pre>
        </div>
        <div class="flex justify-end mt-4 pt-3 border-t border-[var(--glass-stroke-base)]">
          <button
            phx-click="close_prompt_viewer"
            class="glass-btn glass-btn-ghost px-4 py-2 text-sm"
          >
            {dgettext("default", "Close")}
          </button>
        </div>
      </div>
    </div>
    """
  end

  # ══════════════════════════════════════════
  # Stage Components
  # ══════════════════════════════════════════

  defp config_stage(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto space-y-6 animate-slide-up">
      <%!-- Story Input Card --%>
      <div class="glass-surface rounded-2xl p-6 shadow-sm">
        <textarea
          name="novel_text"
          class="glass-input w-full resize-none text-base leading-relaxed border-none bg-transparent focus:ring-0 p-0"
          style="min-height: 40vh"
          placeholder={dgettext("projects", "Paste your story or novel text here...")}
          value={@novel_text}
          phx-change="update_novel_text"
          phx-debounce="500"
        />

        <%!-- Bottom toolbar --%>
        <div class="flex items-center justify-between pt-4 mt-4 border-t border-[var(--glass-stroke-soft)]">
          <div class="flex items-center gap-3">
            <%!-- Aspect ratio --%>
            <div class="flex items-center gap-1.5">
              <svg
                class="w-4 h-4 text-[var(--glass-text-tertiary)]"
                fill="none"
                stroke="currentColor"
                stroke-width="1.5"
                viewBox="0 0 24 24"
              >
                <rect x="2" y="4" width="20" height="16" rx="2" />
              </svg>
              <select
                phx-change="set_aspect_ratio"
                name="ratio"
                class="glass-input text-xs py-1 pl-2 pr-6 border-[var(--glass-stroke-soft)]"
              >
                <option value="9:16" selected={@aspect_ratio == "9:16"}>9:16</option>
                <option value="16:9" selected={@aspect_ratio == "16:9"}>16:9</option>
                <option value="1:1" selected={@aspect_ratio == "1:1"}>1:1</option>
                <option value="4:3" selected={@aspect_ratio == "4:3"}>4:3</option>
              </select>
            </div>

            <%!-- Art style --%>
            <div class="flex items-center gap-1.5">
              <svg
                class="w-4 h-4 text-[var(--glass-text-tertiary)]"
                fill="none"
                stroke="currentColor"
                stroke-width="1.5"
                viewBox="0 0 24 24"
              >
                <path d="M9.53 16.122a3 3 0 00-5.78 1.128 2.25 2.25 0 01-2.4 2.245 4.5 4.5 0 008.4-2.245c0-.399-.078-.78-.22-1.128zm0 0a15.998 15.998 0 003.388-1.62m-5.043-.025a15.994 15.994 0 011.622-3.395m3.42 3.42a15.995 15.995 0 004.764-4.648l3.876-5.814a1.151 1.151 0 00-1.597-1.597L14.146 6.32a15.996 15.996 0 00-4.649 4.763m3.42 3.42a6.776 6.776 0 00-3.42-3.42" />
              </svg>
              <select
                phx-change="set_art_style"
                name="style"
                class="glass-input text-xs py-1 pl-2 pr-6 border-[var(--glass-stroke-soft)]"
              >
                <option value="realistic" selected={@art_style == "realistic"}>
                  {dgettext("projects", "Realistic")}
                </option>
                <option value="anime" selected={@art_style == "anime"}>
                  {dgettext("projects", "Anime")}
                </option>
                <option value="oil_painting" selected={@art_style == "oil_painting"}>
                  {dgettext("projects", "Oil Painting")}
                </option>
                <option value="custom" selected={@art_style == "custom"}>
                  {dgettext("projects", "Custom")}
                </option>
              </select>
            </div>
          </div>

          <div class="flex items-center gap-3">
            <.prompt_btn id="NP_AI_STORY_OUTLINE" />
            <button
              type="button"
              class="text-sm text-[var(--glass-accent-from)] hover:text-[var(--glass-accent-to)] transition-colors flex items-center gap-1"
            >
              <svg
                class="w-4 h-4"
                fill="none"
                stroke="currentColor"
                stroke-width="1.5"
                viewBox="0 0 24 24"
              >
                <path d="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09z" />
              </svg>
              {dgettext("projects", "AI Write")}
            </button>
            <form phx-submit="start_pipeline" class="inline">
              <input type="hidden" name="novel_text" value={@novel_text} />
              <button
                type="submit"
                class="glass-btn glass-btn-primary text-sm py-2 px-6 flex items-center gap-2"
                disabled={String.trim(@novel_text || "") == ""}
              >
                {dgettext("projects", "Start Creating")}
                <svg
                  class="w-4 h-4"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  viewBox="0 0 24 24"
                >
                  <path stroke-linecap="round" stroke-linejoin="round" d="M13 7l5 5m0 0l-5 5m5-5H6" />
                </svg>
              </button>
            </form>
          </div>
        </div>
      </div>

      <%!-- Asset hint card --%>
      <div class="glass-surface rounded-xl p-4 flex items-start gap-3">
        <svg
          class="w-5 h-5 text-[var(--glass-text-tertiary)] mt-0.5 flex-shrink-0"
          fill="none"
          stroke="currentColor"
          stroke-width="1.5"
          viewBox="0 0 24 24"
        >
          <path d="M22 19a2 2 0 01-2 2H4a2 2 0 01-2-2V5a2 2 0 012-2h5l2 3h9a2 2 0 012 2z" />
        </svg>
        <div>
          <p class="text-sm font-medium text-[var(--glass-text-primary)]">
            {dgettext("projects", "Need custom characters and scenes?")}
          </p>
          <p class="text-xs text-[var(--glass-text-tertiary)] mt-0.5">
            {dgettext(
              "projects",
              "Click the Asset Library button in the top-right corner to upload asset documents or manually add characters/scenes. AI will prioritize using assets from the library."
            )}
          </p>
        </div>
      </div>
    </div>
    """
  end

  defp script_stage(assigns) do
    ~H"""
    <div class="space-y-5 animate-slide-up">
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-3">
          <div class="w-1 h-6 rounded-full bg-gradient-to-b from-[var(--glass-accent-from)] to-[var(--glass-accent-to)]">
          </div>
          <h2 class="text-lg font-bold text-[var(--glass-text-primary)]">
            {dgettext("projects", "Script Breakdown")}
          </h2>
          <.prompt_btn id="NP_AGENT_CLIP" />
          <.prompt_btn id="NP_SCREENPLAY_CONVERSION" />
        </div>
        <button phx-click="run_story_to_script" class="glass-btn glass-btn-ghost text-xs py-1.5 px-3">
          {dgettext("projects", "Generate Script")}
        </button>
      </div>

      <div class="grid grid-cols-12 gap-5">
        <%!-- Left: Script clips --%>
        <div class="col-span-12 lg:col-span-8 space-y-3">
          <div class="glass-surface rounded-xl p-5 border-l-2 border-[var(--glass-accent-from)]">
            <p class="text-sm text-[var(--glass-text-tertiary)]">
              {dgettext("projects", "Run 'Generate Script' to create clips from story text.")}
            </p>
          </div>
        </div>

        <%!-- Right: Project assets --%>
        <div class="col-span-12 lg:col-span-4 space-y-4">
          <div class="glass-surface rounded-xl p-4">
            <div class="flex items-center gap-2 mb-3">
              <h3 class="text-sm font-semibold text-[var(--glass-text-primary)]">
                {dgettext("projects", "Characters")} ({length(@characters)})
              </h3>
              <.prompt_btn id="NP_AGENT_CHARACTER_PROFILE" />
            </div>
            <div class="space-y-2">
              <%= for char <- @characters do %>
                <div class="flex items-center gap-2 p-2 rounded-lg hover:bg-[var(--glass-bg-muted)] transition-colors">
                  <div class="w-10 h-10 rounded-lg bg-[var(--glass-bg-muted)] flex items-center justify-center overflow-hidden flex-shrink-0">
                    <%= if char.image_url && char.image_url != "" do %>
                      <img src={char.image_url} class="w-full h-full object-cover" />
                    <% else %>
                      <span class="text-sm text-[var(--glass-text-tertiary)]">
                        {String.first(char.name || "?")}
                      </span>
                    <% end %>
                  </div>
                  <div class="min-w-0">
                    <p class="text-sm font-medium text-[var(--glass-text-primary)] truncate">
                      {char.name}
                    </p>
                    <p class="text-[10px] text-[var(--glass-text-tertiary)] truncate">
                      {char.description || char.introduction || ""}
                    </p>
                  </div>
                </div>
              <% end %>
              <button
                phx-click="add_character"
                class="w-full p-2 rounded-lg border border-dashed border-[var(--glass-stroke-base)] text-xs text-[var(--glass-text-tertiary)] hover:border-[var(--glass-accent-from)] hover:text-[var(--glass-accent-from)] transition-colors"
              >
                + {dgettext("projects", "Add Character")}
              </button>
            </div>
          </div>

          <div class="glass-surface rounded-xl p-4">
            <h3 class="text-sm font-semibold text-[var(--glass-text-primary)] mb-3">
              {dgettext("projects", "Locations")} ({length(@locations)})
            </h3>
            <div class="space-y-2">
              <%= for loc <- @locations do %>
                <div class="flex items-center gap-2 p-2 rounded-lg hover:bg-[var(--glass-bg-muted)] transition-colors">
                  <div class="w-10 h-7 rounded bg-[var(--glass-bg-muted)] flex items-center justify-center overflow-hidden flex-shrink-0">
                    <%= if loc.image_url && loc.image_url != "" do %>
                      <img src={loc.image_url} class="w-full h-full object-cover" />
                    <% else %>
                      <span class="text-[10px] text-[var(--glass-text-tertiary)]">L</span>
                    <% end %>
                  </div>
                  <p class="text-sm text-[var(--glass-text-primary)] truncate">{loc.name}</p>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>

      <%!-- Bottom action --%>
      <button
        phx-click="run_story_to_script"
        class="w-full glass-btn glass-btn-primary py-3 text-base flex items-center justify-center gap-2"
      >
        {dgettext("projects", "Confirm & Start Drawing")}
        <svg class="w-5 h-5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" d="M13 7l5 5m0 0l-5 5m5-5H6" />
        </svg>
      </button>
    </div>
    """
  end

  defp storyboard_stage(assigns) do
    all_panels = (assigns.storyboards || []) |> Enum.flat_map(fn sb -> sb.panels || [] end)
    image_count = Enum.count(all_panels, fn p -> p.image_url && p.image_url != "" end)
    video_count = Enum.count(all_panels, fn p -> p.video_url && p.video_url != "" end)

    assigns =
      assigns
      |> Map.put(:all_panels, all_panels)
      |> Map.put(:image_count, image_count)
      |> Map.put(:sb_video_count, video_count)
      |> Map.put(:total_count, length(all_panels))

    ~H"""
    <div class="space-y-5 animate-slide-up">
      <%!-- Header with accent bar --%>
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-3">
          <div class="w-1 h-6 rounded-full bg-gradient-to-b from-[var(--glass-accent-from)] to-[var(--glass-accent-to)]">
          </div>
          <h2 class="text-lg font-bold text-[var(--glass-text-primary)]">
            {dgettext("projects", "Storyboard")}
          </h2>
        </div>
        <div class="flex items-center gap-2">
          <.prompt_btn id="NP_AGENT_STORYBOARD_PLAN" />
          <.prompt_btn id="NP_SINGLE_PANEL_IMAGE" />
          <button
            phx-click="generate_all_images"
            class="glass-btn glass-btn-primary px-4 py-2 text-sm flex items-center gap-1.5"
          >
            <svg
              class="w-4 h-4"
              fill="none"
              stroke="currentColor"
              stroke-width="1.5"
              viewBox="0 0 24 24"
            >
              <path d="M2.25 15.75l5.159-5.159a2.25 2.25 0 013.182 0l5.159 5.159m-1.5-1.5l1.409-1.41a2.25 2.25 0 013.182 0l2.909 2.91m-18 3.75h16.5a1.5 1.5 0 001.5-1.5V6a1.5 1.5 0 00-1.5-1.5H3.75A1.5 1.5 0 002.25 6v12a1.5 1.5 0 001.5 1.5zm10.5-11.25h.008v.008h-.008V8.25zm.375 0a.375.375 0 11-.75 0 .375.375 0 01.75 0z" />
            </svg>
            {dgettext("projects", "Generate All Images")}
          </button>
        </div>
      </div>

      <%!-- Info bar with counts --%>
      <div :if={@total_count > 0} class="glass-surface rounded-xl px-5 py-3 flex items-center gap-6">
        <div class="flex items-center gap-2">
          <span class="text-sm text-[var(--glass-text-tertiary)]">
            {dgettext("projects", "Panels:")}
          </span>
          <span class="text-sm font-semibold text-[var(--glass-text-primary)]">{@total_count}</span>
        </div>
        <div class="w-px h-4 bg-[var(--glass-stroke-soft)]"></div>
        <div class="flex items-center gap-2">
          <span class="text-sm text-[var(--glass-text-tertiary)]">
            {dgettext("projects", "Images:")}
          </span>
          <span class={[
            "text-sm font-semibold",
            if(@image_count == @total_count,
              do: "text-green-500",
              else: "text-[var(--glass-text-primary)]"
            )
          ]}>
            {@image_count}/{@total_count}
          </span>
        </div>
        <div class="w-px h-4 bg-[var(--glass-stroke-soft)]"></div>
        <div class="flex items-center gap-2">
          <span class="text-sm text-[var(--glass-text-tertiary)]">
            {dgettext("projects", "Videos:")}
          </span>
          <span class={[
            "text-sm font-semibold",
            if(@sb_video_count == @total_count and @total_count > 0,
              do: "text-green-500",
              else: "text-[var(--glass-text-primary)]"
            )
          ]}>
            {@sb_video_count}/{@total_count}
          </span>
        </div>
      </div>

      <%= if @storyboards && length(@storyboards) > 0 do %>
        <%= for sb <- @storyboards do %>
          <div class="glass-surface rounded-xl p-4">
            <div class="grid grid-cols-4 gap-3">
              <%= for panel <- (sb.panels || []) do %>
                <div
                  class="glass-surface rounded-xl overflow-hidden cursor-pointer hover:shadow-lg hover:ring-1 hover:ring-[var(--glass-accent-from)]/30 transition-all duration-200 group"
                  phx-click="edit_panel"
                  phx-value-panel-id={panel.id}
                >
                  <div class="aspect-video bg-[var(--glass-bg-muted)] flex items-center justify-center relative">
                    <%= if panel.image_url && panel.image_url != "" do %>
                      <img
                        src={panel.image_url}
                        class="w-full h-full object-cover group-hover:scale-[1.02] transition-transform duration-300"
                      />
                    <% else %>
                      <div class="flex flex-col items-center gap-1">
                        <svg
                          class="w-8 h-8 text-[var(--glass-text-tertiary)] opacity-30"
                          fill="none"
                          stroke="currentColor"
                          stroke-width="1"
                          viewBox="0 0 24 24"
                        >
                          <path d="M2.25 15.75l5.159-5.159a2.25 2.25 0 013.182 0l5.159 5.159m-1.5-1.5l1.409-1.41a2.25 2.25 0 013.182 0l2.909 2.91m-18 3.75h16.5a1.5 1.5 0 001.5-1.5V6a1.5 1.5 0 00-1.5-1.5H3.75A1.5 1.5 0 002.25 6v12a1.5 1.5 0 001.5 1.5z" />
                        </svg>
                      </div>
                    <% end %>
                    <%!-- Task progress overlay --%>
                    <div
                      :if={task_progress_for(@task_progress, panel.id)}
                      class="absolute bottom-0 left-0 right-0 bg-black/60 px-2 py-1"
                    >
                      <div class="h-1 bg-[var(--glass-bg-muted)] rounded-full overflow-hidden">
                        <div
                          class="h-full bg-gradient-to-r from-[var(--glass-accent-from)] to-[var(--glass-accent-to)] transition-all"
                          style={"width: #{task_progress_for(@task_progress, panel.id)}%"}
                        />
                      </div>
                    </div>
                    <%!-- Edit icon on hover --%>
                    <div class="absolute top-1.5 right-1.5 opacity-0 group-hover:opacity-100 transition-opacity duration-200">
                      <span class="glass-chip text-[10px] bg-black/60 text-[var(--glass-text-primary)] backdrop-blur-sm">
                        {dgettext("projects", "Edit")}
                      </span>
                    </div>
                  </div>
                  <div class="p-2.5">
                    <p class="text-xs text-[var(--glass-text-secondary)] line-clamp-2 leading-relaxed">
                      {panel.description}
                    </p>
                    <div class="flex items-center gap-1.5 mt-1.5">
                      <%!-- Shot type as colored chip --%>
                      <span class="inline-flex items-center px-1.5 py-0.5 rounded text-[10px] font-medium bg-[var(--glass-accent-from)]/10 text-[var(--glass-accent-from)]">
                        {panel.shot_type || "MS"}
                      </span>
                      <span
                        :if={panel.video_url && panel.video_url != ""}
                        class="inline-flex items-center px-1.5 py-0.5 rounded text-[10px] font-medium bg-green-500/10 text-green-500"
                      >
                        {dgettext("projects", "Video")}
                      </span>
                    </div>
                    <%!-- Video prompt preview --%>
                    <p
                      :if={panel.video_prompt && panel.video_prompt != ""}
                      class="text-[10px] text-[var(--glass-text-tertiary)] mt-1.5 line-clamp-1 italic"
                    >
                      {panel.video_prompt}
                    </p>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      <% else %>
        <div class="glass-surface rounded-xl p-12 text-center">
          <svg
            class="w-12 h-12 mx-auto text-[var(--glass-text-tertiary)] opacity-30 mb-3"
            fill="none"
            stroke="currentColor"
            stroke-width="1"
            viewBox="0 0 24 24"
          >
            <path d="M2.25 15.75l5.159-5.159a2.25 2.25 0 013.182 0l5.159 5.159m-1.5-1.5l1.409-1.41a2.25 2.25 0 013.182 0l2.909 2.91m-18 3.75h16.5a1.5 1.5 0 001.5-1.5V6a1.5 1.5 0 00-1.5-1.5H3.75A1.5 1.5 0 002.25 6v12a1.5 1.5 0 001.5 1.5z" />
          </svg>
          <p class="text-[var(--glass-text-tertiary)]">
            {dgettext("projects", "No storyboards yet. Generate a script first.")}
          </p>
        </div>
      <% end %>

      <%!-- Panel Editor Modal --%>
      <.live_component
        :if={@editing_panel}
        module={AstraAutoExWeb.WorkspaceLive.PanelEditor}
        id="panel-editor"
        panel={@editing_panel}
        project={@project}
        current_scope={@current_scope}
      />
    </div>
    """
  end

  # Voice stage merged into film stage above

  defp video_stage(assigns) do
    all_panels =
      (assigns.storyboards || [])
      |> Enum.flat_map(fn sb -> sb.panels || [] end)

    video_count = Enum.count(all_panels, fn p -> p.video_url && p.video_url != "" end)

    voice_done =
      Enum.count(assigns.voice_lines || [], fn vl -> vl.audio_url && vl.audio_url != "" end)

    assigns =
      assigns
      |> Map.put(:all_panels, all_panels)
      |> Map.put(:video_count, video_count)
      |> Map.put(:voice_done, voice_done)

    ~H"""
    <div class="space-y-5 animate-slide-up">
      <%!-- Header with accent bar --%>
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-3">
          <div class="w-1 h-6 rounded-full bg-gradient-to-b from-[var(--glass-accent-from)] to-[var(--glass-accent-to)]">
          </div>
          <div>
            <h2 class="text-lg font-bold text-[var(--glass-text-primary)]">
              {dgettext("projects", "Film")}
            </h2>
            <p class="text-xs text-[var(--glass-text-tertiary)] mt-0.5">
              {dgettext("projects", "%{total} panels", total: length(@all_panels))}
              <span :if={@video_count > 0} class="text-green-500 ml-1">
                ({@video_count} {dgettext("projects", "generated")})
              </span>
              <span :if={@voice_done > 0} class="ml-2">
                | {dgettext("projects", "Voice:")} {@voice_done}/{length(@voice_lines || [])}
              </span>
            </p>
          </div>
        </div>
        <div class="flex items-center gap-2">
          <.prompt_btn id="NP_VOICE_ANALYSIS" />
          <button
            phx-click="generate_all_voices"
            class="glass-btn glass-btn-ghost text-xs py-1.5 px-3 flex items-center gap-1.5"
          >
            <svg
              class="w-3.5 h-3.5"
              fill="none"
              stroke="currentColor"
              stroke-width="1.5"
              viewBox="0 0 24 24"
            >
              <path d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m-4 0h8" />
            </svg>
            {dgettext("projects", "Generate All Voices")}
          </button>
          <button
            phx-click="generate_all_videos"
            class="glass-btn glass-btn-primary text-xs py-1.5 px-3 flex items-center gap-1.5"
          >
            <svg
              class="w-3.5 h-3.5"
              fill="none"
              stroke="currentColor"
              stroke-width="1.5"
              viewBox="0 0 24 24"
            >
              <path d="M5.25 5.653c0-.856.917-1.398 1.667-.986l11.54 6.347a1.125 1.125 0 010 1.972l-11.54 6.347a1.125 1.125 0 01-1.667-.986V5.653z" />
            </svg>
            {dgettext("projects", "Generate All Videos")}
          </button>
        </div>
      </div>

      <%!-- Voice lines collapsible --%>
      <details :if={@voice_lines && length(@voice_lines) > 0} class="glass-surface rounded-xl">
        <summary class="flex items-center gap-3 px-5 py-3 cursor-pointer select-none hover:bg-[var(--glass-bg-muted)] rounded-xl transition-colors">
          <svg
            class="w-5 h-5 text-[var(--glass-accent-from)]"
            fill="none"
            stroke="currentColor"
            stroke-width="1.5"
            viewBox="0 0 24 24"
          >
            <path d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m-4 0h8" />
          </svg>
          <div>
            <span class="text-sm font-semibold text-[var(--glass-text-primary)]">
              {dgettext("projects", "Voice Lines")}
            </span>
            <span class="text-xs text-[var(--glass-text-tertiary)] ml-2">
              {@voice_done}/{length(@voice_lines)} {dgettext("projects", "generated")}
            </span>
          </div>
        </summary>
        <div class="px-5 pb-4 space-y-1.5 border-t border-[var(--glass-stroke-soft)]">
          <%= for vl <- @voice_lines do %>
            <div class="flex items-center gap-3 py-2 hover:bg-[var(--glass-bg-muted)] rounded-lg px-2 transition-colors">
              <span class="w-6 text-center text-xs text-[var(--glass-text-tertiary)]">
                {vl.line_index + 1}
              </span>
              <span class="text-sm font-medium text-[var(--glass-text-primary)] w-20 truncate">
                {vl.speaker || "Narrator"}
              </span>
              <p class="text-xs text-[var(--glass-text-tertiary)] flex-1 truncate">
                {vl.content}
              </p>
              <%= if vl.audio_url && vl.audio_url != "" do %>
                <span class="inline-flex items-center px-1.5 py-0.5 rounded text-[10px] font-medium bg-green-500/10 text-green-500">
                  {dgettext("projects", "generated")}
                </span>
              <% else %>
                <button
                  phx-click="generate_voice_line"
                  phx-value-line-id={vl.id}
                  class="glass-btn glass-btn-ghost text-[10px] py-0.5 px-2"
                >
                  {dgettext("projects", "Generate")}
                </button>
              <% end %>
            </div>
          <% end %>
        </div>
      </details>

      <%!-- Video panels grid --%>
      <%= if length(@all_panels) > 0 do %>
        <div class="grid grid-cols-3 gap-4">
          <%= for {panel, idx} <- Enum.with_index(@all_panels) do %>
            <div class="glass-surface rounded-xl overflow-hidden group hover:shadow-lg transition-all duration-200">
              <div class="aspect-video bg-[var(--glass-bg-muted)] flex items-center justify-center relative">
                <span class="absolute top-2 left-2 inline-flex items-center px-1.5 py-0.5 rounded text-[10px] font-semibold bg-black/50 text-[var(--glass-text-primary)] backdrop-blur-sm z-10">
                  {idx + 1}
                </span>
                <%= if panel.video_url && panel.video_url != "" do %>
                  <video src={panel.video_url} class="w-full h-full object-cover" controls />
                  <div class="absolute top-2 right-2 z-10">
                    <svg
                      class="w-5 h-5 text-green-400 drop-shadow"
                      fill="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z" />
                    </svg>
                  </div>
                <% else %>
                  <%= if panel.image_url && panel.image_url != "" do %>
                    <img
                      src={panel.image_url}
                      class="w-full h-full object-cover opacity-60 group-hover:opacity-80 transition-opacity duration-300"
                    />
                    <div class="absolute inset-0 flex items-center justify-center">
                      <div class="w-10 h-10 rounded-full bg-black/30 flex items-center justify-center backdrop-blur-sm group-hover:scale-110 transition-transform">
                        <svg
                          class="w-5 h-5 text-[var(--glass-text-primary)]"
                          fill="currentColor"
                          viewBox="0 0 24 24"
                        >
                          <path d="M8 5v14l11-7z" />
                        </svg>
                      </div>
                    </div>
                  <% else %>
                    <div class="flex flex-col items-center gap-1">
                      <svg
                        class="w-6 h-6 text-[var(--glass-text-tertiary)] opacity-30"
                        fill="none"
                        stroke="currentColor"
                        stroke-width="1"
                        viewBox="0 0 24 24"
                      >
                        <path d="M2.25 15.75l5.159-5.159a2.25 2.25 0 013.182 0l5.159 5.159m-1.5-1.5l1.409-1.41a2.25 2.25 0 013.182 0l2.909 2.91m-18 3.75h16.5a1.5 1.5 0 001.5-1.5V6a1.5 1.5 0 00-1.5-1.5H3.75A1.5 1.5 0 002.25 6v12a1.5 1.5 0 001.5 1.5z" />
                      </svg>
                      <span class="text-[var(--glass-text-tertiary)] opacity-40 text-[10px]">
                        {dgettext("projects", "No image")}
                      </span>
                    </div>
                  <% end %>
                <% end %>
              </div>
              <div class="p-3">
                <div class="flex items-center gap-1.5 mb-1.5">
                  <span
                    :if={panel.shot_type}
                    class="inline-flex items-center px-1.5 py-0.5 rounded text-[10px] font-medium bg-[var(--glass-accent-from)]/10 text-[var(--glass-accent-from)]"
                  >
                    {panel.shot_type}
                  </span>
                </div>
                <p class="text-xs text-[var(--glass-text-secondary)] line-clamp-2">
                  {panel.description}
                </p>
              </div>
            </div>
          <% end %>
        </div>
      <% else %>
        <div class="glass-surface rounded-xl p-12 text-center">
          <svg
            class="w-12 h-12 mx-auto text-[var(--glass-text-tertiary)] opacity-30 mb-3"
            fill="none"
            stroke="currentColor"
            stroke-width="1"
            viewBox="0 0 24 24"
          >
            <path d="M5.25 5.653c0-.856.917-1.398 1.667-.986l11.54 6.347a1.125 1.125 0 010 1.972l-11.54 6.347a1.125 1.125 0 01-1.667-.986V5.653z" />
          </svg>
          <p class="text-[var(--glass-text-tertiary)]">
            {dgettext("projects", "Generate storyboard images first.")}
          </p>
        </div>
      <% end %>
    </div>
    """
  end

  defp compose_stage(assigns) do
    all_panels =
      (assigns.storyboards || [])
      |> Enum.flat_map(fn sb -> sb.panels || [] end)

    video_count = Enum.count(all_panels, fn p -> p.video_url && p.video_url != "" end)
    total = length(all_panels)

    voice_done =
      Enum.count(assigns.voice_lines || [], fn vl -> vl.audio_url && vl.audio_url != "" end)

    voice_total = length(assigns.voice_lines || [])
    compose_task = Enum.find(assigns.active_tasks, fn t -> t.type == "video_compose" end)

    selected_count = MapSet.size(assigns.selected_panels)

    assigns =
      assigns
      |> Map.put(:all_panels, all_panels)
      |> Map.put(:video_count, video_count)
      |> Map.put(:total, total)
      |> Map.put(:voice_done, voice_done)
      |> Map.put(:voice_total, voice_total)
      |> Map.put(:compose_task, compose_task)
      |> Map.put(:ready, video_count > 0 and video_count == total)
      |> Map.put(:selected_count, selected_count)

    ~H"""
    <div class="max-w-4xl mx-auto space-y-6 animate-slide-up">
      <%!-- Title centered --%>
      <div class="text-center py-4">
        <h1 class="text-2xl font-bold text-[var(--glass-text-primary)]">
          {dgettext("projects", "AI Edit")}
        </h1>
        <p class="text-sm text-[var(--glass-text-tertiary)] mt-1">
          {dgettext(
            "projects",
            "Select panels, configure effects, and compose the final video with one click."
          )}
        </p>
      </div>

      <%!-- Panel checklist --%>
      <div class="glass-surface rounded-xl overflow-hidden">
        <div class="flex items-center justify-between px-5 py-3 border-b border-[var(--glass-stroke-soft)]">
          <div class="flex items-center gap-2">
            <h3 class="text-sm font-semibold text-[var(--glass-text-primary)]">
              {dgettext("projects", "Panel Clips")}
            </h3>
            <span class="text-xs text-[var(--glass-text-tertiary)]">
              ({@video_count}/{@total} {dgettext("projects", "ready")})
            </span>
          </div>
          <button
            phx-click="select_all_panels"
            class="text-xs text-[var(--glass-accent-from)] hover:text-[var(--glass-accent-to)] transition-colors"
          >
            {dgettext("projects", "Select All")}
          </button>
        </div>
        <div class="divide-y divide-[var(--glass-stroke-soft)] max-h-[40vh] overflow-y-auto">
          <%= for {panel, idx} <- Enum.with_index(@all_panels) do %>
            <div
              class="flex items-center gap-3 px-5 py-2.5 hover:bg-[var(--glass-bg-muted)] transition-colors cursor-pointer"
              phx-click="toggle_panel_select"
              phx-value-panel-id={panel.id}
            >
              <%!-- Checkbox --%>
              <div class={[
                "w-4 h-4 rounded border flex items-center justify-center flex-shrink-0 transition-colors",
                if(MapSet.member?(@selected_panels, panel.id),
                  do: "bg-[var(--glass-accent-from)] border-[var(--glass-accent-from)]",
                  else: "border-[var(--glass-stroke-base)]"
                )
              ]}>
                <svg
                  :if={MapSet.member?(@selected_panels, panel.id)}
                  class="w-3 h-3 text-[var(--glass-text-on-accent)]"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="3"
                  viewBox="0 0 24 24"
                >
                  <path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7" />
                </svg>
              </div>
              <%!-- Index --%>
              <span class="text-xs text-[var(--glass-text-tertiary)] w-6 text-center">{idx + 1}</span>
              <%!-- Thumbnail --%>
              <div class="w-12 h-8 rounded bg-[var(--glass-bg-muted)] flex-shrink-0 overflow-hidden">
                <img
                  :if={panel.image_url && panel.image_url != ""}
                  src={panel.image_url}
                  class="w-full h-full object-cover"
                />
              </div>
              <%!-- Status chip --%>
              <%= if panel.video_url && panel.video_url != "" do %>
                <span class="inline-flex items-center px-1.5 py-0.5 rounded text-[10px] font-medium bg-green-500/10 text-green-500 flex-shrink-0">
                  {dgettext("projects", "Ready")}
                </span>
              <% else %>
                <span class="inline-flex items-center px-1.5 py-0.5 rounded text-[10px] font-medium bg-yellow-500/10 text-yellow-500 flex-shrink-0">
                  {dgettext("projects", "No Video")}
                </span>
              <% end %>
              <%!-- Description --%>
              <p class="text-xs text-[var(--glass-text-secondary)] flex-1 truncate">
                {panel.description}
              </p>
            </div>
          <% end %>
        </div>
      </div>

      <%!-- Compose config --%>
      <div class="glass-surface rounded-xl p-5 space-y-5">
        <h3 class="text-sm font-semibold text-[var(--glass-text-primary)]">
          {dgettext("projects", "Compose Settings")}
        </h3>

        <%!-- Transition --%>
        <div>
          <label class="text-xs text-[var(--glass-text-tertiary)] mb-2 block">
            {dgettext("projects", "Transition Effect")}
          </label>
          <div class="flex items-center gap-2">
            <%= for {val, label} <- [{"crossfade", dgettext("projects", "Crossfade")}, {"fade-black", dgettext("projects", "Fade Black")}, {"none", dgettext("projects", "None")}] do %>
              <button
                phx-click="set_compose_transition"
                phx-value-value={val}
                class={[
                  "px-3 py-1.5 rounded-lg text-xs font-medium transition-all",
                  if(@compose_transition == val,
                    do:
                      "bg-[var(--glass-accent-from)]/20 text-[var(--glass-accent-from)] ring-1 ring-[var(--glass-accent-from)]/30",
                    else:
                      "bg-[var(--glass-bg-muted)] text-[var(--glass-text-secondary)] hover:text-[var(--glass-text-primary)]"
                  )
                ]}
              >
                {label}
              </button>
            <% end %>
            <select
              phx-change="set_compose_transition_ms"
              name="value"
              class="glass-input text-xs py-1 pl-2 pr-6 ml-2"
            >
              <option value="300" selected={@compose_transition_ms == "300"}>300ms</option>
              <option value="500" selected={@compose_transition_ms == "500"}>500ms</option>
              <option value="800" selected={@compose_transition_ms == "800"}>800ms</option>
              <option value="1000" selected={@compose_transition_ms == "1000"}>1000ms</option>
            </select>
          </div>
        </div>

        <%!-- Subtitles --%>
        <div>
          <label class="text-xs text-[var(--glass-text-tertiary)] mb-2 block">
            {dgettext("projects", "Subtitle Mode")}
          </label>
          <div class="flex items-center gap-2">
            <%= for {val, label} <- [{"burn-in", dgettext("projects", "Burn-in")}, {"soft", dgettext("projects", "Soft Sub")}, {"both", dgettext("projects", "Both")}, {"none", dgettext("projects", "None")}] do %>
              <button
                phx-click="set_compose_subtitle"
                phx-value-value={val}
                class={[
                  "px-3 py-1.5 rounded-lg text-xs font-medium transition-all",
                  if(@compose_subtitle == val,
                    do:
                      "bg-[var(--glass-accent-from)]/20 text-[var(--glass-accent-from)] ring-1 ring-[var(--glass-accent-from)]/30",
                    else:
                      "bg-[var(--glass-bg-muted)] text-[var(--glass-text-secondary)] hover:text-[var(--glass-text-primary)]"
                  )
                ]}
              >
                {label}
              </button>
            <% end %>
          </div>
        </div>

        <%!-- BGM --%>
        <div>
          <label class="text-xs text-[var(--glass-text-tertiary)] mb-2 block">
            {dgettext("projects", "Background Music")}
          </label>
          <div class="flex items-center gap-2">
            <%= for {val, label} <- [{"none", dgettext("projects", "None")}, {"preset", dgettext("projects", "Preset")}] do %>
              <button
                phx-click="set_compose_bgm"
                phx-value-value={val}
                class={[
                  "px-3 py-1.5 rounded-lg text-xs font-medium transition-all",
                  if(@compose_bgm == val,
                    do:
                      "bg-[var(--glass-accent-from)]/20 text-[var(--glass-accent-from)] ring-1 ring-[var(--glass-accent-from)]/30",
                    else:
                      "bg-[var(--glass-bg-muted)] text-[var(--glass-text-secondary)] hover:text-[var(--glass-text-primary)]"
                  )
                ]}
              >
                {label}
              </button>
            <% end %>
          </div>
        </div>
      </div>

      <%!-- Compose progress (if running) --%>
      <div :if={@compose_task} class="glass-surface rounded-xl p-5">
        <div class="flex items-center gap-3 mb-3">
          <div class="w-3 h-3 rounded-full bg-[var(--glass-accent-from)] animate-pulse" />
          <h3 class="text-sm font-semibold text-[var(--glass-text-primary)]">
            {dgettext("projects", "Composing...")}
          </h3>
        </div>
        <div class="h-1.5 bg-[var(--glass-bg-muted)] rounded-full overflow-hidden">
          <div
            class="h-full bg-gradient-to-r from-[var(--glass-accent-from)] to-[var(--glass-accent-to)] transition-all animate-pulse"
            style="width: 60%"
          />
        </div>
        <p class="text-xs text-[var(--glass-text-tertiary)] mt-2">
          {dgettext("projects", "Processing video composition. This may take several minutes.")}
        </p>
      </div>

      <%!-- One-click compose button --%>
      <button
        phx-click="compose_video"
        class={[
          "w-full py-3.5 rounded-xl text-base font-semibold flex items-center justify-center gap-2 transition-all",
          if(@ready and @selected_count > 0,
            do: "glass-btn glass-btn-primary hover:shadow-lg",
            else: "glass-btn glass-btn-primary opacity-50 cursor-not-allowed"
          )
        ]}
        disabled={!@ready or @selected_count == 0}
      >
        <svg class="w-5 h-5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="M5.25 5.653c0-.856.917-1.398 1.667-.986l11.54 6.347a1.125 1.125 0 010 1.972l-11.54 6.347a1.125 1.125 0 01-1.667-.986V5.653z"
          />
        </svg>
        {dgettext("projects", "Compose Video")} ({@selected_count} {dgettext("projects", "panels")})
      </button>

      <%!-- Compose result placeholder --%>
      <div class="glass-surface rounded-xl p-8 text-center">
        <svg
          class="w-12 h-12 mx-auto text-[var(--glass-text-tertiary)] opacity-30 mb-3"
          fill="none"
          stroke="currentColor"
          stroke-width="1"
          viewBox="0 0 24 24"
        >
          <path d="M3.375 19.5h17.25m-17.25 0a1.125 1.125 0 01-1.125-1.125M3.375 19.5h1.5C5.496 19.5 6 18.996 6 18.375m-2.625 0V5.625m0 12.75v-1.5c0-.621.504-1.125 1.125-1.125m18.375 2.625V5.625m0 12.75c0 .621-.504 1.125-1.125 1.125m1.125-1.125v-1.5c0-.621-.504-1.125-1.125-1.125m0 3.75h-1.5A1.125 1.125 0 0118 18.375M20.625 4.5H3.375m17.25 0c.621 0 1.125.504 1.125 1.125M20.625 4.5h-1.5C18.504 4.5 18 5.004 18 5.625m3.75 0v1.5c0 .621-.504 1.125-1.125 1.125M3.375 4.5c-.621 0-1.125.504-1.125 1.125M3.375 4.5h1.5C5.496 4.5 6 5.004 6 5.625m-2.625 0v1.5c0 .621.504 1.125 1.125 1.125m0 0h1.5m-1.5 0c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125m1.5-3.75C5.496 8.25 6 7.746 6 7.125v-1.5M4.875 8.25C5.496 8.25 6 8.754 6 9.375v1.5m0-5.25v5.25m0-5.25C6 5.004 6.504 4.5 7.125 4.5h9.75c.621 0 1.125.504 1.125 1.125m1.125 2.625h1.5m-1.5 0A1.125 1.125 0 0118 7.125v-1.5m1.125 2.625c-.621 0-1.125.504-1.125 1.125v1.5m2.625-2.625c.621 0 1.125.504 1.125 1.125v1.5c0 .621-.504 1.125-1.125 1.125M18 5.625v5.25M7.125 12h9.75m-9.75 0A1.125 1.125 0 016 10.875M7.125 12C6.504 12 6 12.504 6 13.125m0-2.25C6 11.496 5.496 12 4.875 12M18 10.875c0 .621-.504 1.125-1.125 1.125M18 10.875c0 .621.504 1.125 1.125 1.125m-2.25 0c.621 0 1.125.504 1.125 1.125m-12 5.25v-5.25m0 5.25c0 .621.504 1.125 1.125 1.125h9.75c.621 0 1.125-.504 1.125-1.125m-12 0v-1.5c0-.621-.504-1.125-1.125-1.125M18 18.375v-5.25m0 5.25v-1.5c0-.621.504-1.125 1.125-1.125M18 13.125v1.5c0 .621.504 1.125 1.125 1.125M18 13.125c0-.621.504-1.125 1.125-1.125M6 13.125v1.5c0 .621-.504 1.125-1.125 1.125M6 13.125C6 12.504 5.496 12 4.875 12m-1.5 0h1.5m-1.5 0c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125m1.5-3.75C5.496 12 6 12.504 6 13.125" />
        </svg>
        <p class="text-sm text-[var(--glass-text-tertiary)]">
          {dgettext("projects", "Composed video will appear here after processing.")}
        </p>
      </div>
    </div>
    """
  end

  # ══════════════════════════════════════════
  # Events
  # ══════════════════════════════════════════

  @impl true
  def handle_event("switch_stage", %{"stage" => stage}, socket) when stage in @stages do
    {:noreply, assign(socket, :stage, stage)}
  end

  def handle_event("select_episode", %{"_target" => _, "value" => episode_id}, socket) do
    episode = Enum.find(socket.assigns.episodes, &(&1.id == episode_id))
    storyboards = load_storyboards(episode)
    {:noreply, socket |> assign(:current_episode, episode) |> assign(:storyboards, storyboards)}
  end

  def handle_event("select_episode", params, socket) do
    # Handle alternate param format
    episode_id = params["episode_id"] || params["value"]

    if episode_id do
      handle_event("select_episode", %{"_target" => [], "value" => episode_id}, socket)
    else
      {:noreply, socket}
    end
  end

  def handle_event("toggle_assistant", _, socket) do
    {:noreply, assign(socket, :show_assistant, !socket.assigns.show_assistant)}
  end

  def handle_event("start_pipeline", %{"novel_text" => text}, socket) do
    project = socket.assigns.project
    user_id = socket.assigns.current_scope.user.id

    # Create episode if none exists
    episode = socket.assigns.current_episode || create_default_episode(project, user_id)

    # Start story-to-script task
    Tasks.create_task(%{
      user_id: user_id,
      project_id: project.id,
      episode_id: episode.id,
      type: "story_to_script_run",
      target_type: "episode",
      target_id: episode.id,
      payload: %{"novel_text" => text, "episode_id" => episode.id, "auto_continue" => true}
    })

    {:noreply,
     socket
     |> assign(:novel_text, text)
     |> put_flash(:info, dgettext("projects", "Pipeline started. Processing your story..."))}
  end

  def handle_event("run_story_to_script", _, socket) do
    {:noreply,
     put_flash(socket, :info, dgettext("projects", "Use Config stage to input story text first."))}
  end

  def handle_event("generate_all_images", _, socket) do
    dispatch_batch_task(socket, "image_panel", "panel")
  end

  def handle_event("generate_all_voices", _, socket) do
    dispatch_batch_task(socket, "voice_line", "voice_line")
  end

  def handle_event("generate_all_videos", _, socket) do
    dispatch_batch_task(socket, "video_panel", "panel")
  end

  def handle_event("compose_video", _, socket) do
    project = socket.assigns.project
    user_id = socket.assigns.current_scope.user.id
    episode = socket.assigns.current_episode

    if episode do
      Tasks.create_task(%{
        user_id: user_id,
        project_id: project.id,
        episode_id: episode.id,
        type: "video_compose",
        target_type: "episode",
        target_id: episode.id,
        payload: %{"episode_id" => episode.id}
      })

      {:noreply, put_flash(socket, :info, dgettext("projects", "Compose task queued."))}
    else
      {:noreply, put_flash(socket, :error, dgettext("projects", "Select an episode first."))}
    end
  end

  def handle_event("add_character", _, socket) do
    {:noreply, assign(socket, show_character_modal: true, editing_character: nil)}
  end

  def handle_event("close_character_modal", _, socket) do
    {:noreply, assign(socket, show_character_modal: false, editing_character: nil)}
  end

  def handle_event("add_location", _, socket) do
    {:noreply, assign(socket, show_location_modal: true, editing_location: nil)}
  end

  def handle_event("close_location_modal", _, socket) do
    {:noreply, assign(socket, show_location_modal: false, editing_location: nil)}
  end

  def handle_event("open_voice_picker", %{"line-id" => line_id}, socket) do
    {:noreply, assign(socket, show_voice_picker: true, voice_picker_target: line_id)}
  end

  def handle_event("close_voice_picker", _, socket) do
    {:noreply, assign(socket, show_voice_picker: false, voice_picker_target: nil)}
  end

  def handle_event(
        "reorder_panels",
        %{"source_id" => source_id, "target_id" => target_id},
        socket
      ) do
    source = Production.get_panel!(source_id)
    target = Production.get_panel!(target_id)

    # Swap panel_index
    Production.update_panel(source, %{panel_index: target.panel_index})
    Production.update_panel(target, %{panel_index: source.panel_index})

    storyboards = load_storyboards(socket.assigns.current_episode)
    {:noreply, assign(socket, :storyboards, storyboards)}
  end

  def handle_event("edit_panel", %{"panel-id" => panel_id}, socket) do
    panel = Production.get_panel!(panel_id)
    {:noreply, assign(socket, :editing_panel, panel)}
  end

  def handle_event("close_panel_editor", _, socket) do
    {:noreply, assign(socket, :editing_panel, nil)}
  end

  def handle_event("view_pipeline_prompt", %{"id" => prompt_id}, socket) do
    alias AstraAutoEx.AI.PromptCatalog

    locale = "zh"

    label =
      case PromptCatalog.get_entry(String.to_atom(prompt_id)) do
        %{label_zh: zh, label_en: en} -> "#{zh} — #{en}"
        _ -> prompt_id
      end

    text =
      case PromptCatalog.get_template(String.to_atom(prompt_id), locale) do
        {:ok, t} -> t
        {:error, _} -> "(template not found)"
      end

    {:noreply, assign(socket, :viewing_prompt, %{id: prompt_id, label: label, text: text})}
  end

  def handle_event("close_prompt_viewer", _, socket) do
    {:noreply, assign(socket, :viewing_prompt, nil)}
  end

  def handle_event("generate_panel_image", %{"panel-id" => panel_id}, socket) do
    project = socket.assigns.project
    user_id = socket.assigns.current_scope.user.id

    Tasks.create_task(%{
      user_id: user_id,
      project_id: project.id,
      episode_id: socket.assigns.current_episode && socket.assigns.current_episode.id,
      type: "image_panel",
      target_type: "panel",
      target_id: panel_id,
      payload: %{"panel_id" => panel_id}
    })

    {:noreply, put_flash(socket, :info, "Image generation queued.")}
  end

  def handle_event("generate_panel_video", %{"panel-id" => panel_id}, socket) do
    project = socket.assigns.project
    user_id = socket.assigns.current_scope.user.id

    Tasks.create_task(%{
      user_id: user_id,
      project_id: project.id,
      episode_id: socket.assigns.current_episode && socket.assigns.current_episode.id,
      type: "video_panel",
      target_type: "panel",
      target_id: panel_id,
      payload: %{"panel_id" => panel_id}
    })

    {:noreply, put_flash(socket, :info, "Video generation queued.")}
  end

  def handle_event("generate_voice_line", %{"line-id" => line_id}, socket) do
    project = socket.assigns.project
    user_id = socket.assigns.current_scope.user.id

    Tasks.create_task(%{
      user_id: user_id,
      project_id: project.id,
      episode_id: socket.assigns.current_episode && socket.assigns.current_episode.id,
      type: "voice_line",
      target_type: "voice_line",
      target_id: line_id,
      payload: %{"voice_line_id" => line_id}
    })

    {:noreply, put_flash(socket, :info, "Voice generation queued.")}
  end

  def handle_event("update_novel_text", %{"novel_text" => text}, socket) do
    {:noreply, assign(socket, :novel_text, text)}
  end

  def handle_event("set_aspect_ratio", %{"ratio" => ratio}, socket) do
    {:noreply, assign(socket, :aspect_ratio, ratio)}
  end

  def handle_event("set_art_style", %{"style" => style}, socket) do
    {:noreply, assign(socket, :art_style, style)}
  end

  def handle_event("set_compose_transition", %{"value" => v}, socket) do
    {:noreply, assign(socket, :compose_transition, v)}
  end

  def handle_event("set_compose_transition_ms", %{"value" => v}, socket) do
    {:noreply, assign(socket, :compose_transition_ms, v)}
  end

  def handle_event("set_compose_subtitle", %{"value" => v}, socket) do
    {:noreply, assign(socket, :compose_subtitle, v)}
  end

  def handle_event("set_compose_bgm", %{"value" => v}, socket) do
    {:noreply, assign(socket, :compose_bgm, v)}
  end

  def handle_event("toggle_panel_select", %{"panel-id" => id}, socket) do
    selected = socket.assigns.selected_panels

    new =
      if MapSet.member?(selected, id),
        do: MapSet.delete(selected, id),
        else: MapSet.put(selected, id)

    {:noreply, assign(socket, :selected_panels, new)}
  end

  def handle_event("select_all_panels", _, socket) do
    all_ids =
      (socket.assigns.storyboards || [])
      |> Enum.flat_map(fn sb -> sb.panels || [] end)
      |> Enum.filter(fn p -> p.video_url && p.video_url != "" end)
      |> Enum.map(& &1.id)
      |> MapSet.new()

    {:noreply, assign(socket, :selected_panels, all_ids)}
  end

  @impl true
  def handle_info({:task_event, event}, socket) do
    project_id = socket.assigns.project.id
    active = Tasks.list_project_tasks(project_id, status: "processing")
    storyboards = load_storyboards(socket.assigns.current_episode)
    voice_lines = load_voice_lines(socket.assigns.current_episode)

    # Update task progress map
    task_progress =
      case event do
        %{type: "task.processing", target_id: target_id} ->
          Map.put(socket.assigns.task_progress, target_id, 10)

        %{type: "task.completed", target_id: target_id} ->
          Map.delete(socket.assigns.task_progress, target_id)

        %{type: "task.failed", target_id: target_id} ->
          Map.delete(socket.assigns.task_progress, target_id)

        _ ->
          socket.assigns.task_progress
      end

    # Refresh editing panel if it was updated
    editing_panel =
      if socket.assigns.editing_panel do
        try do
          Production.get_panel!(socket.assigns.editing_panel.id)
        rescue
          _ -> nil
        end
      end

    {:noreply,
     socket
     |> assign(:active_tasks, active)
     |> assign(:storyboards, storyboards)
     |> assign(:voice_lines, voice_lines)
     |> assign(:task_progress, task_progress)
     |> assign(:editing_panel, editing_panel)}
  end

  def handle_info({:character_saved, _char}, socket) do
    characters = Characters.list_characters(socket.assigns.project.id)

    {:noreply,
     socket
     |> assign(:characters, characters)
     |> assign(:show_character_modal, false)
     |> put_flash(:info, "Character saved.")}
  end

  def handle_info({:location_saved, _loc}, socket) do
    locations = Locations.list_locations(socket.assigns.project.id)

    {:noreply,
     socket
     |> assign(:locations, locations)
     |> assign(:show_location_modal, false)
     |> put_flash(:info, "Location saved.")}
  end

  def handle_info(
        {:voice_selected, %{voice_id: voice_id, emotion: emotion, target_id: target_id}},
        socket
      ) do
    if target_id do
      vl = Production.get_voice_line!(target_id)
      Production.update_voice_line(vl, %{voice_preset_id: voice_id, emotion_prompt: emotion})
    end

    voice_lines = load_voice_lines(socket.assigns.current_episode)

    {:noreply,
     socket
     |> assign(:voice_lines, voice_lines)
     |> assign(:show_voice_picker, false)}
  end

  def handle_info({:files_uploaded, _files}, socket) do
    {:noreply, put_flash(socket, :info, "Files uploaded successfully.")}
  end

  def handle_info({:panel_updated, panel}, socket) do
    storyboards = load_storyboards(socket.assigns.current_episode)
    {:noreply, socket |> assign(:storyboards, storyboards) |> assign(:editing_panel, panel)}
  end

  def handle_info({:assistant_generate, messages, component_id}, socket) do
    user_id = socket.assigns.current_scope.user.id
    alias AstraAutoEx.Workers.Handlers.Helpers

    Task.start(fn ->
      model_config = Helpers.get_model_config(user_id, nil, :llm)
      provider = model_config["provider"]

      contents =
        Enum.map(messages, fn m ->
          role = if m.role == "user", do: "user", else: "model"
          %{"role" => role, "parts" => [%{"text" => m.content}]}
        end)

      request = %{model: model_config["model"], contents: contents}

      response =
        case Helpers.chat(user_id, provider, request) do
          {:ok, text} -> text
          {:error, reason} -> "Error: #{inspect(reason)}"
        end

      send(self(), {:assistant_response, component_id, response})
    end)

    {:noreply, socket}
  end

  def handle_info({:assistant_response, component_id, response}, socket) do
    send_update(AstraAutoExWeb.AssistantLive.Panel,
      id: component_id,
      ai_response: response
    )

    {:noreply, socket}
  end

  # ══════════════════════════════════════════
  # Helpers
  # ══════════════════════════════════════════

  defp load_storyboards(nil), do: []
  defp load_storyboards(episode), do: Production.list_storyboards(episode.id)

  defp load_voice_lines(nil), do: []
  defp load_voice_lines(episode), do: Production.list_voice_lines(episode.id)

  defp task_progress_for(progress_map, panel_id) do
    Map.get(progress_map, panel_id)
  end

  defp create_default_episode(project, user_id) do
    {:ok, ep} =
      Production.create_episode(%{
        project_id: project.id,
        user_id: user_id,
        episode_number: 1,
        title: "Episode 1",
        status: "draft"
      })

    ep
  end

  defp dispatch_batch_task(socket, task_type, target_type) do
    project = socket.assigns.project
    user_id = socket.assigns.current_scope.user.id
    episode = socket.assigns.current_episode

    if episode do
      storyboards = Production.list_storyboards(episode.id)
      panels = Enum.flat_map(storyboards, &Production.list_panels(&1.id))

      Enum.each(panels, fn panel ->
        Tasks.create_task(%{
          user_id: user_id,
          project_id: project.id,
          episode_id: episode.id,
          type: task_type,
          target_type: target_type,
          target_id: panel.id,
          payload: %{"panel_id" => panel.id}
        })
      end)

      {:noreply, put_flash(socket, :info, "#{length(panels)} tasks queued.")}
    else
      {:noreply, put_flash(socket, :error, dgettext("projects", "Select an episode first."))}
    end
  end

  defp stage_label("story"), do: dgettext("projects", "Story")
  defp stage_label("script"), do: dgettext("projects", "Script")
  defp stage_label("storyboard"), do: dgettext("projects", "Storyboard")
  defp stage_label("film"), do: dgettext("projects", "Film")
  defp stage_label("compose"), do: dgettext("projects", "AI Edit")
end
