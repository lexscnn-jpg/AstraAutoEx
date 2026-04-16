defmodule AstraAutoEx.Workers.Handlers.MusicGenerateHandler do
  @moduledoc """
  Generates background music (BGM) via MiniMax Music-01 API (synchronous).

  Persists the resulting audio URL on the Episode.

  Payload keys:
    - `episode_id` (required) — target episode for the BGM
    - `prompt` — style / mood description for the music
    - `lyrics` — optional lyrics for vocal tracks
    - `is_instrumental` — boolean, default true
    - `model` — MiniMax music model ID (default "music-2.6")
  """

  require Logger

  alias AstraAutoEx.Workers.Handlers.Helpers
  alias AstraAutoEx.{Production, Tasks}
  alias AstraAutoEx.AI.Providers.Minimax

  # --------------------------------------------------------------------------
  # Public API
  # --------------------------------------------------------------------------

  @spec execute(struct()) :: {:ok, map()} | {:error, term()}
  def execute(task) do
    payload = task.payload || %{}
    episode_id = payload["episode_id"] || task.target_id

    with {:ok, episode} <- fetch_episode(episode_id),
         {:ok, config} <- Helpers.get_provider_config(task.user_id, "minimax") do
      Helpers.update_progress(task, 10)
      Logger.info("[MusicGenerate] Starting BGM generation for episode #{episode_id}")

      request = build_request(payload)
      Helpers.update_progress(task, 20)

      # Note: MiniMax music API is synchronous — returns audio in one shot.
      # If a future async path is added, dispatch by shape here.
      case Minimax.generate_music(request, config) do
        {:ok, %{status: :completed, audio: audio}} when is_binary(audio) ->
          handle_completed(task, episode, audio)

        {:error, reason} ->
          handle_error(task, episode_id, reason)
      end
    else
      {:error, reason} ->
        Tasks.update_task(task, %{status: "failed", error_message: inspect(reason)})
        {:error, reason}
    end
  end

  # --------------------------------------------------------------------------
  # Private helpers
  # --------------------------------------------------------------------------

  @spec fetch_episode(String.t()) :: {:ok, struct()} | {:error, String.t()}
  defp fetch_episode(episode_id) do
    try do
      {:ok, Production.get_episode!(episode_id)}
    rescue
      Ecto.NoResultsError -> {:error, "Episode #{episode_id} not found"}
    end
  end

  @spec build_request(map()) :: map()
  defp build_request(payload) do
    %{
      prompt: payload["prompt"] || "cinematic background music, emotional, orchestral",
      model: payload["model"] || "music-2.6",
      lyrics: payload["lyrics"],
      is_instrumental: Map.get(payload, "is_instrumental", true)
    }
  end

  @spec handle_completed(struct(), struct(), String.t()) :: {:ok, map()}
  defp handle_completed(task, episode, audio_url) do
    Logger.info("[MusicGenerate] BGM ready for episode #{episode.id}: #{audio_url}")

    Production.update_episode(episode, %{bgm_url: audio_url})
    Helpers.update_progress(task, 95)

    {:ok,
     %{
       step: "music_generate",
       audio_url: audio_url,
       episode_id: episode.id
     }}
  end

  @spec handle_error(struct(), term(), term()) :: {:error, term()}
  defp handle_error(task, episode_id, reason) do
    Logger.error("[MusicGenerate] Failed for episode #{episode_id}: #{inspect(reason)}")
    Tasks.update_task(task, %{error_message: inspect(reason)})
    {:error, reason}
  end
end
