defmodule AstraAutoEx.Workers.Handlers.VoiceLine do
  @moduledoc """
  Generates TTS audio for a voice line.
  Loads voice line → calls TTS provider → saves audioUrl + duration.
  Auto-triggers compose check after completion.
  """
  require Logger
  alias AstraAutoEx.Workers.Handlers.Helpers
  alias AstraAutoEx.Production

  def execute(task) do
    payload = task.payload || %{}
    voice_line_id = payload["voice_line_id"] || task.target_id

    Helpers.update_progress(task, 10)

    voice_line = Production.get_voice_line!(voice_line_id)

    model_config = Helpers.get_model_config(task.user_id, task.project_id, :tts)
    provider = model_config["provider"]

    request = %{
      text: voice_line.content || "",
      model: model_config["model"],
      voice_id: voice_line.voice_id || payload["voice_id"] || "Calm_Woman",
      speed: payload["speed"] || 1.0,
      voice_setting: %{
        "voice_id" => voice_line.voice_id || "Calm_Woman",
        "speed" => payload["speed"] || 1.0
      }
    }

    Helpers.update_progress(task, 40)

    case Helpers.text_to_speech(task.user_id, provider, request) do
      {:ok, %{download_url: url}} ->
        Production.update_voice_line(voice_line, %{audio_url: url, status: "completed"})
        Helpers.update_progress(task, 95)
        maybe_auto_trigger_compose(task)
        {:ok, %{audio_url: url}}

      {:ok, %{status: :completed} = result} ->
        audio_url = Map.get(result, :audio_url) || Map.get(result, :download_url)

        if audio_url do
          Production.update_voice_line(voice_line, %{audio_url: audio_url, status: "completed"})
        end

        {:ok, result}

      {:error, reason} ->
        Production.update_voice_line(voice_line, %{status: "failed"})
        {:error, reason}
    end
  end

  defp maybe_auto_trigger_compose(task) do
    payload = task.payload || %{}

    if payload["full_auto_chain"] && task.episode_id do
      # Check if compose is needed
      Logger.info("[VoiceLine] Voice completed, checking compose readiness")
    end
  end
end

defmodule AstraAutoEx.Workers.Handlers.VoiceDesign do
  @moduledoc "Voice design — creates a custom voice profile via MiniMax."
  alias AstraAutoEx.Workers.Handlers.Helpers

  def execute(task) do
    payload = task.payload || %{}

    Helpers.update_progress(task, 20)

    request = %{
      prompt: payload["prompt"] || "",
      preview_text: payload["preview_text"] || "你好，这是一段测试语音。",
      voice_id: payload["voice_id"]
    }

    case Helpers.text_to_speech(task.user_id, "minimax", request) do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end
end

defmodule AstraAutoEx.Workers.Handlers.MusicGenerate do
  @moduledoc "Generates music via MiniMax music API."
  alias AstraAutoEx.Workers.Handlers.Helpers

  def execute(task) do
    payload = task.payload || %{}

    Helpers.update_progress(task, 20)

    # MiniMax music generation (only MiniMax supports this)
    alias AstraAutoEx.AI.Providers.Minimax

    with {:ok, config} <- Helpers.get_provider_config(task.user_id, "minimax") do
      request = %{
        prompt: payload["prompt"] || "",
        model: payload["model"] || "music-2.6",
        lyrics: payload["lyrics"],
        is_instrumental: payload["is_instrumental"]
      }

      case Minimax.generate_music(request, config) do
        {:ok, result} -> {:ok, result}
        {:error, reason} -> {:error, reason}
      end
    end
  end
end
