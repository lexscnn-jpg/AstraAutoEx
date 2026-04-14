defmodule AstraAutoExWeb.WorkspaceLive.VoicePicker do
  @moduledoc "Voice preset picker — select voice ID and emotion for TTS."
  use AstraAutoExWeb, :live_component

  @voice_presets [
    %{id: "Calm_Woman", name: "Calm Woman", gender: "female", lang: "zh"},
    %{id: "Gentle_Woman", name: "Gentle Woman", gender: "female", lang: "zh"},
    %{id: "Sweet_Girl", name: "Sweet Girl", gender: "female", lang: "zh"},
    %{id: "Confident_Woman", name: "Confident Woman", gender: "female", lang: "zh"},
    %{id: "Deep_Voice_Man", name: "Deep Voice Man", gender: "male", lang: "zh"},
    %{id: "Warm_Man", name: "Warm Man", gender: "male", lang: "zh"},
    %{id: "Young_Man", name: "Young Man", gender: "male", lang: "zh"},
    %{id: "Narrator", name: "Narrator", gender: "male", lang: "zh"},
    %{id: "Cute_Boy", name: "Cute Boy", gender: "male", lang: "zh"},
    %{id: "Energetic_Girl", name: "Energetic Girl", gender: "female", lang: "en"},
    %{id: "Professional_Man", name: "Professional Man", gender: "male", lang: "en"},
    %{id: "Friendly_Woman", name: "Friendly Woman", gender: "female", lang: "en"}
  ]

  @emotions ~w(neutral happy sad angry surprised fearful disgusted calm excited whisper)

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:presets, @voice_presets)
     |> assign(:emotions, @emotions)
     |> assign(:selected_voice, assigns[:selected_voice] || "Calm_Woman")
     |> assign(:selected_emotion, assigns[:selected_emotion] || "neutral")
     |> assign(:filter_gender, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center">
      <div class="absolute inset-0 bg-black/70" phx-click="close_voice_picker" />
      <div class="glass-card p-6 w-full max-w-md relative z-10">
        <h2 class="text-lg font-bold text-[var(--glass-text-primary)] mb-4">
          {dgettext("projects", "Voice Settings")}
        </h2>
        <%!-- Gender filter --%>
        <div class="flex gap-2 mb-4">
          <button
            phx-click="filter_voice_gender"
            phx-value-gender=""
            phx-target={@myself}
            class={[
              "glass-chip text-xs cursor-pointer",
              is_nil(@filter_gender) &&
                "bg-[var(--glass-accent-from)]/20 ring-1 ring-[var(--glass-accent-from)]/30"
            ]}
          >
            All
          </button>
          <button
            phx-click="filter_voice_gender"
            phx-value-gender="female"
            phx-target={@myself}
            class={[
              "glass-chip text-xs cursor-pointer",
              @filter_gender == "female" &&
                "bg-[var(--glass-accent-from)]/20 ring-1 ring-[var(--glass-accent-from)]/30"
            ]}
          >
            Female
          </button>
          <button
            phx-click="filter_voice_gender"
            phx-value-gender="male"
            phx-target={@myself}
            class={[
              "glass-chip text-xs cursor-pointer",
              @filter_gender == "male" &&
                "bg-[var(--glass-accent-from)]/20 ring-1 ring-[var(--glass-accent-from)]/30"
            ]}
          >
            Male
          </button>
        </div>
        <%!-- Voice list --%>
        <div class="space-y-1 max-h-48 overflow-y-auto mb-4">
          <%= for preset <- filtered_presets(@presets, @filter_gender) do %>
            <button
              phx-click="select_voice"
              phx-value-voice-id={preset.id}
              phx-target={@myself}
              class={[
                "w-full flex items-center gap-3 p-2 rounded-lg text-left transition-all",
                if(@selected_voice == preset.id,
                  do: "bg-[var(--glass-accent-from)]/10 ring-1 ring-[var(--glass-accent-from)]/30",
                  else: "hover:bg-[var(--glass-bg-muted)]"
                )
              ]}
            >
              <div class="w-8 h-8 rounded-full bg-[var(--glass-bg-muted)] flex items-center justify-center text-xs text-[var(--glass-text-secondary)]">
                {String.first(preset.name)}
              </div>

              <div class="flex-1">
                <span class="text-sm text-[var(--glass-text-primary)]">{preset.name}</span>
                <div class="flex gap-1 mt-0.5">
                  <span class="glass-chip text-[10px]">{preset.gender}</span>
                  <span class="glass-chip text-[10px]">{preset.lang}</span>
                </div>
              </div>
              <span :if={@selected_voice == preset.id} class="text-green-500 text-sm">OK</span>
            </button>
          <% end %>
        </div>
        <%!-- Emotion --%>
        <div class="mb-4">
          <label class="text-xs text-[var(--glass-text-tertiary)] mb-2 block">
            {dgettext("projects", "Emotion")}
          </label>
          <div class="flex flex-wrap gap-1">
            <%= for emotion <- @emotions do %>
              <button
                phx-click="select_emotion"
                phx-value-emotion={emotion}
                phx-target={@myself}
                class={[
                  "glass-chip text-xs cursor-pointer",
                  @selected_emotion == emotion &&
                    "bg-[var(--glass-accent-from)]/20 ring-1 ring-[var(--glass-accent-from)]/30"
                ]}
              >
                {emotion}
              </button>
            <% end %>
          </div>
        </div>

        <div class="flex justify-end gap-2">
          <button
            phx-click="close_voice_picker"
            class="px-4 py-2 text-sm text-[var(--glass-text-tertiary)] hover:text-[var(--glass-text-primary)]"
          >
            {dgettext("default", "Cancel")}
          </button>
          <button
            phx-click="confirm_voice"
            phx-target={@myself}
            class="glass-btn glass-btn-primary px-6 py-2 text-sm"
          >
            {dgettext("projects", "Apply")}
          </button>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("filter_voice_gender", %{"gender" => ""}, socket) do
    {:noreply, assign(socket, :filter_gender, nil)}
  end

  def handle_event("filter_voice_gender", %{"gender" => g}, socket) do
    {:noreply, assign(socket, :filter_gender, g)}
  end

  def handle_event("select_voice", %{"voice-id" => id}, socket) do
    {:noreply, assign(socket, :selected_voice, id)}
  end

  def handle_event("select_emotion", %{"emotion" => e}, socket) do
    {:noreply, assign(socket, :selected_emotion, e)}
  end

  def handle_event("confirm_voice", _, socket) do
    send(
      self(),
      {:voice_selected,
       %{
         voice_id: socket.assigns.selected_voice,
         emotion: socket.assigns.selected_emotion,
         target_id: socket.assigns[:target_id]
       }}
    )

    {:noreply, socket}
  end

  defp filtered_presets(presets, nil), do: presets

  defp filtered_presets(presets, gender) do
    Enum.filter(presets, fn p -> p.gender == gender end)
  end
end
