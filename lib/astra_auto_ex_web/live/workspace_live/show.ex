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
     |> assign(:clips, load_clips(current_episode))
     |> assign(:active_tasks, Tasks.list_project_tasks(project_id, status: "processing"))
     |> assign(:novel_text, (current_episode && current_episode.novel_text) || "")
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
     |> assign(:art_style, load_novel_field(project, :art_style, "realistic"))
     |> assign(:auto_chain, load_novel_field(project, :auto_chain_enabled, false))
     |> assign(:full_auto_chain, load_novel_field(project, :full_auto_chain_enabled, false))
     |> assign(:pipeline_state, :idle)
     |> assign(:show_ai_write, false)
     |> assign(:show_wizard, false)
     |> assign(:show_art_style_modal, false)
     |> assign(:custom_art_prompt, "")
     |> assign(:compose_transition, "crossfade")
     |> assign(:compose_transition_ms, "500")
     |> assign(:compose_subtitle, "both")
     |> assign(:compose_bgm, "none")
     |> assign(:selected_panels, MapSet.new())
     |> assign(:extracting_entities, false)
     |> assign(:extracted_entities, nil)
     |> assign(:skip_voice, false)
     |> assign(:promo_copy, "")
     |> assign(:ref_image_urls, [])
     |> assign(:ref_image_prompt, "")
     |> allow_upload(:ref_images,
       accept: ~w(.jpg .jpeg .png .webp),
       max_entries: 5,
       max_file_size: 10_000_000,
       auto_upload: true,
       progress: &handle_ref_upload_progress/3
     )
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
                    {ep.title || "第#{ep.episode_number}集"}
                  </option>
                <% end %>
              </select>
              <span class="text-xs text-[var(--glass-text-tertiary)]">
                ({length(@episodes)} {dgettext("projects", "episodes")})
              </span>
              <button
                phx-click="add_episode"
                class="ml-1 p-1 rounded-md text-[var(--glass-text-tertiary)] hover:text-[var(--glass-accent-from)] hover:bg-[var(--glass-bg-muted)] transition-all"
                title={dgettext("projects", "Add Episode")}
              >
                <svg
                  class="w-4 h-4"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="1.5"
                  viewBox="0 0 24 24"
                >
                  <path d="M12 4.5v15m7.5-7.5h-15" />
                </svg>
              </button>
              <button
                :if={length(@episodes) > 1}
                phx-click="delete_episode"
                data-confirm={dgettext("projects", "Delete current episode? This cannot be undone.")}
                class="p-1 rounded-md text-[var(--glass-text-tertiary)] hover:text-red-400 hover:bg-red-500/10 transition-all"
                title={dgettext("projects", "Delete Episode")}
              >
                <svg
                  class="w-4 h-4"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="1.5"
                  viewBox="0 0 24 24"
                >
                  <path d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0" />
                </svg>
              </button>
            </div>
          </div>
          <%!-- Center: Stage tabs with step indicator --%>
          <div class="flex items-center gap-0.5 p-1 rounded-xl bg-[var(--glass-bg-muted)]">
            <%= for {stage, idx} <- Enum.with_index(@stages) do %>
              <% current_idx = Enum.find_index(@stages, &(&1 == @stage)) || 0 %>
              <button
                phx-click="switch_stage"
                phx-value-stage={stage}
                class={[
                  "relative px-4 py-1.5 rounded-lg text-sm font-medium transition-all duration-300",
                  if(@stage == stage,
                    do: "bg-white/80 dark:bg-white/10 text-[var(--glass-accent-from)] shadow-sm",
                    else:
                      if(idx < current_idx,
                        do: "text-[var(--glass-accent-from)]/60",
                        else:
                          "text-[var(--glass-text-tertiary)] hover:text-[var(--glass-text-primary)]"
                      )
                  )
                ]}
              >
                <span class="flex items-center gap-1.5">
                  <span
                    :if={idx < current_idx}
                    class="w-3.5 h-3.5 rounded-full bg-[var(--glass-accent-from)]/20 text-[var(--glass-accent-from)] flex items-center justify-center"
                  >
                    <svg
                      class="w-2.5 h-2.5"
                      fill="none"
                      stroke="currentColor"
                      stroke-width="3"
                      viewBox="0 0 24 24"
                    >
                      <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5" />
                    </svg>
                  </span>
                  {stage_label(stage)}
                </span>
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
              class={[
                "glass-btn text-xs py-1.5 px-3 flex items-center gap-1.5 transition-all",
                if(@show_assistant,
                  do:
                    "bg-[var(--glass-accent-from)]/15 text-[var(--glass-accent-from)] ring-1 ring-[var(--glass-accent-from)]/30",
                  else: "glass-btn-ghost"
                )
              ]}
              title="AI 助手"
            >
              <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
                <path d="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09z" />
              </svg>
              AI 助手
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
            {dgettext("projects", "Currently editing:")} {@current_episode.title ||
              "Episode #{@current_episode.episode_number}"}
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
                  auto_chain={@auto_chain}
                  full_auto_chain={@full_auto_chain}
                  pipeline_state={@pipeline_state}
                  active_tasks={@active_tasks}
                />
              <% "script" -> %>
                <.script_stage
                  episodes={@episodes}
                  current_episode={@current_episode}
                  characters={@characters}
                  locations={@locations}
                  extracting_entities={@extracting_entities}
                />
              <% "storyboard" -> %>
                <.storyboard_stage
                  current_episode={@current_episode}
                  storyboards={@storyboards}
                  editing_panel={@editing_panel}
                  task_progress={@task_progress}
                  project={@project}
                  current_scope={@current_scope}
                  ref_image_urls={@ref_image_urls}
                  ref_image_prompt={@ref_image_prompt}
                  uploads={@uploads}
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
        class="fixed top-[52px] right-0 bottom-0 w-80 glass-surface border-l border-[var(--glass-stroke-base)] flex flex-col z-40 shadow-2xl animate-slide-in-right"
      >
        <.live_component
          module={AstraAutoExWeb.AssistantLive.Panel}
          id="assistant-panel"
          project={@project}
          current_scope={@current_scope}
          novel_text={@novel_text}
          characters={@characters}
          locations={@locations}
          stage={@stage}
        />
      </aside>
      <%!-- Floating AI Assistant toggle button --%>
      <button
        :if={!@show_assistant}
        phx-click="toggle_assistant"
        class="fixed bottom-6 right-6 z-50 w-12 h-12 rounded-full bg-gradient-to-br from-[var(--glass-accent-from)] to-[var(--glass-accent-to)] text-white shadow-lg hover:shadow-xl hover:scale-110 transition-all flex items-center justify-center group"
        title="AI 助手"
      >
        <svg
          class="w-5 h-5 group-hover:scale-110 transition-transform"
          fill="currentColor"
          viewBox="0 0 24 24"
        >
          <path d="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09zM18.259 8.715L18 9.75l-.259-1.035a3.375 3.375 0 00-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 002.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 002.455 2.456L21.75 6l-1.036.259a3.375 3.375 0 00-2.455 2.456z" />
        </svg>
      </button>
      <%!-- Prompt Viewer Modal --%>
      <.prompt_viewer_modal :if={@viewing_prompt} prompt={@viewing_prompt} /> <%!-- Import Wizard --%>
      <.live_component
        :if={@show_wizard}
        module={AstraAutoExWeb.WorkspaceLive.ImportWizard}
        id="import-wizard"
      /> <%!-- Pipeline Progress Modal --%>
      <.live_component
        module={AstraAutoExWeb.WorkspaceLive.PipelineModal}
        id="pipeline-modal"
        active={@pipeline_state == :running}
        status_messages={["准备中...", "思考中...", "写作中...", "润色中...", "即将完成..."]}
      /> <%!-- Voice Picker --%>
      <.live_component
        :if={@show_voice_picker}
        module={AstraAutoExWeb.WorkspaceLive.VoicePicker}
        id="voice-picker"
        target={@voice_picker_target}
      /> <%!-- Art Style Custom Modal --%>
      <.live_component
        :if={@show_art_style_modal}
        module={AstraAutoExWeb.WorkspaceLive.ArtStyleModal}
        id="art-style-modal"
        current_prompt={@custom_art_prompt}
      /> <%!-- AI Write Modal (workspace version) --%>
      <%= if @show_ai_write do %>
        <div class="fixed inset-0 z-50 flex items-center justify-center">
          <div class="absolute inset-0 bg-black/60 backdrop-blur-sm" phx-click="close_ai_write" />
          <div class="glass-card p-6 w-full max-w-lg relative z-10 shadow-2xl">
            <div class="flex items-center justify-between mb-5">
              <div class="flex items-center gap-3">
                <div class="w-10 h-10 rounded-xl bg-gradient-to-br from-purple-500 to-blue-500 flex items-center justify-center">
                  <svg
                    class="w-5 h-5 text-white"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="1.5"
                    viewBox="0 0 24 24"
                  >
                    <path d="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09z" />
                  </svg>
                </div>

                <div>
                  <h3 class="text-lg font-bold text-[var(--glass-text-primary)]">AI 创作助手</h3>

                  <p class="text-xs text-[var(--glass-text-tertiary)]">输入创意灵感，AI 生成故事大纲</p>
                </div>
              </div>

              <button
                phx-click="close_ai_write"
                class="text-[var(--glass-text-tertiary)] hover:text-[var(--glass-text-primary)]"
              >
                <svg
                  class="w-5 h-5"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  viewBox="0 0 24 24"
                >
                  <path d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>

            <%= case assigns[:ai_write_phase] || :input do %>
              <% :input -> %>
                <div class="space-y-4">
                  <h4 class="text-sm font-semibold text-[var(--glass-text-primary)]">输入你的创意内容</h4>
                  <textarea
                    phx-change="update_ai_write_prompt"
                    phx-debounce="300"
                    name="prompt"
                    rows="6"
                    class="glass-input w-full resize-none"
                    placeholder="输入关键词、IP名称、故事灵感...\n\n例如：\n• 古代宫廷 复仇 悬疑 女主角\n• 现代霸总+替身新娘+复仇逆袭"
                  ><%= assigns[:ai_write_prompt] || "" %></textarea>
                  <p class="text-xs text-[var(--glass-text-tertiary)] bg-[var(--glass-bg-muted)] rounded-lg p-2.5">
                    AI 将生成完整多集短剧大纲，确认后自动填入故事输入区域并启动管线。
                  </p>

                  <div class="flex justify-end">
                    <button
                      phx-click="generate_ai_write"
                      disabled={String.trim(assigns[:ai_write_prompt] || "") == ""}
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
                      </svg>
                      生成剧本大纲
                    </button>
                  </div>
                </div>
              <% :loading -> %>
                <div class="text-center py-12">
                  <div class="inline-flex items-center justify-center w-16 h-16 rounded-full bg-gradient-to-br from-purple-500 to-blue-500 mb-4 animate-pulse">
                    <svg class="w-8 h-8 text-white animate-spin" fill="none" viewBox="0 0 24 24">
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
                  </div>

                  <p class="text-[var(--glass-text-primary)] font-medium">AI 正在创作中...</p>

                  <p class="text-xs text-[var(--glass-text-tertiary)] mt-1">请稍候，这可能需要 30-60 秒</p>
                </div>
              <% :result -> %>
                <div class="space-y-4">
                  <textarea
                    rows="12"
                    class="glass-input w-full resize-none text-sm"
                    readonly
                  ><%= assigns[:ai_write_outline] || "" %></textarea>
                  <div class="flex justify-end gap-3">
                    <button phx-click="close_ai_write" class="glass-btn px-4 py-2 text-sm">取消</button>
                    <button
                      phx-click="use_ai_outline"
                      class="glass-btn glass-btn-primary px-6 py-2 text-sm"
                    >
                      使用此大纲
                    </button>
                  </div>
                </div>
            <% end %>
          </div>
        </div>
      <% end %>
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
      <%!-- Pipeline Progress Banner --%>
      <div
        :if={@active_tasks != [] || @pipeline_state == :running}
        class="glass-surface rounded-2xl p-4 border border-[var(--glass-accent-from)]/30 animate-pulse-slow"
      >
        <div class="flex items-center gap-3">
          <div class="relative">
            <svg
              class="w-5 h-5 text-[var(--glass-accent-from)] animate-spin"
              fill="none"
              viewBox="0 0 24 24"
            >
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
                d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
              />
            </svg>
          </div>
          <div class="flex-1">
            <p class="text-sm font-medium text-[var(--glass-text-primary)]">
              管线正在执行...
            </p>
            <p class="text-xs text-[var(--glass-text-tertiary)] mt-0.5">
              <%= for task <- @active_tasks do %>
                <span class="inline-flex items-center gap-1 mr-3">
                  <span class="w-1.5 h-1.5 rounded-full bg-[var(--glass-accent-from)] animate-pulse" />
                  {pipeline_step_label(task.type)}
                </span>
              <% end %>
            </p>
          </div>
          <div class="text-xs text-[var(--glass-text-tertiary)]">
            {length(@active_tasks)} 个任务执行中
          </div>
        </div>
      </div>
      <%!-- Story Input Card --%>
      <div class="glass-surface rounded-2xl p-6 shadow-sm">
        <textarea
          name="novel_text"
          class="glass-input w-full resize-none text-base leading-relaxed border-none bg-transparent focus:ring-0 p-0"
          style="min-height: 40vh"
          placeholder={dgettext("projects", "Paste your story or novel text here...")}
          phx-change="update_novel_text"
          phx-debounce="500"
        >{@novel_text}</textarea> <%!-- Bottom toolbar --%>
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
                <%= for {r, label} <- [{"16:9", "16:9 横屏·长视频"}, {"9:16", "9:16 竖屏·短剧"}, {"1:1", "1:1 方形"}, {"3:2", "3:2 风景"}, {"2:3", "2:3 海报"}, {"4:3", "4:3 传统"}, {"3:4", "3:4 直播"}, {"5:4", "5:4 广告"}, {"4:5", "4:5 信息流"}, {"21:9", "21:9 电影"}] do %>
                  <option value={r} selected={@aspect_ratio == r}>{label}</option>
                <% end %>
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
                <%= for {label, value} <- AstraAutoEx.AI.ArtStyles.style_options() do %>
                  <option value={value} selected={@art_style == value}>{label}</option>
                <% end %>
              </select>
            </div>
          </div>

          <div class="flex items-center gap-3">
            <.prompt_btn id="NP_AI_STORY_OUTLINE" />
            <button
              type="button"
              phx-click="open_ai_write"
              class="text-sm text-[var(--glass-accent-from)] hover:text-[var(--glass-accent-to)] transition-colors flex items-center gap-1"
              title="输入创意灵感，AI 生成完整故事大纲。确认后管线自动进行剧本拆解、角色/场景提取、分镜生成。"
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
            <form phx-submit="start_pipeline" class="inline relative group/start">
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
              <div class="absolute bottom-full left-1/2 -translate-x-1/2 mb-2 w-64 p-3 glass-surface rounded-xl shadow-xl text-xs text-[var(--glass-text-secondary)] opacity-0 group-hover/start:opacity-100 pointer-events-none transition-opacity z-10">
                <p class="font-medium text-[var(--glass-text-primary)] mb-1">管线将自动执行：</p>

                <ol class="list-decimal list-inside space-y-0.5 text-[10px]">
                  <li>AI 拆解故事 → 生成剧本</li>

                  <li>提取角色/场景/道具</li>

                  <li>生成分镜描述</li>

                  <li>按需生成图片/视频/配音</li>
                </ol>
              </div>
            </form>
          </div>
        </div>
      </div>
      <%!-- Auto-chain controls --%>
      <div class="glass-surface rounded-xl p-4 space-y-3">
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-2">
            <span class="text-sm font-medium text-[var(--glass-text-primary)]">自动链</span>
            <span class="group relative">
              <svg
                class="w-3.5 h-3.5 text-[var(--glass-text-tertiary)] cursor-help"
                fill="currentColor"
                viewBox="0 0 20 20"
              >
                <path
                  fill-rule="evenodd"
                  d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z"
                  clip-rule="evenodd"
                />
              </svg>
              <span class="invisible group-hover:visible absolute bottom-full left-1/2 -translate-x-1/2 mb-2 w-48 p-2 text-xs text-[var(--glass-text-primary)] bg-[var(--glass-bg-surface-modal)] rounded-lg shadow-lg border border-[var(--glass-stroke-base)] z-50">
                每步完成后自动执行下一步
              </span>
            </span>
          </div>

          <label class="relative inline-flex items-center cursor-pointer">
            <input
              type="checkbox"
              class="sr-only peer"
              checked={@auto_chain}
              phx-click="toggle_auto_chain"
            />
            <div class="w-9 h-5 bg-[var(--glass-bg-muted)] peer-checked:bg-[var(--glass-accent-from)] rounded-full transition-colors after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:after:translate-x-full" />
          </label>
        </div>

        <div class="flex items-center justify-between">
          <div class="flex items-center gap-2">
            <span class="text-sm font-medium text-[var(--glass-text-primary)]">全自动</span>
            <span class="group relative">
              <svg
                class="w-3.5 h-3.5 text-[var(--glass-text-tertiary)] cursor-help"
                fill="currentColor"
                viewBox="0 0 20 20"
              >
                <path
                  fill-rule="evenodd"
                  d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z"
                  clip-rule="evenodd"
                />
              </svg>
              <span class="invisible group-hover:visible absolute bottom-full left-1/2 -translate-x-1/2 mb-2 w-48 p-2 text-xs text-[var(--glass-text-primary)] bg-[var(--glass-bg-surface-modal)] rounded-lg shadow-lg border border-[var(--glass-stroke-base)] z-50">
                一键从故事直接到成片
              </span>
            </span>
          </div>

          <label class="relative inline-flex items-center cursor-pointer">
            <input
              type="checkbox"
              class="sr-only peer"
              checked={@full_auto_chain}
              phx-click="toggle_full_auto_chain"
            />
            <div class="w-9 h-5 bg-[var(--glass-bg-muted)] peer-checked:bg-[var(--glass-accent-from)] rounded-full transition-colors after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:after:translate-x-full" />
          </label>
        </div>
        <%!-- Pipeline control bar --%>
        <div
          :if={@pipeline_state in [:running, :paused]}
          class="flex items-center gap-2 pt-2 border-t border-[var(--glass-stroke-soft)]"
        >
          <button
            :if={@pipeline_state == :running}
            phx-click="pause_pipeline"
            class="glass-btn text-xs py-1 px-3 flex items-center gap-1"
          >
            ⏸ 暂停
          </button>
          <button
            :if={@pipeline_state == :paused}
            phx-click="resume_pipeline"
            class="glass-btn glass-btn-primary text-xs py-1 px-3 flex items-center gap-1"
          >
            ▶ 恢复
          </button>
          <button
            phx-click="stop_pipeline"
            class="glass-btn text-xs py-1 px-3 text-red-400 hover:text-red-300"
          >
            ⏹ 停止
          </button>
          <span class="text-xs text-[var(--glass-text-tertiary)] ml-auto">
            {if @pipeline_state == :paused, do: "已暂停", else: "运行中..."}
          </span>
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
            点击右上角素材库按钮上传资产文件或手动添加角色/场景。AI 将优先使用素材库中的资产。
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
          <.prompt_btn id="NP_AGENT_CLIP" /> <.prompt_btn id="NP_SCREENPLAY_CONVERSION" />
        </div>

        <div class="flex items-center gap-2">
          <button
            phx-click="extract_entities"
            class="glass-btn glass-btn-ghost text-xs py-1.5 px-3 flex items-center gap-1"
            disabled={@extracting_entities}
          >
            <svg
              class="w-3.5 h-3.5"
              fill="none"
              stroke="currentColor"
              stroke-width="1.5"
              viewBox="0 0 24 24"
            >
              <path d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
            </svg>
            {if @extracting_entities, do: "提取中...", else: "AI 提取实体"}
          </button>
          <button
            phx-click="run_story_to_script"
            class="glass-btn glass-btn-ghost text-xs py-1.5 px-3"
          >
            {dgettext("projects", "Generate Script")}
          </button>
        </div>
      </div>

      <div class="grid grid-cols-12 gap-5">
        <%!-- Left: Script clips --%>
        <div class="col-span-12 lg:col-span-8 space-y-3">
          <%= if @clips != [] do %>
            <%= for {clip, idx} <- Enum.with_index(@clips) do %>
              <div
                class="glass-surface rounded-xl overflow-hidden animate-slide-up"
                style={"animation-delay: #{idx * 80}ms"}
              >
                <div class="flex items-center gap-2 px-4 py-2.5 border-b border-[var(--glass-stroke-soft)] bg-[var(--glass-bg-muted)]">
                  <span class="w-6 h-6 rounded-full bg-gradient-to-br from-[var(--glass-accent-from)] to-[var(--glass-accent-to)] flex items-center justify-center text-[10px] font-bold text-white">
                    {idx + 1}
                  </span>
                  <span class="text-sm font-medium text-[var(--glass-text-primary)]">
                    {clip.title || "Clip #{idx + 1}"}
                  </span>
                </div>
                <div class="px-4 py-3 space-y-2">
                  <p
                    :if={clip.summary && clip.summary != ""}
                    class="text-xs text-[var(--glass-text-secondary)] leading-relaxed"
                  >
                    {clip.summary}
                  </p>
                  <div
                    :if={clip.characters && clip.characters != ""}
                    class="flex items-center gap-1.5"
                  >
                    <span class="text-[10px] text-[var(--glass-text-tertiary)]">角色:</span>
                    <span class="text-[10px] text-[var(--glass-accent-from)]">{clip.characters}</span>
                  </div>
                  <div :if={clip.location && clip.location != ""} class="flex items-center gap-1.5">
                    <span class="text-[10px] text-[var(--glass-text-tertiary)]">场景:</span>
                    <span class="text-[10px] text-green-400">{clip.location}</span>
                  </div>
                </div>
              </div>
            <% end %>
          <% else %>
            <div class="glass-surface rounded-xl p-5 border-l-2 border-[var(--glass-accent-from)]">
              <p class="text-sm text-[var(--glass-text-tertiary)]">
                {dgettext("projects", "Run 'Generate Script' to create clips from story text.")}
              </p>
            </div>
          <% end %>
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
      <%!-- Entity operation buttons (shown after extraction) --%>
      <div :if={@extracted_entities} class="glass-surface rounded-xl p-4 space-y-3">
        <h3 class="text-xs font-semibold text-[var(--glass-text-primary)] flex items-center gap-2">
          <svg
            class="w-4 h-4 text-amber-500"
            fill="none"
            stroke="currentColor"
            stroke-width="1.5"
            viewBox="0 0 24 24"
          >
            <path d="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09z" />
          </svg>
          {dgettext("projects", "Entity Actions")}
          <span class="text-[10px] text-[var(--glass-text-tertiary)]">
            ({length(@extracted_entities.characters || [])} {dgettext("projects", "chars")} + {length(
              @extracted_entities.locations || []
            )} {dgettext("projects", "scenes")} + {length(@extracted_entities.props || [])} {dgettext(
              "projects",
              "props"
            )})
          </span>
        </h3>

        <div class="grid grid-cols-3 gap-2">
          <button
            phx-click="generate_all_entity_images"
            class="glass-btn glass-btn-primary text-xs py-2 px-2 flex items-center gap-1 justify-center"
          >
            <svg
              class="w-3 h-3"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              viewBox="0 0 24 24"
            >
              <path d="M2.25 15.75l5.159-5.159a2.25 2.25 0 013.182 0l5.159 5.159" />
            </svg>
            {dgettext("projects", "Generate All")}
          </button>
          <button
            phx-click="retry_all_entity_images"
            class="glass-btn glass-btn-ghost text-xs py-2 px-2 flex items-center gap-1 justify-center"
          >
            <svg
              class="w-3 h-3"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              viewBox="0 0 24 24"
            >
              <path d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0l3.181 3.183a8.25 8.25 0 0013.803-3.7M4.031 9.865a8.25 8.25 0 0113.803-3.7l3.181 3.182" />
            </svg>
            {dgettext("projects", "Retry All")}
          </button>
          <button
            phx-click="delete_all_entities"
            class="glass-btn glass-btn-ghost text-xs py-2 px-2 flex items-center gap-1 justify-center text-red-400 hover:text-red-300"
          >
            <svg
              class="w-3 h-3"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              viewBox="0 0 24 24"
            >
              <path d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79" />
            </svg>
            {dgettext("projects", "Clear All")}
          </button>
        </div>
        <%!-- Per-entity actions (inline) --%>
        <div class="space-y-1 max-h-40 overflow-y-auto">
          <%= for char <- (@extracted_entities.characters || []) do %>
            <div class="flex items-center gap-2 py-1 px-2 rounded hover:bg-[var(--glass-bg-muted)] transition-colors">
              <span class="inline-flex items-center px-1.5 py-0.5 rounded text-[9px] font-medium bg-blue-500/15 text-blue-400">
                {dgettext("projects", "Char")}
              </span>
              <span class="text-xs text-[var(--glass-text-primary)] flex-1 truncate">
                {char["name"]}
              </span>
              <button
                phx-click="generate_entity_image"
                phx-value-type="character"
                phx-value-name={char["name"]}
                class="text-[10px] text-[var(--glass-accent-from)] hover:underline"
              >
                {dgettext("projects", "Generate")}
              </button>
              <button
                phx-click="edit_entity"
                phx-value-type="character"
                phx-value-name={char["name"]}
                class="text-[10px] text-[var(--glass-text-tertiary)] hover:text-[var(--glass-text-primary)]"
              >
                {dgettext("projects", "Edit")}
              </button>
            </div>
          <% end %>

          <%= for loc <- (@extracted_entities.locations || []) do %>
            <div class="flex items-center gap-2 py-1 px-2 rounded hover:bg-[var(--glass-bg-muted)] transition-colors">
              <span class="inline-flex items-center px-1.5 py-0.5 rounded text-[9px] font-medium bg-green-500/15 text-green-400">
                {dgettext("projects", "Scene")}
              </span>
              <span class="text-xs text-[var(--glass-text-primary)] flex-1 truncate">
                {loc["name"]}
              </span>
              <button
                phx-click="generate_entity_image"
                phx-value-type="location"
                phx-value-name={loc["name"]}
                class="text-[10px] text-[var(--glass-accent-from)] hover:underline"
              >
                {dgettext("projects", "Generate")}
              </button>
            </div>
          <% end %>
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
          <.prompt_btn id="NP_AGENT_STORYBOARD_PLAN" /> <.prompt_btn id="NP_SINGLE_PANEL_IMAGE" />
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
      <%!-- Reference image upload for image-to-image --%>
      <details class="glass-surface rounded-xl">
        <summary class="flex items-center gap-3 px-5 py-3 cursor-pointer select-none hover:bg-[var(--glass-bg-muted)] rounded-xl transition-colors">
          <svg
            class="w-5 h-5 text-[var(--glass-accent-from)]"
            fill="none"
            stroke="currentColor"
            stroke-width="1.5"
            viewBox="0 0 24 24"
          >
            <path d="M2.25 15.75l5.159-5.159a2.25 2.25 0 013.182 0l5.159 5.159m-1.5-1.5l1.409-1.41a2.25 2.25 0 013.182 0l2.909 2.91m-18 3.75h16.5a1.5 1.5 0 001.5-1.5V6a1.5 1.5 0 00-1.5-1.5H3.75A1.5 1.5 0 002.25 6v12a1.5 1.5 0 001.5 1.5z" />
          </svg>
          <div>
            <span class="text-sm font-semibold text-[var(--glass-text-primary)]">
              {dgettext("projects", "Reference Images (Image-to-Image)")}
            </span>
            <span class="text-xs text-[var(--glass-text-tertiary)] ml-2">
              {length(@ref_image_urls)}/5
            </span>
          </div>
        </summary>

        <div class="px-5 pb-4 pt-2 border-t border-[var(--glass-stroke-soft)] space-y-3">
          <p class="text-xs text-[var(--glass-text-tertiary)]">
            {dgettext(
              "projects",
              "Upload reference images (max 5) to guide AI image generation style and composition."
            )}
          </p>
          <%!-- Uploaded images grid --%>
          <div class="flex flex-wrap gap-2">
            <%= for {url, idx} <- Enum.with_index(@ref_image_urls) do %>
              <div class="relative w-20 h-20 rounded-lg overflow-hidden group">
                <img src={url} class="w-full h-full object-cover" />
                <button
                  phx-click="remove_ref_image"
                  phx-value-index={idx}
                  class="absolute top-0.5 right-0.5 w-5 h-5 rounded-full bg-red-500/80 text-white text-xs flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity"
                >
                  &times;
                </button>
              </div>
            <% end %>
            <%!-- Upload button --%>
            <div
              :if={length(@ref_image_urls) < 5}
              class="w-20 h-20 rounded-lg border-2 border-dashed border-[var(--glass-stroke-base)] flex items-center justify-center cursor-pointer hover:border-[var(--glass-accent-from)] hover:bg-[var(--glass-accent-from)]/5 transition-all"
            >
              <label for={@uploads.ref_images.ref} class="cursor-pointer flex flex-col items-center">
                <svg
                  class="w-6 h-6 text-[var(--glass-text-tertiary)]"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="1.5"
                  viewBox="0 0 24 24"
                >
                  <path d="M12 4.5v15m7.5-7.5h-15" />
                </svg>
                <span class="text-[9px] text-[var(--glass-text-tertiary)]">
                  {dgettext("projects", "Upload")}
                </span>
              </label>
              <.live_file_input upload={@uploads.ref_images} class="hidden" />
            </div>
          </div>
          <%!-- Upload entries in progress --%>
          <%= for entry <- @uploads.ref_images.entries do %>
            <div class="flex items-center gap-2 text-xs text-[var(--glass-text-secondary)]">
              <span>{entry.client_name}</span>
              <div class="flex-1 h-1 bg-[var(--glass-bg-muted)] rounded-full">
                <div
                  class="h-full bg-gradient-to-r from-[var(--glass-accent-from)] to-[var(--glass-accent-to)] rounded-full"
                  style={"width: #{entry.progress}%"}
                />
              </div>

              <button
                type="button"
                phx-click="cancel_ref_upload"
                phx-value-ref={entry.ref}
                class="text-red-400"
              >
                &times;
              </button>
            </div>
          <% end %>
          <%!-- Reference prompt --%>
          <div>
            <label class="text-xs text-[var(--glass-text-tertiary)] mb-1 block">
              {dgettext("projects", "Style prompt (optional)")}
            </label>
            <input
              type="text"
              name="ref_image_prompt"
              value={@ref_image_prompt}
              phx-change="update_ref_prompt"
              phx-debounce="500"
              class="glass-input w-full text-xs py-1.5"
              placeholder={
                dgettext("projects", "e.g., match the color palette and composition style")
              }
            />
          </div>
        </div>
      </details>

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
                    <%!-- Action buttons on hover --%>
                    <div class="absolute top-1.5 right-1.5 opacity-0 group-hover:opacity-100 transition-opacity duration-200 flex gap-1">
                      <button
                        phx-click="generate_panel_image"
                        phx-value-panel-id={panel.id}
                        class="glass-chip text-[10px] bg-[var(--glass-accent-from)]/80 text-white backdrop-blur-sm hover:bg-[var(--glass-accent-from)] px-1.5 py-0.5"
                        title={if panel.image_url && panel.image_url != "", do: "重新生成", else: "生成图片"}
                      >
                        <svg
                          class="w-3 h-3 inline"
                          fill="none"
                          stroke="currentColor"
                          stroke-width="2"
                          viewBox="0 0 24 24"
                        >
                          <%= if panel.image_url && panel.image_url != "" do %>
                            <path d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0l3.181 3.183a8.25 8.25 0 0013.803-3.7M4.031 9.865a8.25 8.25 0 0113.803-3.7l3.181 3.182" />
                          <% else %>
                            <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z" />
                          <% end %>
                        </svg>
                      </button>

                      <span class="glass-chip text-[10px] bg-black/60 text-[var(--glass-text-primary)] backdrop-blur-sm">
                        {dgettext("projects", "Edit")}
                      </span>
                    </div>
                  </div>

                  <div class="p-2.5">
                    <p class="text-xs text-[var(--glass-text-secondary)] line-clamp-2 leading-relaxed">
                      {panel.description}
                    </p>

                    <div class="flex flex-wrap items-center gap-1 mt-1.5">
                      <%!-- Shot type chip --%>
                      <span class="inline-flex items-center px-1.5 py-0.5 rounded text-[10px] font-medium bg-[var(--glass-accent-from)]/10 text-[var(--glass-accent-from)]">
                        {panel.shot_type || "MS"}
                      </span>
                      <%!-- Character tags (blue) --%>
                      <%= for char <- parse_panel_characters(panel) do %>
                        <span class="inline-flex items-center px-1.5 py-0.5 rounded text-[10px] font-medium bg-blue-500/10 text-blue-400">
                          {char}
                        </span>
                      <% end %>
                      <%!-- Location tag (green) --%>
                      <span
                        :if={panel_location(panel)}
                        class="inline-flex items-center px-1.5 py-0.5 rounded text-[10px] font-medium bg-green-500/10 text-green-400"
                      >
                        {panel_location(panel)}
                      </span>
                      <%!-- Prop tags (orange) --%>
                      <%= for prop <- parse_panel_props(panel) do %>
                        <span class="inline-flex items-center px-1.5 py-0.5 rounded text-[10px] font-medium bg-orange-500/10 text-orange-400">
                          {prop}
                        </span>
                      <% end %>

                      <span
                        :if={panel.video_url && panel.video_url != ""}
                        class="inline-flex items-center gap-0.5 px-1.5 py-0.5 rounded text-[10px] font-medium bg-blue-500/10 text-blue-400"
                      >
                        <svg class="w-2.5 h-2.5" fill="currentColor" viewBox="0 0 24 24">
                          <path d="M5.25 5.653c0-.856.917-1.398 1.667-.986l11.54 6.347a1.125 1.125 0 010 1.972l-11.54 6.347a1.125 1.125 0 01-1.667-.986V5.653z" />
                        </svg>
                        视频
                      </span>
                      <span
                        :if={panel.audio_url && panel.audio_url != ""}
                        class="inline-flex items-center gap-0.5 px-1.5 py-0.5 rounded text-[10px] font-medium bg-purple-500/10 text-purple-400"
                      >
                        <svg
                          class="w-2.5 h-2.5"
                          fill="none"
                          stroke="currentColor"
                          stroke-width="2"
                          viewBox="0 0 24 24"
                        >
                          <path d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4" />
                        </svg>
                        配音
                      </span>
                      <span
                        :if={panel.lip_sync_video_url && panel.lip_sync_video_url != ""}
                        class="inline-flex items-center gap-0.5 px-1.5 py-0.5 rounded text-[10px] font-medium bg-amber-500/10 text-amber-400"
                      >
                        口型
                      </span>
                    </div>
                    <%!-- Mini pipeline status bar --%>
                    <div class="flex gap-0.5 mt-1.5">
                      <div
                        class={[
                          "h-0.5 flex-1 rounded-full",
                          if(panel.image_url && panel.image_url != "",
                            do: "bg-green-500",
                            else: "bg-[var(--glass-bg-muted)]"
                          )
                        ]}
                        title="图片"
                      />
                      <div
                        class={[
                          "h-0.5 flex-1 rounded-full",
                          if(panel.video_url && panel.video_url != "",
                            do: "bg-blue-500",
                            else: "bg-[var(--glass-bg-muted)]"
                          )
                        ]}
                        title="视频"
                      />
                      <div
                        class={[
                          "h-0.5 flex-1 rounded-full",
                          if(panel.audio_url && panel.audio_url != "",
                            do: "bg-purple-500",
                            else: "bg-[var(--glass-bg-muted)]"
                          )
                        ]}
                        title="配音"
                      />
                    </div>
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
          <%!-- Skip voice toggle --%>
          <label class="flex items-center gap-1.5 text-xs text-[var(--glass-text-secondary)] cursor-pointer group">
            <div class="relative">
              <input
                type="checkbox"
                class="sr-only peer"
                phx-click="toggle_skip_voice"
                checked={@skip_voice}
              />
              <div class="w-8 h-4 bg-[var(--glass-bg-muted)] rounded-full peer-checked:bg-amber-500/60 transition-colors">
              </div>

              <div class="absolute left-0.5 top-0.5 w-3 h-3 bg-white rounded-full transition-transform peer-checked:translate-x-4">
              </div>
            </div>

            <span class="group-hover:text-[var(--glass-text-primary)] transition-colors">
              {dgettext("projects", "Skip voice (dub later)")}
            </span>
          </label>
          <.prompt_btn id="NP_VOICE_ANALYSIS" />
          <button
            phx-click="generate_all_voices"
            class={"glass-btn glass-btn-ghost text-xs py-1.5 px-3 flex items-center gap-1.5 #{if @skip_voice, do: "opacity-40 pointer-events-none"}"}
            disabled={@skip_voice}
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
          <button
            phx-click="generate_all_lip_sync"
            class={"glass-btn text-xs py-1.5 px-3 flex items-center gap-1.5 border border-purple-500/30 text-purple-400 hover:bg-purple-500/10 #{if @video_count == 0 or @voice_done == 0, do: "opacity-40 pointer-events-none"}"}
            disabled={@video_count == 0 or @voice_done == 0}
            title={dgettext("projects", "Requires video + voice for each panel")}
          >
            <svg
              class="w-3.5 h-3.5"
              fill="none"
              stroke="currentColor"
              stroke-width="1.5"
              viewBox="0 0 24 24"
            >
              <path d="M15.182 15.182a4.5 4.5 0 01-6.364 0M21 12a9 9 0 11-18 0 9 9 0 0118 0zM9.75 9.75c0 .414-.168.75-.375.75S9 10.164 9 9.75 9.168 9 9.375 9s.375.336.375.75zm-.375 0h.008v.015h-.008V9.75zm5.625 0c0 .414-.168.75-.375.75s-.375-.336-.375-.75.168-.75.375-.75.375.336.375.75zm-.375 0h.008v.015h-.008V9.75z" />
            </svg>
            {dgettext("projects", "Lip Sync")}
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
              <p class="text-xs text-[var(--glass-text-tertiary)] flex-1 truncate">{vl.content}</p>

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
        <%!-- First/Last Frame Transitions --%>
        <%= if length(@all_panels) > 1 do %>
          <div class="mt-6">
            <h3 class="text-sm font-semibold text-[var(--glass-text-primary)] mb-3 flex items-center gap-2">
              首尾帧过渡 <span class="glass-chip text-[10px]">{length(@all_panels) - 1} 对</span>
            </h3>

            <div class="space-y-3">
              <%= for {panel, idx} <- Enum.with_index(@all_panels), idx < length(@all_panels) - 1 do %>
                <.live_component
                  module={AstraAutoExWeb.WorkspaceLive.FirstLastFrame}
                  id={"fl-#{panel.id}"}
                  current_panel={panel}
                  next_panel={Enum.at(@all_panels, idx + 1)}
                  panel_index={idx}
                />
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
    <div class="max-w-6xl mx-auto space-y-6 animate-slide-up">
      <%!-- Title centered --%>
      <div class="text-center py-4">
        <h1 class="text-2xl font-bold text-[var(--glass-text-primary)]">
          {dgettext("projects", "AI Edit")}
        </h1>
      </div>

      <div class="grid grid-cols-12 gap-4">
        <%!-- Left: Panel checklist + settings --%>
        <div class="col-span-5 space-y-3">
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
                  <span class="text-xs text-[var(--glass-text-tertiary)] w-6 text-center">
                    {idx + 1}
                  </span>
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
          <div class="glass-surface rounded-xl p-4 space-y-3">
            <h3 class="text-xs font-semibold text-[var(--glass-text-primary)]">
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
            <svg
              class="w-5 h-5"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M5.25 5.653c0-.856.917-1.398 1.667-.986l11.54 6.347a1.125 1.125 0 010 1.972l-11.54 6.347a1.125 1.125 0 01-1.667-.986V5.653z"
              />
            </svg>
            {dgettext("projects", "Compose Video")} ({@selected_count} {dgettext(
              "projects",
              "panels"
            )})
          </button>
        </div>
        <%!-- Right: Preview + Export --%>
        <div class="col-span-7 space-y-3">
          <%!-- Video preview (enlarged) --%>
          <div class="glass-surface rounded-xl overflow-hidden bg-black/20 sticky top-20">
            <div class="aspect-video flex items-center justify-center relative">
              <%= if @compose_task && @compose_task.status == "completed" do %>
                <video
                  id="compose-preview"
                  class="w-full h-full object-contain"
                  controls
                  phx-hook="VideoPlayer"
                />
              <% else %>
                <div class="flex flex-col items-center gap-3">
                  <svg
                    class="w-16 h-16 text-[var(--glass-text-tertiary)] opacity-20"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="0.5"
                    viewBox="0 0 24 24"
                  >
                    <path d="M5.25 5.653c0-.856.917-1.398 1.667-.986l11.54 6.347a1.125 1.125 0 010 1.972l-11.54 6.347a1.125 1.125 0 01-1.667-.986V5.653z" />
                  </svg>
                  <p class="text-sm text-[var(--glass-text-tertiary)]">
                    {dgettext("projects", "Composed video will appear here after processing.")}
                  </p>
                </div>
              <% end %>
            </div>
          </div>
          <%!-- Export actions --%>
          <div class="glass-surface rounded-xl p-4 space-y-3">
            <h3 class="text-xs font-semibold text-[var(--glass-text-primary)] flex items-center gap-2">
              <svg
                class="w-4 h-4"
                fill="none"
                stroke="currentColor"
                stroke-width="1.5"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5M16.5 12L12 16.5m0 0L7.5 12m4.5 4.5V3"
                />
              </svg>
              {dgettext("projects", "Export")}
            </h3>

            <div class="grid grid-cols-2 gap-2">
              <%!-- Download video --%>
              <button class="glass-btn glass-btn-ghost text-xs py-2.5 px-3 flex items-center gap-2 justify-center">
                <svg
                  class="w-4 h-4"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="1.5"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5M16.5 12L12 16.5m0 0L7.5 12m4.5 4.5V3"
                  />
                </svg>
                {dgettext("projects", "Download MP4")}
              </button>
              <%!-- Export to CapCut/JianYing --%>
              <button
                phx-click="export_capcut"
                class="glass-btn glass-btn-primary text-xs py-2.5 px-3 flex items-center gap-2 justify-center"
              >
                <svg
                  class="w-4 h-4"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="1.5"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M13.5 6H5.25A2.25 2.25 0 003 8.25v10.5A2.25 2.25 0 005.25 21h10.5A2.25 2.25 0 0018 18.75V10.5m-10.5 6L21 3m0 0h-5.25M21 3v5.25"
                  />
                </svg>
                {dgettext("projects", "Export to CapCut")}
              </button>
            </div>
          </div>
          <%!-- Promo copy generator --%>
          <div class="glass-surface rounded-xl p-4 space-y-3">
            <h3 class="text-xs font-semibold text-[var(--glass-text-primary)] flex items-center gap-2">
              <svg
                class="w-4 h-4"
                fill="none"
                stroke="currentColor"
                stroke-width="1.5"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M7.5 8.25h9m-9 3H12m-9.75 1.51c0 1.6 1.123 2.994 2.707 3.227 1.129.166 2.27.293 3.423.379.35.026.67.21.865.501L12 21l2.755-4.133a1.14 1.14 0 01.865-.501 48.172 48.172 0 003.423-.379c1.584-.233 2.707-1.626 2.707-3.228V6.741c0-1.602-1.123-2.995-2.707-3.228A48.394 48.394 0 0012 3c-2.392 0-4.744.175-7.043.513C3.373 3.746 2.25 5.14 2.25 6.741v6.018z"
                />
              </svg>
              {dgettext("projects", "Promo Copy")}
            </h3>
            <textarea
              id="promo-copy"
              class="glass-input w-full text-xs h-20 resize-none"
              placeholder={
                dgettext("projects", "Click generate to create promotional copy for your video...")
              }
              phx-change="update_promo_copy"
              name="promo_copy"
            ><%= @promo_copy %></textarea>
            <div class="flex items-center gap-2">
              <button
                phx-click="generate_promo_copy"
                class="glass-btn glass-btn-ghost text-xs py-1.5 px-3 flex items-center gap-1.5"
              >
                <svg
                  class="w-3.5 h-3.5"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="1.5"
                  viewBox="0 0 24 24"
                >
                  <path d="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09z" />
                </svg>
                {dgettext("projects", "AI Generate")}
              </button>
              <button class="glass-btn glass-btn-ghost text-xs py-1.5 px-3">
                {dgettext("projects", "Copy to clipboard")}
              </button>
            </div>
          </div>
          <%!-- Open location selector --%>
          <div class="glass-surface rounded-xl p-4">
            <h3 class="text-xs font-semibold text-[var(--glass-text-primary)] mb-2 flex items-center gap-2">
              <svg
                class="w-4 h-4"
                fill="none"
                stroke="currentColor"
                stroke-width="1.5"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M15 10.5a3 3 0 11-6 0 3 3 0 016 0z"
                />
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="M19.5 10.5c0 7.142-7.5 11.25-7.5 11.25S4.5 17.642 4.5 10.5a7.5 7.5 0 1115 0z"
                />
              </svg>
              {dgettext("projects", "Publish Location")}
            </h3>

            <div class="flex flex-wrap gap-2">
              <%= for platform <- ["Douyin", "Kuaishou", "Bilibili", "YouTube", "TikTok", "RedNote"] do %>
                <span class="inline-flex items-center px-2.5 py-1 rounded-lg text-xs bg-[var(--glass-bg-muted)] text-[var(--glass-text-secondary)] hover:text-[var(--glass-text-primary)] hover:bg-[var(--glass-accent-from)]/10 cursor-pointer transition-colors">
                  {platform}
                </span>
              <% end %>
            </div>
          </div>
        </div>
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
    novel_text = if episode, do: episode.novel_text || "", else: ""

    {:noreply,
     socket
     |> assign(:current_episode, episode)
     |> assign(:storyboards, storyboards)
     |> assign(:novel_text, novel_text)}
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

  def handle_event("add_episode", _, socket) do
    project = socket.assigns.project
    user_id = socket.assigns.current_scope.user.id
    episodes = socket.assigns.episodes
    next_num = length(episodes) + 1

    case Production.create_episode(%{
           project_id: project.id,
           user_id: user_id,
           episode_number: next_num,
           title: "#{project.name} 第#{next_num}集",
           status: "draft"
         }) do
      {:ok, ep} ->
        updated_episodes = episodes ++ [ep]

        {:noreply,
         socket
         |> assign(:episodes, updated_episodes)
         |> assign(:current_episode, ep)
         |> assign(:storyboards, load_storyboards(ep))
         |> assign(:voice_lines, load_voice_lines(ep))
         |> assign(:novel_text, "")
         |> put_flash(:info, dgettext("projects", "Episode %{num} created", num: next_num))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, dgettext("default", "Error"))}
    end
  end

  def handle_event("delete_episode", _, socket) do
    episode = socket.assigns.current_episode
    episodes = socket.assigns.episodes

    if episode && length(episodes) > 1 do
      {:ok, _} = Production.delete_episode(episode)
      remaining = Enum.reject(episodes, &(&1.id == episode.id))
      next_ep = List.first(remaining)

      {:noreply,
       socket
       |> assign(:episodes, remaining)
       |> assign(:current_episode, next_ep)
       |> assign(:storyboards, load_storyboards(next_ep))
       |> assign(:clips, load_clips(next_ep))
       |> assign(:voice_lines, load_voice_lines(next_ep))
       |> assign(:novel_text, (next_ep && next_ep.novel_text) || "")
       |> put_flash(:info, dgettext("projects", "Episode deleted"))}
    else
      {:noreply,
       put_flash(socket, :error, dgettext("projects", "Cannot delete the last episode"))}
    end
  end

  def handle_event("toggle_assistant", _, socket) do
    {:noreply, assign(socket, :show_assistant, !socket.assigns.show_assistant)}
  end

  def handle_event("toggle_auto_chain", _, socket) do
    new_val = !socket.assigns.auto_chain
    save_novel_setting(socket.assigns.project.id, :auto_chain_enabled, new_val)
    {:noreply, assign(socket, :auto_chain, new_val)}
  end

  def handle_event("toggle_skip_voice", _, socket) do
    {:noreply, assign(socket, :skip_voice, !socket.assigns.skip_voice)}
  end

  def handle_event("toggle_full_auto_chain", _, socket) do
    new_val = !socket.assigns.full_auto_chain
    save_novel_setting(socket.assigns.project.id, :full_auto_chain_enabled, new_val)

    socket =
      socket
      |> assign(:full_auto_chain, new_val)
      |> then(fn s -> if new_val, do: assign(s, :auto_chain, true), else: s end)

    if new_val do
      save_novel_setting(socket.assigns.project.id, :auto_chain_enabled, true)
    end

    {:noreply, socket}
  end

  def handle_event("pause_pipeline", _, socket) do
    {:noreply, assign(socket, :pipeline_state, :paused)}
  end

  def handle_event("resume_pipeline", _, socket) do
    {:noreply, assign(socket, :pipeline_state, :running)}
  end

  def handle_event("stop_pipeline", _, socket) do
    {:noreply,
     socket
     |> assign(:pipeline_state, :idle)
     |> put_flash(:info, "管线已停止，已完成的结果已保留。")}
  end

  def handle_event("open_ai_write", _, socket) do
    {:noreply,
     socket
     |> assign(:show_ai_write, true)
     |> assign(:ai_write_prompt, "")
     |> assign(:ai_write_phase, :input)}
  end

  def handle_event("close_ai_write", _, socket) do
    {:noreply, assign(socket, :show_ai_write, false)}
  end

  def handle_event("update_ai_write_prompt", %{"prompt" => prompt}, socket) do
    {:noreply, assign(socket, :ai_write_prompt, prompt)}
  end

  def handle_event("generate_ai_write", _, socket) do
    prompt = socket.assigns[:ai_write_prompt] || ""

    if String.trim(prompt) == "" do
      {:noreply, put_flash(socket, :error, "请输入创意内容")}
    else
      # Set loading phase
      socket = assign(socket, :ai_write_phase, :loading)

      # Dispatch async AI outline generation
      user_id = socket.assigns.current_scope.user.id
      lv = self()

      Task.start(fn ->
        case AstraAutoEx.Workers.Handlers.Helpers.chat(
               user_id,
               "default",
               %{
                 "messages" => [
                   %{
                     "role" => "system",
                     "content" => "你是一个专业短剧编剧。根据用户的创意灵感，生成一个完整的多集短剧大纲（60-80集），包含核心冲突、人物关系和每集概要。"
                   },
                   %{"role" => "user", "content" => prompt}
                 ],
                 "max_tokens" => 4000
               }
             ) do
          {:ok, result} -> send(lv, {:ai_write_result, result})
          {:error, reason} -> send(lv, {:ai_write_error, reason})
        end
      end)

      {:noreply, socket}
    end
  end

  def handle_event("use_ai_outline", _, socket) do
    outline = socket.assigns[:ai_write_outline] || ""

    # Persist to episode DB
    if episode = socket.assigns.current_episode do
      Production.update_episode(episode, %{novel_text: outline})
    end

    # Auto-trigger pipeline after filling outline
    socket =
      socket
      |> assign(:novel_text, outline)
      |> assign(:show_ai_write, false)

    # Directly start pipeline with the outline
    handle_event("start_pipeline", %{"novel_text" => outline}, socket)
  end

  def handle_event("extract_entities", _, socket) do
    novel_text = socket.assigns.novel_text || ""

    if String.trim(novel_text) == "" do
      {:noreply, put_flash(socket, :error, "请先输入故事文本")}
    else
      user_id = socket.assigns.current_scope.user.id
      parent = self()

      Task.start(fn ->
        result = AstraAutoEx.AI.EntityExtractor.extract_all(user_id, novel_text)
        send(parent, {:entities_extracted, result})
      end)

      {:noreply, assign(socket, :extracting_entities, true)}
    end
  end

  def handle_event("generate_all_entity_images", _, socket) do
    project = socket.assigns.project
    user_id = socket.assigns.current_scope.user.id

    # Generate images for all characters and locations
    Enum.each(socket.assigns.characters, fn char ->
      Tasks.create_task(%{
        user_id: user_id,
        project_id: project.id,
        type: "image_character",
        target_type: "character",
        target_id: char.id,
        payload: %{"character_id" => char.id}
      })
    end)

    Enum.each(socket.assigns.locations, fn loc ->
      Tasks.create_task(%{
        user_id: user_id,
        project_id: project.id,
        type: "image_location",
        target_type: "location",
        target_id: loc.id,
        payload: %{"location_id" => loc.id}
      })
    end)

    total = length(socket.assigns.characters) + length(socket.assigns.locations)
    {:noreply, put_flash(socket, :info, "#{total} entity image tasks queued.")}
  end

  def handle_event("retry_all_entity_images", _, socket) do
    # Same as generate_all but only for entities without images
    handle_event("generate_all_entity_images", nil, socket)
  end

  def handle_event("delete_all_entities", _, socket) do
    {:noreply,
     socket
     |> assign(:extracted_entities, nil)
     |> put_flash(:info, "Extracted entities cleared.")}
  end

  def handle_event("generate_entity_image", %{"type" => type, "name" => name}, socket) do
    project = socket.assigns.project
    user_id = socket.assigns.current_scope.user.id

    case type do
      "character" ->
        char = Enum.find(socket.assigns.characters, &(&1.name == name))

        if char do
          Tasks.create_task(%{
            user_id: user_id,
            project_id: project.id,
            type: "image_character",
            target_type: "character",
            target_id: char.id,
            payload: %{"character_id" => char.id}
          })

          {:noreply, put_flash(socket, :info, "Generating image for #{name}...")}
        else
          {:noreply, put_flash(socket, :error, "Character not found: #{name}")}
        end

      "location" ->
        loc = Enum.find(socket.assigns.locations, &(&1.name == name))

        if loc do
          Tasks.create_task(%{
            user_id: user_id,
            project_id: project.id,
            type: "image_location",
            target_type: "location",
            target_id: loc.id,
            payload: %{"location_id" => loc.id}
          })

          {:noreply, put_flash(socket, :info, "Generating image for #{name}...")}
        else
          {:noreply, put_flash(socket, :error, "Location not found: #{name}")}
        end

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("edit_entity", %{"type" => _type, "name" => _name}, socket) do
    {:noreply, put_flash(socket, :info, "Entity editing coming soon.")}
  end

  def handle_event("select_candidate", %{"panel-id" => panel_id, "index" => idx_str}, socket) do
    idx = String.to_integer(idx_str)
    panel = Production.get_panel!(panel_id)
    candidates = panel.candidate_images || %{}
    urls = candidates["urls"] || []

    if idx >= 0 and idx < length(urls) do
      selected_url = Enum.at(urls, idx)

      Production.update_panel(panel, %{
        image_url: selected_url,
        candidate_images: Map.put(candidates, "selected", idx)
      })

      storyboards = load_storyboards(socket.assigns.current_episode)
      {:noreply, assign(socket, :storyboards, storyboards)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("delete_candidate", %{"panel-id" => panel_id, "index" => idx_str}, socket) do
    idx = String.to_integer(idx_str)
    panel = Production.get_panel!(panel_id)
    candidates = panel.candidate_images || %{}
    urls = candidates["urls"] || []

    new_urls = List.delete_at(urls, idx)

    Production.update_panel(panel, %{
      candidate_images: %{candidates | "urls" => new_urls, "selected" => 0}
    })

    storyboards = load_storyboards(socket.assigns.current_episode)
    {:noreply, assign(socket, :storyboards, storyboards)}
  end

  def handle_event("open_wizard", _, socket) do
    {:noreply, assign(socket, :show_wizard, true)}
  end

  def handle_event("start_pipeline", %{"novel_text" => text}, socket) do
    project = socket.assigns.project
    user_id = socket.assigns.current_scope.user.id

    # Create episode if none exists
    episode = socket.assigns.current_episode || create_default_episode(project, user_id)

    # Persist novel_text to episode DB
    Production.update_episode(episode, %{novel_text: text})

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
     |> assign(:pipeline_state, :running)
     |> assign(:current_episode, %{episode | novel_text: text})
     |> put_flash(:info, dgettext("projects", "Pipeline started. Processing your story..."))}
  end

  def handle_event("run_story_to_script", _, socket) do
    episode = socket.assigns.current_episode
    novel_text = socket.assigns.novel_text

    if episode && novel_text && String.trim(novel_text) != "" do
      Tasks.create_task(%{
        user_id: socket.assigns.current_scope.user.id,
        project_id: socket.assigns.project.id,
        episode_id: episode.id,
        type: "story_to_script_run",
        target_type: "episode",
        target_id: episode.id,
        payload: %{
          "novel_text" => novel_text,
          "episode_id" => episode.id,
          "auto_continue" => socket.assigns.auto_chain
        }
      })

      {:noreply,
       socket
       |> assign(:pipeline_state, :running)
       |> put_flash(:info, "剧本生成任务已排队，AI 正在分析故事...")}
    else
      {:noreply, put_flash(socket, :error, "请先在故事阶段输入故事文本")}
    end
  end

  def handle_event("generate_all_images", _, socket) do
    dispatch_batch_task(socket, "image_panel", "panel")
  end

  def handle_event("generate_all_voices", _, socket) do
    user_id = socket.assigns.current_scope.user.id
    project = socket.assigns.project
    episode = socket.assigns.current_episode

    if episode do
      voice_lines = socket.assigns.voice_lines || []

      # Only generate for voice lines without audio
      to_generate =
        Enum.filter(voice_lines, fn vl -> is_nil(vl.audio_url) or vl.audio_url == "" end)

      Enum.each(to_generate, fn vl ->
        Tasks.create_task(%{
          user_id: user_id,
          project_id: project.id,
          episode_id: episode.id,
          type: "voice_line",
          target_type: "voice_line",
          target_id: vl.id,
          payload: %{"voice_line_id" => vl.id}
        })
      end)

      {:noreply, put_flash(socket, :info, "#{length(to_generate)} 条配音任务已排队")}
    else
      {:noreply, put_flash(socket, :error, dgettext("projects", "Select an episode first."))}
    end
  end

  def handle_event("generate_all_videos", _, socket) do
    user_id = socket.assigns.current_scope.user.id
    project = socket.assigns.project
    episode = socket.assigns.current_episode

    if episode do
      storyboards = Production.list_storyboards(episode.id)
      panels = Enum.flat_map(storyboards, &Production.list_panels(&1.id))

      # Only panels with images but no videos
      to_generate =
        Enum.filter(panels, fn p ->
          p.image_url && p.image_url != "" && (is_nil(p.video_url) || p.video_url == "")
        end)

      Enum.each(to_generate, fn panel ->
        Tasks.create_task(%{
          user_id: user_id,
          project_id: project.id,
          episode_id: episode.id,
          type: "video_panel",
          target_type: "panel",
          target_id: panel.id,
          payload: %{"panel_id" => panel.id}
        })
      end)

      {:noreply, put_flash(socket, :info, "#{length(to_generate)} 个视频生成任务已排队")}
    else
      {:noreply, put_flash(socket, :error, dgettext("projects", "Select an episode first."))}
    end
  end

  def handle_event("generate_all_lip_sync", _, socket) do
    project = socket.assigns.project
    user_id = socket.assigns.current_scope.user.id
    episode = socket.assigns.current_episode

    if episode do
      storyboards = socket.assigns.storyboards || []
      panels = Enum.flat_map(storyboards, fn sb -> sb.panels || [] end)
      voice_lines = socket.assigns.voice_lines || []

      # Match panels with voice lines that both have video + audio
      eligible =
        panels
        |> Enum.with_index()
        |> Enum.filter(fn {p, _idx} ->
          has_video = p.video_url && p.video_url != ""
          vl = Enum.find(voice_lines, fn vl -> vl.panel_id == p.id end)
          has_audio = vl && vl.audio_url && vl.audio_url != ""
          has_video && has_audio
        end)

      if eligible == [] do
        {:noreply,
         put_flash(socket, :info, dgettext("projects", "No panels with both video and voice."))}
      else
        Enum.each(eligible, fn {panel, _idx} ->
          vl = Enum.find(voice_lines, fn vl -> vl.panel_id == panel.id end)

          Tasks.create_task(%{
            user_id: user_id,
            project_id: project.id,
            episode_id: episode.id,
            type: "lip_sync",
            target_type: "panel",
            target_id: panel.id,
            payload: %{
              "panel_id" => panel.id,
              "video_url" => panel.video_url,
              "audio_url" => vl.audio_url
            }
          })
        end)

        {:noreply,
         put_flash(
           socket,
           :info,
           dgettext("projects", "Lip sync queued for %{count} panels.", count: length(eligible))
         )}
      end
    else
      {:noreply, put_flash(socket, :error, dgettext("projects", "Select an episode first."))}
    end
  end

  def handle_event("compose_video", _, socket) do
    project = socket.assigns.project
    user_id = socket.assigns.current_scope.user.id
    episode = socket.assigns.current_episode

    if episode do
      # Pass compose settings to task payload
      Tasks.create_task(%{
        user_id: user_id,
        project_id: project.id,
        episode_id: episode.id,
        type: "video_compose",
        target_type: "episode",
        target_id: episode.id,
        payload: %{
          "episode_id" => episode.id,
          "transition" => socket.assigns.compose_transition,
          "transition_ms" => socket.assigns.compose_transition_ms,
          "subtitle_mode" => socket.assigns.compose_subtitle,
          "bgm" => socket.assigns.compose_bgm,
          "selected_panel_ids" => MapSet.to_list(socket.assigns.selected_panels)
        }
      })

      {:noreply, put_flash(socket, :info, dgettext("projects", "Compose task queued."))}
    else
      {:noreply, put_flash(socket, :error, dgettext("projects", "Select an episode first."))}
    end
  end

  def handle_event("export_capcut", _, socket) do
    episode = socket.assigns.current_episode

    if episode do
      storyboards = socket.assigns.storyboards || []
      panels = Enum.flat_map(storyboards, fn sb -> sb.panels || [] end)
      voice_lines = socket.assigns.voice_lines || []

      case AstraAutoEx.Media.CapcutExporter.export(episode, panels, voice_lines) do
        {:ok, xml_path} ->
          {:noreply, put_flash(socket, :info, "CapCut XML exported: #{xml_path}")}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Export failed: #{inspect(reason)}")}
      end
    else
      {:noreply, put_flash(socket, :error, dgettext("projects", "Select an episode first."))}
    end
  end

  def handle_event("generate_promo_copy", _, socket) do
    user_id = socket.assigns.current_scope.user.id
    novel_text = socket.assigns.novel_text || ""
    parent = self()

    Task.start(fn ->
      prompt =
        "Based on this story, write a catchy 2-3 sentence promotional copy for social media (Douyin/TikTok style). Write in Chinese. Story: #{String.slice(novel_text, 0..2000)}"

      case AstraAutoEx.Workers.Handlers.Helpers.chat(
             user_id,
             "default",
             %{
               "messages" => [
                 %{
                   "role" => "system",
                   "content" =>
                     "You are a social media copywriter for short drama promotion. Write engaging, click-worthy copy in Chinese."
                 },
                 %{"role" => "user", "content" => prompt}
               ],
               "max_tokens" => 500
             }
           ) do
        {:ok, result} -> send(parent, {:promo_copy_result, result})
        {:error, _} -> send(parent, {:promo_copy_result, "Failed to generate"})
      end
    end)

    {:noreply, put_flash(socket, :info, dgettext("projects", "Generating promo copy..."))}
  end

  def handle_event("update_promo_copy", %{"promo_copy" => text}, socket) do
    {:noreply, assign(socket, :promo_copy, text)}
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
    # Auto-load 300+ voices from MiniMax API on first open
    user_id = socket.assigns.current_scope.user.id

    Task.start(fn ->
      AstraAutoEx.AI.VoicePresets.load_from_api(user_id)
    end)

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

  # ── Reference image upload handlers ──

  def handle_event("remove_ref_image", %{"index" => idx_str}, socket) do
    idx = String.to_integer(idx_str)
    urls = List.delete_at(socket.assigns.ref_image_urls, idx)
    {:noreply, assign(socket, :ref_image_urls, urls)}
  end

  def handle_event("cancel_ref_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :ref_images, ref)}
  end

  def handle_event("update_ref_prompt", %{"ref_image_prompt" => prompt}, socket) do
    {:noreply, assign(socket, :ref_image_prompt, prompt)}
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

    # Include user-uploaded reference images if any
    ref_payload =
      if socket.assigns.ref_image_urls != [] do
        %{
          "user_ref_images" => socket.assigns.ref_image_urls,
          "ref_prompt" => socket.assigns.ref_image_prompt
        }
      else
        %{}
      end

    Tasks.create_task(%{
      user_id: user_id,
      project_id: project.id,
      episode_id: socket.assigns.current_episode && socket.assigns.current_episode.id,
      type: "image_panel",
      target_type: "panel",
      target_id: panel_id,
      payload: Map.merge(%{"panel_id" => panel_id}, ref_payload)
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
    # Debounce persist to DB (save on every change via phx-change)
    if episode = socket.assigns.current_episode do
      Production.update_episode(episode, %{novel_text: text})
    end

    {:noreply, assign(socket, :novel_text, text)}
  end

  def handle_event("set_aspect_ratio", %{"ratio" => ratio}, socket) do
    Projects.update_project(socket.assigns.project, %{aspect_ratio: ratio})
    {:noreply, assign(socket, :aspect_ratio, ratio)}
  end

  def handle_event("set_art_style", %{"style" => "custom"}, socket) do
    {:noreply,
     socket
     |> assign(:art_style, "custom")
     |> assign(:show_art_style_modal, true)}
  end

  def handle_event("set_art_style", %{"style" => style}, socket) do
    save_novel_setting(socket.assigns.project.id, :art_style, style)
    {:noreply, assign(socket, :art_style, style)}
  end

  def handle_event("close_art_style_modal", _, socket) do
    {:noreply, assign(socket, :show_art_style_modal, false)}
  end

  def handle_event("apply_custom_art_style", %{"prompt" => prompt}, socket) do
    {:noreply,
     socket
     |> assign(:custom_art_prompt, prompt)
     |> assign(:show_art_style_modal, false)
     |> put_flash(:info, "自定义画风已应用")}
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
  def handle_info({:ai_write_result, text}, socket) do
    {:noreply,
     socket
     |> assign(:ai_write_phase, :result)
     |> assign(:ai_write_outline, text)}
  end

  def handle_info({:ai_write_error, reason}, socket) do
    {:noreply,
     socket
     |> assign(:ai_write_phase, :input)
     |> put_flash(:error, "AI 生成失败：#{inspect(reason)}")}
  end

  def handle_info({:entities_extracted, {:ok, entities}}, socket) do
    project = socket.assigns.project
    user_id = socket.assigns.current_scope.user.id

    # Auto-create extracted characters in project
    chars = entities.characters || []
    locs = entities.locations || []

    Enum.each(chars, fn c ->
      AstraAutoEx.Characters.create_character(%{
        project_id: project.id,
        user_id: user_id,
        name: c["name"] || "",
        introduction: c["description"] || c["personality"] || ""
      })
    end)

    Enum.each(locs, fn l ->
      AstraAutoEx.Locations.create_location(%{
        project_id: project.id,
        user_id: user_id,
        name: l["name"] || "",
        description: l["description"] || ""
      })
    end)

    # Reload characters and locations
    characters = AstraAutoEx.Characters.list_characters(project.id)
    locations = AstraAutoEx.Locations.list_locations(project.id)

    prop_count = length(entities.props || [])

    {:noreply,
     socket
     |> assign(:extracting_entities, false)
     |> assign(:extracted_entities, entities)
     |> assign(:characters, characters)
     |> assign(:locations, locations)
     |> put_flash(:info, "AI 提取完成：#{length(chars)}角色，#{length(locs)}场景，#{prop_count}道具")}
  end

  def handle_info({:entities_extracted, {:error, reason}}, socket) do
    {:noreply,
     socket
     |> assign(:extracting_entities, false)
     |> put_flash(:error, "实体提取失败：#{inspect(reason)}")}
  end

  def handle_info({:promo_copy_result, text}, socket) do
    {:noreply, assign(socket, :promo_copy, text)}
  end

  def handle_info({:wizard_complete, %{raw_text: text}}, socket) do
    {:noreply,
     socket
     |> assign(:novel_text, text)
     |> assign(:show_wizard, false)
     |> put_flash(:info, "导入完成")}
  end

  def handle_info(:wizard_closed, socket) do
    {:noreply, assign(socket, :show_wizard, false)}
  end

  def handle_info({:generate_fl_video, params}, socket) do
    project = socket.assigns.project
    user_id = socket.assigns.current_scope.user.id
    episode = socket.assigns.current_episode

    panel_id = params.panel_id
    next_panel_id = params.next_panel_id
    custom_prompt = params[:custom_prompt] || ""

    if episode do
      # Create FL video generation task
      Tasks.create_task(%{
        user_id: user_id,
        project_id: project.id,
        episode_id: episode.id,
        type: "video_panel",
        target_type: "panel",
        target_id: panel_id,
        payload: %{
          "panel_id" => panel_id,
          "fl_mode" => true,
          "next_panel_id" => next_panel_id,
          "custom_prompt" => custom_prompt,
          "use_first_last_frame" => true
        }
      })

      {:noreply, put_flash(socket, :info, "首尾帧过渡视频生成任务已提交")}
    else
      {:noreply, put_flash(socket, :error, "请先选择剧集")}
    end
  end

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

    # Auto-switch stage when pipeline tasks complete + reload clips
    socket =
      case event do
        %{type: "task.completed", task_type: "story_to_script_run"} ->
          episode = socket.assigns.current_episode

          socket
          |> assign(:clips, load_clips(episode))
          |> assign(:stage, "script")

        %{type: "task.completed", task_type: "script_to_storyboard_run"} ->
          assign(socket, :stage, "storyboard")

        _ ->
          socket
      end

    pipeline_state = if active == [], do: :idle, else: :running

    {:noreply,
     socket
     |> assign(:active_tasks, active)
     |> assign(:pipeline_state, pipeline_state)
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

  defp load_clips(nil), do: []
  defp load_clips(episode), do: Production.list_clips(episode.id)

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
  defp stage_label("film"), do: dgettext("projects", "成片")
  defp stage_label("compose"), do: dgettext("projects", "AI Edit")

  # ── Panel entity tag helpers ──
  defp parse_panel_characters(panel) do
    case Map.get(panel, :characters) do
      nil ->
        []

      chars when is_list(chars) ->
        chars

      chars when is_binary(chars) ->
        case Jason.decode(chars) do
          {:ok, list} when is_list(list) -> list
          _ -> []
        end

      _ ->
        []
    end
  end

  defp panel_location(panel) do
    loc = Map.get(panel, :location)
    if loc && loc != "", do: loc, else: nil
  end

  defp parse_panel_props(panel) do
    case Map.get(panel, :props) do
      nil ->
        []

      props when is_list(props) ->
        props

      props when is_binary(props) ->
        case Jason.decode(props) do
          {:ok, list} when is_list(list) -> list
          _ -> []
        end

      _ ->
        []
    end
  end

  # ── Reference image upload progress callback ──
  def handle_ref_upload_progress(:ref_images, entry, socket) do
    if entry.done? do
      url =
        consume_uploaded_entry(socket, entry, fn %{path: path} ->
          upload_dir = Application.get_env(:astra_auto_ex, :upload_dir, "priv/uploads")
          dest_dir = Path.join(upload_dir, "ref_images")
          File.mkdir_p!(dest_dir)
          ext = Path.extname(entry.client_name)
          filename = "#{Ecto.UUID.generate()}#{ext}"
          dest = Path.join(dest_dir, filename)
          File.cp!(path, dest)
          {:ok, "/uploads/ref_images/#{filename}"}
        end)

      urls = socket.assigns.ref_image_urls ++ [url]
      {:noreply, assign(socket, :ref_image_urls, Enum.take(urls, 5))}
    else
      {:noreply, socket}
    end
  end

  # Load a field from NovelProject settings, with fallback default
  defp load_novel_field(project, field, default) do
    case AstraAutoEx.Production.get_novel_project(project.id) do
      nil -> default
      np -> Map.get(np, field) || default
    end
  rescue
    _ -> default
  end

  defp save_novel_setting(project_id, field, value) do
    attrs = Map.put(%{project_id: project_id}, field, value)
    Production.upsert_novel_project(attrs)
  rescue
    _ -> :ok
  end

  defp pipeline_step_label("story_to_script_run"), do: "故事→剧本"
  defp pipeline_step_label("script_to_storyboard_run"), do: "剧本→分镜"
  defp pipeline_step_label("analyze_novel"), do: "故事分析"
  defp pipeline_step_label("clips_build"), do: "片段拆分"
  defp pipeline_step_label("screenplay_convert"), do: "剧本转换"
  defp pipeline_step_label("image_panel"), do: "图像生成"
  defp pipeline_step_label("video_panel"), do: "视频生成"
  defp pipeline_step_label("voice_generate"), do: "配音生成"
  defp pipeline_step_label("lip_sync"), do: "口型同步"
  defp pipeline_step_label(type), do: type
end
