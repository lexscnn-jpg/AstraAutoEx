defmodule AstraAutoEx.Workers.Handlers.MusicGenerateHandler do
  @moduledoc """
  Generates background music (BGM) via MiniMax Music-01 API.

  Follows the async polling pattern:
    1. Submit music generation request
    2. Poll for completion (up to `@max_polls` attempts)
    3. Persist the resulting `audio_url` on the Episode

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

  @max_polls 30
  @poll_interval_ms 5_000

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

      case Minimax.generate_music(request, config) do
        {:ok, %{status: :completed, audio: audio}} when is_binary(audio) ->
          handle_completed(task, episode, audio)

        {:ok, %{task_id: ext_id}} ->
          # Async mode — poll until done
          Helpers.update_progress(task, 30)
          Tasks.update_task(task, %{external_id: ext_id})
          poll_until_done(task, episode, ext_id, config, 0)

        {:ok, result} ->
          # Synchronous completion with alternative shape
          audio_url = Map.get(result, :audio_url) || Map.get(result, :audio)

          if audio_url do
            handle_completed(task, episode, audio_url)
          else
            Helpers.update_progress(task, 95)
            {:ok, %{step: "music_generate", result: result}}
          end

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
  # Async polling loop
  # --------------------------------------------------------------------------

  @spec poll_until_done(struct(), struct(), String.t(), map(), non_neg_integer()) ::
          {:ok, map()} | {:error, term()}
  defp poll_until_done(task, _episode, ext_id, _config, attempt) when attempt >= @max_polls do
    Logger.error("[MusicGenerate] Polling timeout after #{@max_polls} attempts for #{ext_id}")
    Tasks.update_task(task, %{error_message: "Polling timeout"})
    {:error, "Music generation timed out after #{@max_polls} poll attempts"}
  end

  defp poll_until_done(task, episode, ext_id, config, attempt) do
    Process.sleep(@poll_interval_ms)
    progress = 30 + min(div(attempt * 60, @max_polls), 60)
    Helpers.update_progress(task, progress)

    case Minimax.poll_task(ext_id, config) do
      {:ok, %{status: :completed, download_url: url}} ->
        handle_completed(task, episode, url)

      {:ok, %{status: :completed, audio_url: url}} ->
        handle_completed(task, episode, url)

      {:ok, %{status: :processing}} ->
        Logger.info("[MusicGenerate] Still processing (attempt #{attempt + 1}/#{@max_polls})")
        poll_until_done(task, episode, ext_id, config, attempt + 1)

      {:ok, %{status: :failed} = result} ->
        reason = Map.get(result, :error, "Music generation failed on provider side")
        handle_error(task, episode.id, reason)

      {:error, reason} ->
        # Transient poll failure — retry a few times before giving up
        if attempt < @max_polls - 1 do
          Logger.warning("[MusicGenerate] Poll error (retrying): #{inspect(reason)}")
          poll_until_done(task, episode, ext_id, config, attempt + 1)
        else
          handle_error(task, episode.id, reason)
        end
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
