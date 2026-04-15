defmodule AstraAutoExWeb.AssistantLive.Panel do
  @moduledoc """
  AI Assistant panel — live chat with LLM for project assistance.
  Embedded as live_component in WorkspaceLive. Handles its own AI calls.
  """
  use AstraAutoExWeb, :live_component

  alias AstraAutoEx.Workers.Handlers.Helpers

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:messages, [])
     |> assign(:input, "")
     |> assign(:loading, false)}
  end

  @impl true
  def update(%{ai_response: response} = assigns, socket) when is_binary(response) do
    meta = Map.get(assigns, :ai_meta, %{})
    tokens = Map.get(meta, :input_tokens, 0) + Map.get(meta, :output_tokens, 0)
    duration = Map.get(meta, :duration_ms, 0)

    ai_msg = %{role: "assistant", content: response, tokens: tokens, duration_ms: duration}
    messages = socket.assigns.messages ++ [ai_msg]
    {:ok, assign(socket, messages: messages, loading: false)}
  end

  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col h-full">
      <%!-- Header --%>
      <div class="flex items-center justify-between px-4 py-3 border-b border-[var(--glass-stroke-base)]">
        <div class="flex items-center gap-2">
          <div class="w-6 h-6 rounded-lg bg-gradient-to-br from-[var(--glass-accent-from)] to-[var(--glass-accent-to)] flex items-center justify-center">
            <svg class="w-3.5 h-3.5 text-white" fill="currentColor" viewBox="0 0 24 24">
              <path d="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09z" />
            </svg>
          </div>
          <div>
            <h3 class="text-sm font-semibold text-[var(--glass-text-primary)]">AI 助手</h3>
            <p class="text-[10px] text-[var(--glass-text-tertiary)]">{@project.name}</p>
          </div>
        </div>
        <button
          phx-click="toggle_assistant"
          class="p-1.5 rounded-lg text-[var(--glass-text-tertiary)] hover:text-[var(--glass-text-primary)] hover:bg-[var(--glass-bg-muted)] transition-all"
        >
          <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>
      <%!-- Messages --%>
      <div
        class="flex-1 overflow-y-auto p-4 space-y-3"
        id="assistant-messages"
        phx-hook="ScrollBottom"
      >
        <%= if @messages == [] do %>
          <div class="text-center py-6 space-y-3">
            <div class="w-12 h-12 mx-auto rounded-2xl bg-gradient-to-br from-[var(--glass-accent-from)]/20 to-[var(--glass-accent-to)]/20 flex items-center justify-center">
              <svg
                class="w-6 h-6 text-[var(--glass-accent-from)]"
                fill="currentColor"
                viewBox="0 0 24 24"
              >
                <path d="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09z" />
              </svg>
            </div>
            <p class="text-sm text-[var(--glass-text-tertiary)]">
              我了解你的项目，随时可以帮助你：
            </p>
            <div class="flex flex-wrap gap-1.5 justify-center">
              <button
                phx-click="assistant_quick"
                phx-value-q="分析故事结构和角色关系"
                phx-target={@myself}
                class="text-[10px] px-2.5 py-1 rounded-full border border-[var(--glass-stroke-base)] text-[var(--glass-text-secondary)] hover:border-[var(--glass-accent-from)] hover:text-[var(--glass-accent-from)] transition-colors"
              >
                分析故事结构
              </button>
              <button
                phx-click="assistant_quick"
                phx-value-q="为当前场景建议镜头运动和构图"
                phx-target={@myself}
                class="text-[10px] px-2.5 py-1 rounded-full border border-[var(--glass-stroke-base)] text-[var(--glass-text-secondary)] hover:border-[var(--glass-accent-from)] hover:text-[var(--glass-accent-from)] transition-colors"
              >
                建议镜头构图
              </button>
              <button
                phx-click="assistant_quick"
                phx-value-q="为项目生成一段社交媒体推广文案"
                phx-target={@myself}
                class="text-[10px] px-2.5 py-1 rounded-full border border-[var(--glass-stroke-base)] text-[var(--glass-text-secondary)] hover:border-[var(--glass-accent-from)] hover:text-[var(--glass-accent-from)] transition-colors"
              >
                生成推广文案
              </button>
            </div>
          </div>
        <% else %>
          <%= for msg <- @messages do %>
            <div class={[
              "rounded-xl p-3 text-sm max-w-[90%] animate-slide-up",
              if(msg.role == "user",
                do:
                  "ml-auto bg-gradient-to-r from-[var(--glass-accent-from)] to-[var(--glass-accent-to)] text-white",
                else: "mr-auto glass-surface text-[var(--glass-text-secondary)]"
              )
            ]}>
              <div class="whitespace-pre-wrap text-xs leading-relaxed">{msg.content}</div>
              <div
                :if={msg.role == "assistant" && Map.get(msg, :tokens, 0) > 0}
                class="flex items-center gap-2 mt-1.5 pt-1.5 border-t border-[var(--glass-stroke-soft)]"
              >
                <span class="text-[9px] text-[var(--glass-text-tertiary)] flex items-center gap-0.5">
                  <svg
                    class="w-2.5 h-2.5"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    viewBox="0 0 24 24"
                  >
                    <path d="M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                  {Map.get(msg, :duration_ms, 0)}ms
                </span>
                <span class="text-[9px] px-1.5 py-0.5 rounded-full bg-[var(--glass-accent-from)]/10 text-[var(--glass-accent-from)]">
                  {Map.get(msg, :tokens, 0)} tokens
                </span>
              </div>
            </div>
          <% end %>

          <div :if={@loading} class="mr-auto glass-surface rounded-xl p-3">
            <div class="flex gap-1.5 items-center">
              <span class="w-1.5 h-1.5 bg-[var(--glass-accent-from)] rounded-full animate-pulse" />
              <span class="w-1.5 h-1.5 bg-[var(--glass-accent-from)] rounded-full animate-pulse [animation-delay:0.2s]" />
              <span class="w-1.5 h-1.5 bg-[var(--glass-accent-from)] rounded-full animate-pulse [animation-delay:0.4s]" />
              <span class="text-[10px] text-[var(--glass-text-tertiary)] ml-1">思考中...</span>
            </div>
          </div>
        <% end %>
      </div>
      <%!-- Input --%>
      <div class="p-3 border-t border-[var(--glass-stroke-base)]">
        <form phx-submit="assistant_send" phx-target={@myself} class="flex gap-2">
          <input
            type="text"
            name="message"
            value={@input}
            placeholder="输入消息..."
            class="glass-input flex-1 text-xs py-2"
            autocomplete="off"
            disabled={@loading}
          />
          <button
            type="submit"
            class="glass-btn glass-btn-primary px-3 py-2 text-xs flex items-center gap-1"
            disabled={@loading}
          >
            <svg
              class="w-3.5 h-3.5"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M6 12L3.269 3.126A59.768 59.768 0 0121.485 12 59.77 59.77 0 013.27 20.876L5.999 12zm0 0h7.5"
              />
            </svg>
          </button>
        </form>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("assistant_send", %{"message" => msg}, socket) when msg != "" do
    user_msg = %{role: "user", content: msg}
    messages = socket.assigns.messages ++ [user_msg]
    socket = assign(socket, messages: messages, input: "", loading: true)

    dispatch_ai_call(socket, messages)
    {:noreply, socket}
  end

  def handle_event("assistant_send", _params, socket), do: {:noreply, socket}

  def handle_event("assistant_quick", %{"q" => question}, socket) do
    user_msg = %{role: "user", content: question}
    messages = socket.assigns.messages ++ [user_msg]
    socket = assign(socket, messages: messages, loading: true)

    dispatch_ai_call(socket, messages)
    {:noreply, socket}
  end

  # ── Private ──

  defp dispatch_ai_call(socket, messages) do
    user_id = socket.assigns.current_scope.user.id
    project = socket.assigns.project
    component_id = socket.assigns.id

    # Build project context for system prompt
    context = build_project_context(project, socket.assigns)

    Task.start(fn ->
      model_config = Helpers.get_model_config(user_id, nil, "analysis")
      provider = model_config["provider"]

      # Build messages with system context
      system_msg = %{
        "role" => "system",
        "content" => context
      }

      chat_messages =
        [system_msg] ++
          Enum.map(messages, fn m ->
            %{"role" => m.role, "content" => m.content}
          end)

      request = %{
        "model" => model_config["model"],
        "messages" => chat_messages,
        "max_tokens" => 2000
      }

      {response, meta} =
        case Helpers.chat_with_meta(user_id, provider, request) do
          {:ok, text, meta} -> {text, meta}
          {:error, reason} -> {"抱歉，出现了错误：#{inspect(reason)}", %{}}
        end

      send_update(__MODULE__,
        id: component_id,
        ai_response: response,
        ai_meta: meta
      )
    end)
  end

  defp build_project_context(project, assigns) do
    novel_text = Map.get(assigns, :novel_text, "") || ""
    characters = Map.get(assigns, :characters, [])
    locations = Map.get(assigns, :locations, [])
    stage = Map.get(assigns, :stage, "story")

    char_names = Enum.map_join(characters, "、", & &1.name)
    loc_names = Enum.map_join(locations, "、", & &1.name)

    story_excerpt =
      if String.length(novel_text) > 500,
        do: String.slice(novel_text, 0..500) <> "...",
        else: novel_text

    """
    你是 AstraAutoEx AI 创作助手。你正在帮助用户制作一个短剧/漫画视频项目。

    **项目信息：**
    - 项目名称：#{project.name}
    - 当前阶段：#{stage_name(stage)}
    - 角色：#{if char_names != "", do: char_names, else: "暂无"}
    - 场景：#{if loc_names != "", do: loc_names, else: "暂无"}
    #{if story_excerpt != "", do: "\n**故事摘要：**\n#{story_excerpt}", else: ""}

    请用中文回复，简洁专业。根据项目上下文给出有针对性的建议。
    """
  end

  defp stage_name("story"), do: "故事创作"
  defp stage_name("script"), do: "剧本拆解"
  defp stage_name("storyboard"), do: "分镜设计"
  defp stage_name("film"), do: "视频制作"
  defp stage_name("compose"), do: "AI 剪辑"
  defp stage_name(_), do: "未知"
end

# Standalone version for /assistant route
defmodule AstraAutoExWeb.AssistantLive.Standalone do
  use AstraAutoExWeb, :live_view

  alias AstraAutoEx.Workers.Handlers.Helpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:messages, [])
     |> assign(:input, "")
     |> assign(:loading, false)
     |> assign(:page_title, "AI 助手")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="container mx-auto px-4 py-6 max-w-3xl h-[calc(100vh-120px)] flex flex-col">
        <h1 class="text-xl font-bold text-[var(--glass-text-primary)] mb-4">AI 助手</h1>

        <div class="glass-card flex-1 flex flex-col overflow-hidden">
          <div class="flex-1 overflow-y-auto p-4 space-y-3">
            <%= if @messages == [] do %>
              <div class="text-center py-16">
                <p class="text-[var(--glass-text-tertiary)]">开始和 AI 对话吧</p>
              </div>
            <% else %>
              <%= for msg <- @messages do %>
                <div class={[
                  "rounded-xl p-4 text-sm max-w-[80%]",
                  if(msg.role == "user",
                    do:
                      "ml-auto bg-gradient-to-r from-[var(--glass-accent-from)] to-[var(--glass-accent-to)] text-white",
                    else: "mr-auto glass-surface text-[var(--glass-text-secondary)]"
                  )
                ]}>
                  <div class="whitespace-pre-wrap">{msg.content}</div>
                </div>
              <% end %>

              <div :if={@loading} class="mr-auto glass-surface rounded-xl p-4">
                <div class="flex gap-1.5 items-center">
                  <span class="w-1.5 h-1.5 bg-[var(--glass-accent-from)] rounded-full animate-pulse" />
                  <span class="w-1.5 h-1.5 bg-[var(--glass-accent-from)] rounded-full animate-pulse [animation-delay:0.2s]" />
                  <span class="w-1.5 h-1.5 bg-[var(--glass-accent-from)] rounded-full animate-pulse [animation-delay:0.4s]" />
                  <span class="text-xs text-[var(--glass-text-tertiary)] ml-1">思考中...</span>
                </div>
              </div>
            <% end %>
          </div>

          <div class="p-4 border-t border-[var(--glass-stroke-base)]">
            <form phx-submit="send" class="flex gap-2">
              <input
                type="text"
                name="message"
                value={@input}
                placeholder="输入消息..."
                class="glass-input flex-1 py-2"
                autocomplete="off"
                disabled={@loading}
              />
              <button type="submit" class="glass-btn glass-btn-primary px-6 py-2" disabled={@loading}>
                发送
              </button>
            </form>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("send", %{"message" => msg}, socket) when msg != "" do
    user_msg = %{role: "user", content: msg}
    messages = socket.assigns.messages ++ [user_msg]
    socket = assign(socket, messages: messages, input: "", loading: true)

    user_id = socket.assigns.current_scope.user.id
    pid = self()
    ref = make_ref()

    Task.start(fn ->
      model_config = Helpers.get_model_config(user_id, nil, "analysis")
      provider = model_config["provider"]

      chat_messages =
        [%{"role" => "system", "content" => "你是 AstraAutoEx AI 创作助手。用中文回复，简洁专业。"}] ++
          Enum.map(messages, fn m -> %{"role" => m.role, "content" => m.content} end)

      request = %{"model" => model_config["model"], "messages" => chat_messages}

      case Helpers.chat(user_id, provider, request) do
        {:ok, text} -> send(pid, {:ai_response, ref, text})
        {:error, reason} -> send(pid, {:ai_response, ref, "错误：#{inspect(reason)}"})
      end
    end)

    {:noreply, assign(socket, :ai_ref, ref)}
  end

  def handle_event("send", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_info({:ai_response, _ref, text}, socket) do
    ai_msg = %{role: "assistant", content: text}
    messages = socket.assigns.messages ++ [ai_msg]
    {:noreply, assign(socket, messages: messages, loading: false)}
  end
end
