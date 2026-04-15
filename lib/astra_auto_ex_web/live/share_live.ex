defmodule AstraAutoExWeb.ShareLive do
  @moduledoc "Public video sharing page. Plays a composed episode video without authentication."
  use AstraAutoExWeb, :live_view

  alias AstraAutoEx.Production

  @impl true
  def mount(%{"public_id" => public_id}, _session, socket) do
    case Production.get_episode_by_public_id(public_id) do
      %{composed_video_key: url} = episode when is_binary(url) and url != "" ->
        {:ok,
         socket
         |> assign(:episode, episode)
         |> assign(:video_url, url)
         |> assign(:not_found, false)
         |> assign(:page_title, episode.title || "AstraAutoEx Video")}

      %{} = episode ->
        {:ok,
         socket
         |> assign(:episode, episode)
         |> assign(:video_url, nil)
         |> assign(:not_found, false)
         |> assign(:page_title, episode.title || "AstraAutoEx Video")}

      nil ->
        {:ok,
         socket
         |> assign(:episode, nil)
         |> assign(:video_url, nil)
         |> assign(:not_found, true)
         |> assign(:page_title, "Not Found")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-[var(--glass-bg-body)] flex items-center justify-center p-4">
      <div class="w-full max-w-3xl">
        <%= cond do %>
          <% @not_found -> %>
            <.not_found_view />
          <% @video_url -> %>
            <.video_view episode={@episode} video_url={@video_url} />
          <% true -> %>
            <.no_video_view episode={@episode} />
        <% end %>

        <%!-- Branding footer --%>
        <div class="text-center mt-6">
          <p class="text-xs text-[var(--glass-text-tertiary)]">
            Powered by
            <a href="/" class="text-[var(--glass-accent-from)] hover:underline">AstraAutoEx</a>
          </p>
        </div>
      </div>
    </div>
    """
  end

  defp video_view(assigns) do
    ~H"""
    <div class="glass-card overflow-hidden">
      <%!-- Video player --%>
      <div class="relative bg-black aspect-video">
        <video
          src={@video_url}
          controls
          autoplay={false}
          class="w-full h-full object-contain"
          poster=""
        >
          Your browser does not support the video tag.
        </video>
      </div>
      <%!-- Info section --%>
      <div class="p-5 space-y-2">
        <h1 class="text-lg font-bold text-[var(--glass-text-primary)]">
          {@episode.title || "Untitled"}
        </h1>

        <p :if={@episode.name} class="text-sm text-[var(--glass-text-secondary)]">
          {@episode.name}
        </p>
      </div>
    </div>
    """
  end

  defp no_video_view(assigns) do
    ~H"""
    <div class="glass-card p-10 text-center">
      <div class="inline-flex items-center justify-center w-16 h-16 rounded-full bg-yellow-500/10 mb-4">
        <svg
          class="w-8 h-8 text-yellow-400"
          fill="none"
          stroke="currentColor"
          stroke-width="1.5"
          viewBox="0 0 24 24"
        >
          <path d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z" />
        </svg>
      </div>

      <h2 class="text-lg font-semibold text-[var(--glass-text-primary)] mb-2">
        {@episode.title || "Untitled"}
      </h2>

      <p class="text-sm text-[var(--glass-text-tertiary)]">
        This video is still being produced. Please check back later.
      </p>
    </div>
    """
  end

  defp not_found_view(assigns) do
    ~H"""
    <div class="glass-card p-10 text-center">
      <div class="inline-flex items-center justify-center w-16 h-16 rounded-full bg-red-500/10 mb-4">
        <svg
          class="w-8 h-8 text-red-400"
          fill="none"
          stroke="currentColor"
          stroke-width="1.5"
          viewBox="0 0 24 24"
        >
          <path d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728A9 9 0 015.636 5.636m12.728 12.728L5.636 5.636" />
        </svg>
      </div>

      <h2 class="text-lg font-semibold text-[var(--glass-text-primary)] mb-2">
        Not Found
      </h2>

      <p class="text-sm text-[var(--glass-text-tertiary)]">
        This video does not exist or has been removed.
      </p>
    </div>
    """
  end
end
