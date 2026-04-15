defmodule AstraAutoExWeb.WorkspaceLive.ImportWizard do
  @moduledoc "4-step import wizard: source selection -> parsing -> mapping -> confirm."
  use AstraAutoExWeb, :live_component

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:step, 1)
     |> assign(:source_type, "text")
     |> assign(:raw_text, "")
     |> assign(:parsing, false)
     |> assign(:parsed_episodes, [])
     |> assign(:split_mode, "auto")
     |> assign(:error, nil)
     |> allow_upload(:import_file,
       accept: ~w(.txt .md),
       max_entries: 1,
       max_file_size: 5_000_000,
       auto_upload: true,
       progress: &handle_upload_progress/3
     )}
  end

  @impl true
  def update(%{parsing_done: true, parsed_episodes: episodes}, socket) do
    {:ok,
     socket
     |> assign(:parsing, false)
     |> assign(:parsed_episodes, episodes)
     |> assign(:step, 3)}
  end

  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="glass-card p-6">
      <div class="flex items-center justify-between mb-6">
        <h3 class="text-lg font-semibold text-[var(--glass-text-primary)]">智能导入向导</h3>

        <button
          type="button"
          phx-click="close_wizard"
          phx-target={@myself}
          class="text-[var(--glass-text-tertiary)] hover:text-[var(--glass-text-primary)]"
        >
          <svg class="w-5 h-5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
            <path d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>
      <!-- Step Indicators -->
      <div class="flex items-center gap-2 mb-8">
        <%= for {label, num} <- [{"来源", 1}, {"解析", 2}, {"映射", 3}, {"确认", 4}] do %>
          <div class="flex items-center gap-2">
            <div class={"w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold transition-all " <>
              cond do
                num < @step -> "bg-green-500/20 text-green-400"
                num == @step -> "bg-gradient-to-br from-[var(--glass-accent-from)] to-[var(--glass-accent-to)] text-white"
                true -> "bg-[var(--glass-bg-muted)] text-[var(--glass-text-tertiary)]"
              end}>
              <%= if num < @step do %>
                <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                  <path
                    fill-rule="evenodd"
                    d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z"
                    clip-rule="evenodd"
                  />
                </svg>
              <% else %>
                {num}
              <% end %>
            </div>

            <span class={"text-xs " <> if(num == @step, do: "text-[var(--glass-text-primary)]", else: "text-[var(--glass-text-tertiary)]")}>
              {label}
            </span>
            <%= if num < 4 do %>
              <div class={"w-8 h-px " <> if(num < @step, do: "bg-green-500/40", else: "bg-[var(--glass-stroke-base)]")} />
            <% end %>
          </div>
        <% end %>
      </div>
      <!-- Step Content -->
      <%= case @step do %>
        <% 1 -> %>
          <.step_source {assigns} />
        <% 2 -> %>
          <.step_parse {assigns} />
        <% 3 -> %>
          <.step_mapping {assigns} />
        <% 4 -> %>
          <.step_confirm {assigns} />
      <% end %>
    </div>
    """
  end

  defp step_source(assigns) do
    ~H"""
    <div class="space-y-4">
      <p class="text-sm text-[var(--glass-text-secondary)]">选择你的故事来源方式：</p>

      <div class="grid grid-cols-2 gap-3">
        <button
          type="button"
          phx-click="set_source"
          phx-value-type="text"
          phx-target={@myself}
          class={"glass-card p-4 text-center transition-all cursor-pointer " <>
            if(@source_type == "text", do: "ring-2 ring-[var(--glass-accent-from)]", else: "hover:ring-1 hover:ring-[var(--glass-stroke-base)]")}
        >
          <div class="text-2xl mb-2">📝</div>

          <div class="text-sm font-medium text-[var(--glass-text-primary)]">粘贴文本</div>

          <div class="text-xs text-[var(--glass-text-tertiary)] mt-1">直接输入故事内容</div>
        </button>
        <button
          type="button"
          phx-click="set_source"
          phx-value-type="file"
          phx-target={@myself}
          class={"glass-card p-4 text-center transition-all cursor-pointer " <>
            if(@source_type == "file", do: "ring-2 ring-[var(--glass-accent-from)]", else: "hover:ring-1 hover:ring-[var(--glass-stroke-base)]")}
        >
          <div class="text-2xl mb-2">📄</div>

          <div class="text-sm font-medium text-[var(--glass-text-primary)]">上传文件</div>

          <div class="text-xs text-[var(--glass-text-tertiary)] mt-1">.txt / .md 文件</div>
        </button>
      </div>

      <%= if @source_type == "file" do %>
        <form phx-change="validate_file" phx-target={@myself} class="space-y-3">
          <div class="glass-surface rounded-xl p-6 border-2 border-dashed border-[var(--glass-stroke-base)] text-center">
            <.live_file_input upload={@uploads.import_file} class="hidden" />
            <label
              for={@uploads.import_file.ref}
              class="cursor-pointer block"
            >
              <svg
                class="w-10 h-10 mx-auto text-[var(--glass-text-tertiary)] mb-2"
                fill="none"
                stroke="currentColor"
                stroke-width="1.5"
                viewBox="0 0 24 24"
              >
                <path d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5m-13.5-9L12 3m0 0l4.5 4.5M12 3v13.5" />
              </svg>
              <p class="text-sm text-[var(--glass-text-secondary)]">点击选择 .txt / .md 文件</p>
              <p class="text-xs text-[var(--glass-text-tertiary)] mt-1">最大 5MB</p>
            </label>
          </div>
          <%= for entry <- @uploads.import_file.entries do %>
            <div class="glass-surface rounded-lg px-4 py-2 flex items-center justify-between">
              <span class="text-sm text-[var(--glass-text-primary)]">{entry.client_name}</span>
              <span class="text-xs text-[var(--glass-text-tertiary)]">
                {Float.round(entry.client_size / 1024, 1)} KB
              </span>
            </div>
          <% end %>
        </form>
      <% else %>
        <textarea
          phx-change="update_raw_text"
          phx-target={@myself}
          name="raw_text"
          rows="8"
          class="glass-input w-full text-sm"
          placeholder="在此粘贴你的故事文本..."
        ><%= @raw_text %></textarea>
      <% end %>

      <%!-- Split mode selection --%>
      <div class="space-y-2">
        <p class="text-xs font-medium text-[var(--glass-text-secondary)]">章节拆分方式：</p>
        <div class="flex gap-2">
          <%= for {label, mode} <- [{"自动检测", "auto"}, {"按空行", "blank_lines"}, {"不拆分", "none"}] do %>
            <button
              type="button"
              phx-click="set_split_mode"
              phx-value-mode={mode}
              phx-target={@myself}
              class={"glass-chip text-xs px-3 py-1.5 cursor-pointer transition-all " <>
                if(@split_mode == mode, do: "bg-[var(--glass-accent-from)]/20 text-[var(--glass-accent-from)] ring-1 ring-[var(--glass-accent-from)]/30", else: "hover:bg-[var(--glass-bg-muted)]")}
            >
              {label}
            </button>
          <% end %>
        </div>
      </div>

      <div class="flex justify-end">
        <button
          type="button"
          phx-click="next_step"
          phx-target={@myself}
          disabled={@raw_text == "" and @uploads.import_file.entries == []}
          class="glass-btn glass-btn-primary px-6 py-2 disabled:opacity-50"
        >
          下一步 →
        </button>
      </div>
    </div>
    """
  end

  defp step_parse(assigns) do
    ~H"""
    <div class="text-center py-12">
      <%= if @parsing do %>
        <div class="inline-flex items-center justify-center w-16 h-16 rounded-full bg-gradient-to-br from-[var(--glass-accent-from)] to-[var(--glass-accent-to)] mb-4 animate-pulse">
          <svg class="w-8 h-8 text-white animate-spin" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
            <path
              class="opacity-75"
              fill="currentColor"
              d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"
            />
          </svg>
        </div>

        <p class="text-[var(--glass-text-primary)] font-medium mb-2">AI 正在分析你的故事...</p>

        <p class="text-sm text-[var(--glass-text-tertiary)]">自动识别剧集分割点、角色和场景</p>
      <% else %>
        <%= if @error do %>
          <div class="text-red-400 mb-4">{@error}</div>

          <button
            type="button"
            phx-click="retry_parse"
            phx-target={@myself}
            class="glass-btn glass-btn-primary px-6 py-2"
          >
            重试
          </button>
        <% else %>
          <p class="text-[var(--glass-text-secondary)]">解析完成</p>

          <button
            type="button"
            phx-click="next_step"
            phx-target={@myself}
            class="glass-btn glass-btn-primary px-6 py-2 mt-4"
          >
            下一步 →
          </button>
        <% end %>
      <% end %>
    </div>
    """
  end

  defp step_mapping(assigns) do
    ~H"""
    <div class="space-y-4">
      <p class="text-sm text-[var(--glass-text-secondary)]">
        AI 已将故事拆分为 {length(@parsed_episodes)} 集。你可以调整顺序和内容：
      </p>

      <div class="space-y-3 max-h-[400px] overflow-y-auto">
        <%= for {ep, idx} <- Enum.with_index(@parsed_episodes) do %>
          <div class="glass-card p-4">
            <div class="flex items-center gap-3">
              <span class="flex-shrink-0 w-8 h-8 rounded-full bg-[var(--glass-bg-muted)] flex items-center justify-center text-sm font-bold text-[var(--glass-text-secondary)]">
                {idx + 1}
              </span>
              <div class="flex-1 min-w-0">
                <div class="text-sm font-medium text-[var(--glass-text-primary)] truncate">
                  {Map.get(ep, :title, "第 #{idx + 1} 集")}
                </div>

                <div class="text-xs text-[var(--glass-text-tertiary)] line-clamp-2 mt-1">
                  {String.slice(Map.get(ep, :content, ""), 0..120)}...
                </div>
              </div>
              <span class="text-xs text-[var(--glass-text-tertiary)] flex-shrink-0">
                {String.length(Map.get(ep, :content, ""))} 字
              </span>
            </div>
          </div>
        <% end %>
      </div>

      <%= if @parsed_episodes == [] do %>
        <div class="text-center py-8 text-[var(--glass-text-tertiary)]">未检测到剧集分割。将整段文本作为单集处理。</div>
      <% end %>

      <div class="flex justify-between">
        <button
          type="button"
          phx-click="prev_step"
          phx-target={@myself}
          class="glass-btn px-6 py-2 text-[var(--glass-text-secondary)]"
        >
          ← 上一步
        </button>
        <button
          type="button"
          phx-click="next_step"
          phx-target={@myself}
          class="glass-btn glass-btn-primary px-6 py-2"
        >
          下一步 →
        </button>
      </div>
    </div>
    """
  end

  defp step_confirm(assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="glass-card p-4 bg-green-500/5 border border-green-500/20">
        <div class="flex items-center gap-3">
          <svg class="w-6 h-6 text-green-400 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
            <path
              fill-rule="evenodd"
              d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z"
              clip-rule="evenodd"
            />
          </svg>
          <div>
            <div class="text-sm font-medium text-green-400">准备就绪</div>

            <div class="text-xs text-[var(--glass-text-tertiary)]">
              共 {length(@parsed_episodes)} 集，{String.length(@raw_text)} 字
            </div>
          </div>
        </div>
      </div>

      <div class="flex justify-between">
        <button
          type="button"
          phx-click="prev_step"
          phx-target={@myself}
          class="glass-btn px-6 py-2 text-[var(--glass-text-secondary)]"
        >
          ← 上一步
        </button>
        <div class="flex gap-3">
          <button
            type="button"
            phx-click="confirm_import"
            phx-value-analyze="false"
            phx-target={@myself}
            class="glass-btn px-6 py-2"
          >
            保存
          </button>
          <button
            type="button"
            phx-click="confirm_import"
            phx-value-analyze="true"
            phx-target={@myself}
            class="glass-btn glass-btn-primary px-6 py-2"
          >
            保存并分析资产
          </button>
        </div>
      </div>
    </div>
    """
  end

  # ── Event Handlers ──

  @impl true
  def handle_event("set_source", %{"type" => type}, socket) do
    {:noreply, assign(socket, :source_type, type)}
  end

  def handle_event("set_split_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, :split_mode, mode)}
  end

  def handle_event("update_raw_text", %{"raw_text" => text}, socket) do
    {:noreply, assign(socket, :raw_text, text)}
  end

  def handle_event("validate_file", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("next_step", _params, socket) do
    step = socket.assigns.step

    socket =
      cond do
        step == 1 ->
          socket
          |> maybe_consume_upload()
          |> then(fn s ->
            if s.assigns.raw_text != "" do
              s
              |> assign(:step, 2)
              |> assign(:parsing, true)
              |> start_parsing()
            else
              s
            end
          end)

        step >= 2 and step < 4 ->
          assign(socket, :step, step + 1)

        true ->
          socket
      end

    {:noreply, socket}
  end

  def handle_event("prev_step", _params, socket) do
    {:noreply, assign(socket, :step, max(1, socket.assigns.step - 1))}
  end

  def handle_event("retry_parse", _params, socket) do
    {:noreply,
     socket
     |> assign(:parsing, true)
     |> assign(:error, nil)
     |> start_parsing()}
  end

  def handle_event("confirm_import", %{"analyze" => analyze}, socket) do
    send(
      self(),
      {:wizard_complete,
       %{
         raw_text: socket.assigns.raw_text,
         episodes: socket.assigns.parsed_episodes,
         analyze_assets: analyze == "true"
       }}
    )

    {:noreply, socket}
  end

  def handle_event("close_wizard", _params, socket) do
    send(self(), :wizard_closed)
    {:noreply, socket}
  end

  # ── File Upload ──

  defp handle_upload_progress(:import_file, _entry, socket), do: {:noreply, socket}

  defp maybe_consume_upload(socket) do
    case socket.assigns.source_type do
      "file" ->
        entries = socket.assigns.uploads.import_file.entries

        if entries != [] do
          [text] =
            consume_uploaded_entries(socket, :import_file, fn %{path: path}, _entry ->
              {:ok, File.read!(path)}
            end)

          assign(socket, :raw_text, text)
        else
          socket
        end

      _ ->
        socket
    end
  end

  # ── Parsing ──

  defp start_parsing(socket) do
    text = socket.assigns.raw_text
    split_mode = socket.assigns.split_mode
    myself = socket.assigns.myself

    Task.start(fn ->
      episodes = split_episodes(text, split_mode)
      send_update(myself, %{parsed_episodes: episodes, parsing_done: true})
    end)

    socket
  end

  @doc false
  @spec split_episodes(String.t(), String.t()) :: [%{title: String.t(), content: String.t()}]
  def split_episodes(text, mode \\ "auto")

  def split_episodes(text, "none") do
    [%{title: "第 1 集", content: String.trim(text)}]
  end

  def split_episodes(text, "blank_lines") do
    text
    |> String.split(~r/\n\s*\n\s*\n/, trim: true)
    |> Enum.reject(&(String.trim(&1) == ""))
    |> Enum.with_index(1)
    |> Enum.map(fn {content, idx} ->
      %{title: "第 #{idx} 集", content: String.trim(content)}
    end)
    |> case do
      [] -> [%{title: "第 1 集", content: String.trim(text)}]
      list -> list
    end
  end

  def split_episodes(text, _auto) do
    # Try chapter markers first: "第X集", "第X章", "Chapter X", "EP X"
    parts =
      Regex.split(
        ~r/(?=第\d+[集章]|(?i)chapter\s*\d+|(?i)episode\s*\d+|(?i)ep\s*\d+)/u,
        text
      )
      |> Enum.reject(&(String.trim(&1) == ""))

    if length(parts) > 1 do
      parts
      |> Enum.with_index(1)
      |> Enum.map(fn {content, idx} ->
        title = extract_title(content, idx)
        %{title: title, content: String.trim(content)}
      end)
    else
      # Fallback: try double-blank-line splits
      blank_parts =
        String.split(text, ~r/\n\s*\n\s*\n/, trim: true)
        |> Enum.reject(&(String.trim(&1) == ""))

      if length(blank_parts) > 1 do
        blank_parts
        |> Enum.with_index(1)
        |> Enum.map(fn {content, idx} ->
          %{title: "第 #{idx} 集", content: String.trim(content)}
        end)
      else
        [%{title: "第 1 集", content: String.trim(text)}]
      end
    end
  end

  defp extract_title(content, idx) do
    case Regex.run(
           ~r/^(第\d+[集章]|(?i)chapter\s*\d+|(?i)episode\s*\d+|(?i)ep\s*\d+)[：:\s]*(.*)/u,
           String.trim(content)
         ) do
      [_, _marker, name] when name != "" ->
        name = name |> String.trim() |> String.slice(0..30)
        "第 #{idx} 集：#{name}"

      _ ->
        "第 #{idx} 集"
    end
  end
end
