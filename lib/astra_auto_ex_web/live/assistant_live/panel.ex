defmodule AstraAutoExWeb.AssistantLive.Panel do
  @moduledoc """
  AI Assistant panel — live chat with LLM for project assistance.
  Can be embedded as a live_component in WorkspaceLive or used standalone.
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
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col h-full">
      <%!-- Header --%>
      <div class="px-4 py-3 border-b border-[var(--glass-stroke-base)]">
        <h3 class="text-sm font-semibold text-[var(--glass-text-primary)]">
          {dgettext("projects", "AI Assistant")}
        </h3>
        <p class="text-xs text-[var(--glass-text-tertiary)]">{@project.name}</p>
      </div>

      <%!-- Messages --%>
      <div
        class="flex-1 overflow-y-auto p-4 space-y-3"
        id="assistant-messages"
        phx-hook="ScrollBottom"
      >
        <%= if @messages == [] do %>
          <div class="text-center py-8">
            <p class="text-[var(--glass-text-tertiary)] text-sm">
              {dgettext("projects", "Ask me anything about your project...")}
            </p>
          </div>
        <% else %>
          <%= for msg <- @messages do %>
            <div class={[
              "rounded-lg p-3 text-sm max-w-[90%]",
              if(msg.role == "user",
                do:
                  "ml-auto bg-gradient-to-r from-[var(--glass-accent-from)] to-[var(--glass-accent-to)] text-white",
                else: "mr-auto glass-surface text-[var(--glass-text-secondary)]"
              )
            ]}>
              <div class="whitespace-pre-wrap">{msg.content}</div>
            </div>
          <% end %>

          <div :if={@loading} class="mr-auto glass-surface rounded-lg p-3">
            <div class="flex gap-1">
              <span class="w-2 h-2 bg-[var(--glass-text-tertiary)] rounded-full animate-pulse" />
              <span class="w-2 h-2 bg-[var(--glass-text-tertiary)] rounded-full animate-pulse [animation-delay:0.2s]" />
              <span class="w-2 h-2 bg-[var(--glass-text-tertiary)] rounded-full animate-pulse [animation-delay:0.4s]" />
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
            placeholder={dgettext("projects", "Type a message...")}
            class="glass-input flex-1 text-sm py-2"
            autocomplete="off"
            disabled={@loading}
          />
          <button
            type="submit"
            class="glass-btn glass-btn-primary px-3 py-2 text-sm"
            disabled={@loading}
          >
            {dgettext("projects", "Send")}
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

    # Dispatch AI call asynchronously
    send(self(), {:assistant_generate, messages, socket.assigns.id})

    {:noreply, socket}
  end

  def handle_event("assistant_send", _params, socket), do: {:noreply, socket}

  @doc "Handle AI response from parent LiveView."
  def handle_ai_response(socket, component_id, response) do
    send_update(__MODULE__, id: component_id, ai_response: response)
    socket
  end
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
     |> assign(:page_title, dgettext("projects", "AI Assistant"))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="container mx-auto px-4 py-6 max-w-3xl h-[calc(100vh-120px)] flex flex-col">
        <h1 class="text-xl font-bold text-[var(--glass-text-primary)] mb-4">
          {dgettext("projects", "AI Assistant")}
        </h1>

        <div class="glass-card flex-1 flex flex-col overflow-hidden">
          <%!-- Messages --%>
          <div class="flex-1 overflow-y-auto p-4 space-y-3">
            <%= if @messages == [] do %>
              <div class="text-center py-16">
                <p class="text-[var(--glass-text-tertiary)]">
                  {dgettext("projects", "Start a conversation with AI.")}
                </p>
              </div>
            <% else %>
              <%= for msg <- @messages do %>
                <div class={[
                  "rounded-lg p-4 text-sm max-w-[80%]",
                  if(msg.role == "user",
                    do:
                      "ml-auto bg-gradient-to-r from-[var(--glass-accent-from)] to-[var(--glass-accent-to)] text-white",
                    else: "mr-auto glass-surface text-[var(--glass-text-secondary)]"
                  )
                ]}>
                  <div class="whitespace-pre-wrap">{msg.content}</div>
                </div>
              <% end %>

              <div :if={@loading} class="mr-auto glass-surface rounded-lg p-4">
                <div class="flex gap-1">
                  <span class="w-2 h-2 bg-[var(--glass-text-tertiary)] rounded-full animate-pulse" />
                  <span class="w-2 h-2 bg-[var(--glass-text-tertiary)] rounded-full animate-pulse [animation-delay:0.2s]" />
                  <span class="w-2 h-2 bg-[var(--glass-text-tertiary)] rounded-full animate-pulse [animation-delay:0.4s]" />
                </div>
              </div>
            <% end %>
          </div>

          <%!-- Input --%>
          <div class="p-4 border-t border-[var(--glass-stroke-base)]">
            <form phx-submit="send" class="flex gap-2">
              <input
                type="text"
                name="message"
                value={@input}
                placeholder={dgettext("projects", "Type a message...")}
                class="glass-input flex-1 py-2"
                autocomplete="off"
                disabled={@loading}
              />
              <button
                type="submit"
                class="glass-btn glass-btn-primary px-6 py-2"
                disabled={@loading}
              >
                {dgettext("projects", "Send")}
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

    # Call LLM asynchronously
    user_id = socket.assigns.current_scope.user.id
    pid = self()
    ref = make_ref()

    Task.start(fn ->
      model_config = Helpers.get_model_config(user_id, nil, :llm)
      provider = model_config["provider"]

      # Build chat request
      contents =
        Enum.map(messages, fn m ->
          role = if m.role == "user", do: "user", else: "model"
          %{"role" => role, "parts" => [%{"text" => m.content}]}
        end)

      request = %{model: model_config["model"], contents: contents}

      case Helpers.chat(user_id, provider, request) do
        {:ok, text} -> send(pid, {:ai_response, ref, text})
        {:error, reason} -> send(pid, {:ai_response, ref, "Error: #{inspect(reason)}"})
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
