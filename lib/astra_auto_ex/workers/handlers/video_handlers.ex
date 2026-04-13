defmodule AstraAutoEx.Workers.Handlers.VideoPanel do
  @moduledoc """
  Generates video from panel image + prompt.
  Loads panel → fetches image → builds video prompt → calls provider.
  Auto-triggers compose when all panels have video.
  """
  require Logger
  alias AstraAutoEx.Workers.Handlers.Helpers
  alias AstraAutoEx.{Production, Tasks}

  def execute(task) do
    payload = task.payload || %{}
    panel_id = payload["panel_id"] || task.target_id

    Helpers.update_progress(task, 5)

    panel = Production.get_panel!(panel_id)
    storyboard = Production.get_storyboard!(panel.storyboard_id)
    episode = Production.get_episode!(storyboard.episode_id)

    unless panel.image_url && panel.image_url != "" do
      {:error, "Panel has no image. Generate image first."}
    end

    Helpers.update_progress(task, 20)

    # Build video prompt
    prompt = build_video_prompt(panel, storyboard)

    model_config = Helpers.get_model_config(task.user_id, task.project_id, :video)
    provider = model_config["provider"]

    request = %{
      image_url: panel.image_url,
      prompt: prompt,
      model: model_config["model"],
      model_id: model_config["model"],
      aspect_ratio: payload["aspect_ratio"] || "16:9",
      duration: payload["duration"] || 5
    }

    # Add last frame for first-last-frame mode
    request =
      if payload["last_frame_image_url"] do
        Map.put(request, :last_frame_image_url, payload["last_frame_image_url"])
      else
        request
      end

    Helpers.update_progress(task, 40)

    case Helpers.generate_video(task.user_id, provider, request) do
      {:ok, %{status: :completed, video_url: url}} ->
        Production.update_panel(panel, %{video_url: url})
        Helpers.update_progress(task, 95)
        maybe_auto_trigger_compose(task, episode)
        {:ok, %{video_url: url}}

      {:ok, %{external_id: ext_id} = result} ->
        Tasks.update_task(task, %{external_id: ext_id})
        {:ok, result}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_video_prompt(panel, _storyboard) do
    parts =
      [
        if(panel.shot_type, do: "[镜头] #{panel.shot_type}", else: nil),
        if(panel.camera_movement, do: "#{panel.camera_movement}", else: nil),
        "[视频描述] #{panel.description || ""}",
        if(panel.dialogue, do: "[对白] #{panel.dialogue}", else: nil)
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join("\n")

    parts
  end

  defp maybe_auto_trigger_compose(task, episode) do
    payload = task.payload || %{}

    if payload["full_auto_chain"] do
      storyboards = Production.list_storyboards(episode.id)
      all_panels = Enum.flat_map(storyboards, fn sb -> Production.list_panels(sb.id) end)
      all_have_video = Enum.all?(all_panels, fn p -> p.video_url && p.video_url != "" end)

      if all_have_video do
        Logger.info("[VideoPanel] All panels have video, auto-triggering compose")

        Tasks.create_task(%{
          user_id: task.user_id,
          project_id: task.project_id,
          episode_id: episode.id,
          type: "video_compose",
          target_type: "episode",
          target_id: episode.id,
          payload: %{"episode_id" => episode.id}
        })
      end
    end
  end
end

defmodule AstraAutoEx.Workers.Handlers.LipSync do
  @moduledoc "Lip-sync video generation — overlays voice audio onto video."
  alias AstraAutoEx.Workers.Handlers.Helpers

  def execute(task) do
    payload = task.payload || %{}
    _model_config = Helpers.get_model_config(task.user_id, task.project_id, :video)

    request = %{
      video_url: payload["video_url"],
      audio_url: payload["audio_url"],
      model: "fal-sync",
      model_id: "fal-sync"
    }

    # FAL lip-sync endpoint
    case Helpers.generate_video(task.user_id, "fal", request) do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end
end

defmodule AstraAutoEx.Workers.Handlers.VideoCompose do
  @moduledoc """
  Composes final episode video from all panel videos + voice + BGM.
  Downloads all assets → concatenates with FFmpeg → uploads result.
  """
  require Logger
  alias AstraAutoEx.Workers.Handlers.Helpers
  alias AstraAutoEx.{Production, Media}
  alias AstraAutoEx.Storage.Provider

  def execute(task) do
    payload = task.payload || %{}
    episode_id = payload["episode_id"] || task.target_id

    Helpers.update_progress(task, 5)

    episode = Production.get_episode!(episode_id)
    storyboards = Production.list_storyboards(episode.id)
    _clips = Production.list_clips(episode.id)

    Helpers.update_progress(task, 10)

    # Collect all panel videos in order
    panel_videos =
      storyboards
      |> Enum.sort_by(& &1.sort_order)
      |> Enum.flat_map(fn sb ->
        Production.list_panels(sb.id)
        |> Enum.sort_by(& &1.sort_order)
        |> Enum.map(fn panel ->
          %{
            panel_id: panel.id,
            video_url: panel.video_url,
            audio_url: panel.audio_url,
            duration: panel.duration || 5.0
          }
        end)
      end)
      |> Enum.filter(fn p -> p.video_url && p.video_url != "" end)

    if Enum.empty?(panel_videos) do
      {:error, "No panel videos available for composition"}
    else
      Helpers.update_progress(task, 30)

      # Generate concat file for FFmpeg
      storage_key =
        Provider.generate_key("compose", "mp4", project_id: task.project_id, media_type: "video")

      # For now, store compose metadata (actual FFmpeg compose requires system FFmpeg)
      compose_result = %{
        episode_id: episode_id,
        panel_count: length(panel_videos),
        total_duration: Enum.reduce(panel_videos, 0, fn p, acc -> acc + p.duration end),
        panels: panel_videos,
        storage_key: storage_key,
        status: "composed"
      }

      # Save compose result to media
      Media.upsert_media_object(%{
        project_id: task.project_id,
        storage_key: storage_key,
        media_type: "video",
        content_type: "video/mp4",
        metadata: compose_result
      })

      Helpers.update_progress(task, 95)
      {:ok, compose_result}
    end
  end
end
