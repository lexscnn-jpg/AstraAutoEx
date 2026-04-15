defmodule AstraAutoEx.Workers.Handlers.VoiceDesignHandler do
  @moduledoc """
  MiniMax voice clone / voice design handler.

  Takes a character ID and an optional reference audio URL, calls the MiniMax
  voice-design endpoint to create a custom voice profile, and persists the
  resulting `voice_id` back to the character's `custom_voice_url` field.

  Payload keys:
    - `character_id` (required) — target character
    - `reference_audio_url` — URL of the reference audio sample
    - `prompt` — textual description of the desired voice
    - `preview_text` — text used for the trial audio clip
  """

  require Logger

  alias AstraAutoEx.Workers.Handlers.Helpers
  alias AstraAutoEx.{Characters, Tasks}
  alias AstraAutoEx.AI.Providers.Minimax

  # --------------------------------------------------------------------------
  # Public API
  # --------------------------------------------------------------------------

  @spec execute(struct()) :: {:ok, map()} | {:error, term()}
  def execute(task) do
    payload = task.payload || %{}
    character_id = payload["character_id"] || task.target_id

    with {:ok, character} <- fetch_character(character_id),
         {:ok, config} <- Helpers.get_provider_config(task.user_id, "minimax") do
      Helpers.update_progress(task, 10)
      Logger.info("[VoiceDesign] Starting voice design for character #{character.name}")

      request = build_request(payload, character)
      Helpers.update_progress(task, 30)

      case Minimax.design_voice(request, config) do
        {:ok, %{voice_id: voice_id} = result} when is_binary(voice_id) ->
          handle_success(task, character, voice_id, result)

        {:ok, result} ->
          # Provider returned without a voice_id — treat as partial success
          Logger.warning("[VoiceDesign] No voice_id in result: #{inspect(result)}")
          Helpers.update_progress(task, 95)
          {:ok, %{step: "voice_design", result: result, character_id: character_id}}

        {:error, reason} ->
          handle_error(task, character_id, reason)
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

  @spec fetch_character(String.t() | integer()) :: {:ok, struct()} | {:error, String.t()}
  defp fetch_character(character_id) do
    try do
      {:ok, Characters.get_character!(character_id)}
    rescue
      Ecto.NoResultsError -> {:error, "Character #{character_id} not found"}
    end
  end

  @spec build_request(map(), struct()) :: map()
  defp build_request(payload, character) do
    prompt =
      payload["prompt"] ||
        "#{character.gender || "neutral"} voice, #{character.introduction || character.name}"

    preview_text =
      payload["preview_text"] || "你好，我是#{character.name}，很高兴认识你。"

    base = %{
      prompt: prompt,
      preview_text: preview_text
    }

    # Attach reference audio URL when provided (for voice cloning)
    case payload["reference_audio_url"] do
      url when is_binary(url) and url != "" -> Map.put(base, :voice_id, url)
      _ -> base
    end
  end

  @spec handle_success(struct(), struct(), String.t(), map()) :: {:ok, map()}
  defp handle_success(task, character, voice_id, result) do
    Logger.info("[VoiceDesign] Voice created: #{voice_id} for #{character.name}")

    # Persist the custom voice ID to the character record
    Characters.update_character(character, %{
      custom_voice_url: voice_id,
      voice_id: voice_id
    })

    Helpers.update_progress(task, 95)

    {:ok,
     %{
       step: "voice_design",
       voice_id: voice_id,
       trial_audio: Map.get(result, :trial_audio),
       character_id: character.id,
       character_name: character.name
     }}
  end

  @spec handle_error(struct(), term(), term()) :: {:error, term()}
  defp handle_error(task, character_id, reason) do
    Logger.error("[VoiceDesign] Failed for character #{character_id}: #{inspect(reason)}")
    Tasks.update_task(task, %{error_message: inspect(reason)})
    {:error, reason}
  end
end
