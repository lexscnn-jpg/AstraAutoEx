defmodule AstraAutoEx.Workers.Handlers.VideoPanel do
  @moduledoc """
  Generates video from panel image + prompt.
  Loads panel → fetches image → builds video prompt → calls provider.
  Auto-triggers compose when all panels have video.
  """
  require Logger
  alias AstraAutoEx.Workers.Handlers.Helpers
  alias AstraAutoEx.{Production, Tasks}
  alias AstraAutoEx.AI.SceneEnhancer

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

    # First-Last Frame mode: use next panel's image as last frame
    request =
      cond do
        payload["last_frame_image_url"] ->
          Map.put(request, :last_frame_image_url, payload["last_frame_image_url"])

        payload["fl_mode"] && payload["next_panel_id"] ->
          next_panel = Production.get_panel!(payload["next_panel_id"])

          if next_panel.image_url && next_panel.image_url != "" do
            # Optionally rewrite prompt with LLM for smoother transition
            fl_prompt =
              if payload["custom_prompt"] && payload["custom_prompt"] != "" do
                payload["custom_prompt"]
              else
                case AstraAutoEx.AI.FlPromptRewriter.rewrite(
                       task.user_id,
                       panel,
                       next_panel,
                       prompt,
                       "default"
                     ) do
                  {:ok, rewritten} -> rewritten
                  _ -> prompt
                end
              end

            request
            |> Map.put(:last_frame_image_url, next_panel.image_url)
            |> Map.put(:prompt, fl_prompt)
          else
            request
          end

        true ->
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
    base_description = panel.description || ""

    parts =
      [
        if(panel.shot_type, do: "[镜头] #{panel.shot_type}", else: nil),
        if(panel.camera_move, do: "#{panel.camera_move}", else: nil),
        "[视频描述] #{base_description}"
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join("\n")

    # Enhance with camera style + action tags (default to "daily" scene type)
    SceneEnhancer.enhance_video_prompt(parts, "daily", base_description)
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
  @moduledoc """
  Lip sync handler — overlays voice audio onto panel video.

  Loads panel video_url + voice_line audio_url → submits to lip sync provider
  (FAL Kling / Vidu / Bailian) → stores result as lip_sync_video_url on panel.
  """
  require Logger
  alias AstraAutoEx.Workers.Handlers.Helpers
  alias AstraAutoEx.{Production, Tasks}
  alias AstraAutoEx.AI.LipSync, as: LipSyncAI

  def execute(task) do
    payload = task.payload || %{}
    panel_id = payload["panel_id"] || task.target_id

    Helpers.update_progress(task, 5)

    panel = Production.get_panel!(panel_id)

    # Resolve video and audio URLs
    video_url = payload["video_url"] || panel.video_url
    audio_url = payload["audio_url"] || panel.audio_url

    unless video_url && video_url != "" do
      {:error, "Panel has no video. Generate video first."}
    end

    unless audio_url && audio_url != "" do
      {:error, "No audio available. Generate voice first."}
    end

    Helpers.update_progress(task, 20)

    # Resolve lip sync model from user preferences or payload
    model_key =
      payload["lip_sync_model"] ||
        get_lip_sync_model(task.user_id, task.project_id)

    params = %{
      video_url: video_url,
      audio_url: audio_url,
      model_key: model_key
    }

    Helpers.update_progress(task, 40)

    case LipSyncAI.submit(task.user_id, params) do
      {:ok, %{external_id: ext_id} = result} ->
        # Async task — store external_id for polling
        Tasks.update_task(task, %{external_id: ext_id, status: "processing"})
        Logger.info("[LipSync] Task submitted: #{ext_id} for panel #{panel_id}")
        {:ok, result}

      {:ok, %{video_url: url}} ->
        # Synchronous result (unlikely but handle it)
        Production.update_panel(panel, %{lip_sync_video_url: url})
        Helpers.update_progress(task, 95)
        {:ok, %{video_url: url, lip_synced: true}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_lip_sync_model(user_id, _project_id) do
    case AstraAutoEx.Accounts.get_user_preference(user_id) do
      %{model_selections: selections} when is_map(selections) ->
        Map.get(selections, "lipsync") ||
          "fal::fal-ai/kling-video/lipsync/audio-to-video"

      _ ->
        "fal::fal-ai/kling-video/lipsync/audio-to-video"
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

      # Build compose options from payload
      subtitle_mode = payload["subtitle_mode"] || "none"
      _bgm_mode = payload["bgm"] || "none"

      compose_opts = [
        transition: payload["transition"] || "crossfade",
        transition_ms: String.to_integer(payload["transition_ms"] || "500")
      ]

      # Generate subtitles if requested
      compose_opts =
        if subtitle_mode != "none" do
          case AstraAutoEx.Media.SubtitleGenerator.generate_for_episode(episode_id) do
            {:ok, srt_path} -> Keyword.put(compose_opts, :subtitle_path, srt_path)
            _ -> compose_opts
          end
        else
          compose_opts
        end

      Helpers.update_progress(task, 50)

      # Attempt real FFmpeg compose
      upload_dir = Application.get_env(:astra_auto_ex, :upload_dir, "priv/uploads")
      output_dir = Path.join(upload_dir, "compose")
      File.mkdir_p!(output_dir)
      output_path = Path.join(output_dir, "#{storage_key}.mp4")

      clips = Enum.map(panel_videos, fn p -> %{video_url: p.video_url, duration: p.duration} end)

      compose_result =
        case AstraAutoEx.Media.FFmpeg.compose(clips, output_path, compose_opts) do
          {:ok, _path} ->
            # Real FFmpeg compose succeeded
            Logger.info("[VideoCompose] FFmpeg compose succeeded: #{output_path}")

            %{
              episode_id: episode_id,
              panel_count: length(panel_videos),
              total_duration: Enum.reduce(panel_videos, 0, fn p, acc -> acc + p.duration end),
              output_path: output_path,
              storage_key: storage_key,
              status: "composed"
            }

          {:error, reason} ->
            # FFmpeg not available or failed — store metadata only
            Logger.warning(
              "[VideoCompose] FFmpeg unavailable: #{inspect(reason)}, storing metadata"
            )

            %{
              episode_id: episode_id,
              panel_count: length(panel_videos),
              total_duration: Enum.reduce(panel_videos, 0, fn p, acc -> acc + p.duration end),
              panels: panel_videos,
              storage_key: storage_key,
              status: "metadata_only",
              error: inspect(reason)
            }
        end

      # Save compose result to media
      Media.upsert_media_object(%{
        project_id: task.project_id,
        storage_key: storage_key,
        media_type: "video",
        content_type: "video/mp4",
        metadata: compose_result
      })

      # Update episode compose status
      Production.update_episode(episode, %{
        compose_status: compose_result.status,
        composed_video_key: storage_key
      })

      Helpers.update_progress(task, 95)
      {:ok, compose_result}
    end
  end
end
