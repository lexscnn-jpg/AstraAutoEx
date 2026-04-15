defmodule AstraAutoEx.Workers.AutoChain do
  @moduledoc """
  Unified auto-chain trigger — called after a task completes to
  automatically kick off the next pipeline step.

  Four trigger points:
  1. after_story_to_script  — creates SCRIPT_TO_STORYBOARD task
  2. after_script_to_storyboard — creates IMAGE_PANEL tasks for each panel
  3. after_image_complete — triggers VIDEO + VOICE when all panels have images
  4. after_video_voice_complete — triggers VIDEO_COMPOSE when all ready

  Each trigger is guarded by:
  - auto_chain_enabled / full_auto_chain_enabled project flags
  - dedupe_key to prevent duplicate tasks
  - PubSub broadcast so the LiveView refreshes
  """

  require Logger

  import Ecto.Query

  alias AstraAutoEx.{Production, Tasks, Characters, Locations, Repo}
  alias AstraAutoEx.Production.NovelProject
  alias AstraAutoEx.Tasks.Task, as: TaskSchema

  # ---------------------------------------------------------------------------
  # 1. After Story → Script completes
  # ---------------------------------------------------------------------------

  @doc """
  Called after story_to_script completes.
  If auto_chain is enabled, creates a script_to_storyboard task.
  """
  @spec after_story_to_script(TaskSchema.t()) :: :ok
  def after_story_to_script(task) do
    with {:ok, project} <- load_novel_project(task.project_id),
         true <- auto_chain_enabled?(project),
         episode_id when not is_nil(episode_id) <- task.episode_id,
         episode <- Production.get_episode!(episode_id),
         clips <- Production.list_clips(episode.id),
         true <- length(clips) > 0,
         storyboards <- Production.list_storyboards(episode.id),
         true <- Enum.empty?(storyboards) do
      dedupe = "auto_storyboard:#{episode.id}"

      unless dedupe_exists?(dedupe) do
        Logger.info("[AutoChain] Story→Script done, triggering storyboard: episode=#{episode.id}")

        Tasks.create_task(%{
          user_id: task.user_id,
          project_id: task.project_id,
          episode_id: episode.id,
          type: "script_to_storyboard_run",
          target_type: "episode",
          target_id: episode.id,
          dedupe_key: dedupe,
          payload: %{
            "episode_id" => episode.id,
            "auto_continue" => true
          }
        })

        broadcast(task.project_id, "auto_chain.storyboard_triggered")
      end
    end

    :ok
  rescue
    e ->
      Logger.warning("[AutoChain] after_story_to_script failed: #{inspect(e)}")
      :ok
  end

  # ---------------------------------------------------------------------------
  # 2. After Script → Storyboard completes
  # ---------------------------------------------------------------------------

  @doc """
  Called after script_to_storyboard completes.
  If full_auto_chain is enabled, creates IMAGE_PANEL tasks for panels without images,
  plus IMAGE_CHARACTER and IMAGE_LOCATION tasks for assets without images.
  """
  @spec after_script_to_storyboard(TaskSchema.t()) :: :ok
  def after_script_to_storyboard(task) do
    with {:ok, project} <- load_novel_project(task.project_id),
         true <- full_auto_chain_enabled?(project),
         episode_id when not is_nil(episode_id) <- task.episode_id do
      episode = Production.get_episode!(episode_id)
      storyboards = Production.list_storyboards(episode.id)

      panels =
        storyboards
        |> Enum.flat_map(fn sb -> Production.list_panels(sb.id) end)

      # Queue image tasks for panels without images
      panels_needing_images =
        Enum.filter(panels, fn p -> is_nil(p.image_url) or p.image_url == "" end)

      if length(panels_needing_images) > 0 do
        Logger.info(
          "[AutoChain] Storyboard done, triggering #{length(panels_needing_images)} panel images"
        )

        Enum.each(panels_needing_images, fn panel ->
          dedupe = "auto_image:#{panel.id}"

          unless dedupe_exists?(dedupe) do
            Tasks.create_task(%{
              user_id: task.user_id,
              project_id: task.project_id,
              episode_id: episode.id,
              type: "image_panel",
              target_type: "panel",
              target_id: panel.id,
              dedupe_key: dedupe,
              payload: %{
                "panel_id" => panel.id,
                "full_auto_chain" => true
              }
            })
          end
        end)
      end

      # Queue character appearance images
      characters = Characters.list_characters(task.project_id)

      Enum.each(characters, fn char ->
        appearances = Characters.list_appearances(char.id)

        Enum.each(appearances, fn app ->
          if is_nil(app.image_url) or app.image_url == "" do
            dedupe = "auto_char_image:#{app.id}"

            unless dedupe_exists?(dedupe) do
              Tasks.create_task(%{
                user_id: task.user_id,
                project_id: task.project_id,
                episode_id: episode.id,
                type: "image_character",
                target_type: "character_appearance",
                target_id: app.id,
                dedupe_key: dedupe,
                payload: %{
                  "appearance_id" => app.id,
                  "full_auto_chain" => true
                }
              })
            end
          end
        end)
      end)

      # Queue location images
      locations = Locations.list_locations(task.project_id)

      Enum.each(locations, fn loc ->
        images = loc.images || []
        has_image = Enum.any?(images, fn img -> img.image_url && img.image_url != "" end)

        unless has_image do
          dedupe = "auto_loc_image:#{loc.id}"

          unless dedupe_exists?(dedupe) do
            Tasks.create_task(%{
              user_id: task.user_id,
              project_id: task.project_id,
              episode_id: episode.id,
              type: "image_location",
              target_type: "location",
              target_id: loc.id,
              dedupe_key: dedupe,
              payload: %{
                "location_id" => loc.id,
                "full_auto_chain" => true
              }
            })
          end
        end
      end)

      broadcast(task.project_id, "auto_chain.images_triggered")
    end

    :ok
  rescue
    e ->
      Logger.warning("[AutoChain] after_script_to_storyboard failed: #{inspect(e)}")
      :ok
  end

  # ---------------------------------------------------------------------------
  # 3. After a single image task completes
  # ---------------------------------------------------------------------------

  @doc """
  Called after any image task completes.
  Checks if ALL panels in the episode now have images.
  If so and full_auto_chain is enabled, triggers video + voice in parallel.
  """
  @spec after_image_complete(TaskSchema.t()) :: :ok
  def after_image_complete(task) do
    with {:ok, project} <- load_novel_project(task.project_id),
         true <- full_auto_chain_enabled?(project),
         episode_id when not is_nil(episode_id) <- task.episode_id do
      episode = Production.get_episode!(episode_id)
      storyboards = Production.list_storyboards(episode.id)

      all_panels =
        Enum.flat_map(storyboards, fn sb -> Production.list_panels(sb.id) end)

      all_have_images =
        Enum.all?(all_panels, fn p -> p.image_url && p.image_url != "" end)

      if all_have_images and length(all_panels) > 0 do
        Logger.info(
          "[AutoChain] All #{length(all_panels)} panels have images, triggering video+voice"
        )

        # Trigger video for panels without video_url
        panels_needing_video =
          Enum.filter(all_panels, fn p -> is_nil(p.video_url) or p.video_url == "" end)

        Enum.each(panels_needing_video, fn panel ->
          dedupe = "auto_video:#{panel.id}"

          unless dedupe_exists?(dedupe) do
            Tasks.create_task(%{
              user_id: task.user_id,
              project_id: task.project_id,
              episode_id: episode.id,
              type: "video_panel",
              target_type: "panel",
              target_id: panel.id,
              dedupe_key: dedupe,
              payload: %{
                "panel_id" => panel.id,
                "full_auto_chain" => true
              }
            })
          end
        end)

        # Trigger voice for voice_lines without audio_url
        voice_lines = Production.list_voice_lines(episode.id)

        lines_needing_audio =
          Enum.filter(voice_lines, fn vl -> is_nil(vl.audio_url) or vl.audio_url == "" end)

        Enum.each(lines_needing_audio, fn vl ->
          dedupe = "auto_voice:#{vl.id}"

          unless dedupe_exists?(dedupe) do
            Tasks.create_task(%{
              user_id: task.user_id,
              project_id: task.project_id,
              episode_id: episode.id,
              type: "voice_line",
              target_type: "voice_line",
              target_id: vl.id,
              dedupe_key: dedupe,
              payload: %{
                "voice_line_id" => vl.id,
                "full_auto_chain" => true
              }
            })
          end
        end)

        broadcast(task.project_id, "auto_chain.video_voice_triggered")
      end
    end

    :ok
  rescue
    e ->
      Logger.warning("[AutoChain] after_image_complete failed: #{inspect(e)}")
      :ok
  end

  # ---------------------------------------------------------------------------
  # 4. After video or voice task completes
  # ---------------------------------------------------------------------------

  @doc """
  Called after a video_panel or voice_line task completes.
  Checks 4 conditions for auto-compose:
  1. All panels have video_url
  2. At least 1 voice_line has audio_url
  3. No compose task in progress
  4. Episode not already composed
  """
  @spec after_video_voice_complete(TaskSchema.t()) :: :ok
  def after_video_voice_complete(task) do
    with episode_id when not is_nil(episode_id) <- task.episode_id do
      episode = Production.get_episode!(episode_id)
      storyboards = Production.list_storyboards(episode.id)

      all_panels =
        Enum.flat_map(storyboards, fn sb -> Production.list_panels(sb.id) end)

      voice_lines = Production.list_voice_lines(episode.id)

      # Condition 1: All panels have video
      all_have_video =
        length(all_panels) > 0 and
          Enum.all?(all_panels, fn p -> p.video_url && p.video_url != "" end)

      # Condition 2: At least 1 voice line has audio
      has_voice = Enum.any?(voice_lines, fn vl -> vl.audio_url && vl.audio_url != "" end)

      # Condition 3: No compose in progress (check dedupe)
      compose_dedupe = "auto_compose:#{episode.id}"
      compose_in_progress = dedupe_exists?(compose_dedupe)

      # Condition 4: Not already composed
      compose_status = Map.get(episode, :compose_status)
      already_composed = compose_status == "completed"

      if all_have_video and has_voice and not compose_in_progress and not already_composed do
        Logger.info(
          "[AutoChain] All conditions met, auto-triggering compose: episode=#{episode.id}"
        )

        Tasks.create_task(%{
          user_id: task.user_id,
          project_id: task.project_id,
          episode_id: episode.id,
          type: "video_compose",
          target_type: "episode",
          target_id: episode.id,
          dedupe_key: compose_dedupe,
          payload: %{
            "episode_id" => episode.id
          }
        })

        broadcast(task.project_id, "auto_chain.compose_triggered")
      end
    end

    :ok
  rescue
    e ->
      Logger.warning("[AutoChain] after_video_voice_complete failed: #{inspect(e)}")
      :ok
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp load_novel_project(project_id) do
    case Production.get_novel_project(project_id) do
      nil -> {:error, :no_novel_project}
      np -> {:ok, np}
    end
  end

  defp auto_chain_enabled?(%NovelProject{} = np) do
    np.auto_chain_enabled == true or np.full_auto_chain_enabled == true
  end

  defp full_auto_chain_enabled?(%NovelProject{} = np) do
    np.full_auto_chain_enabled == true
  end

  # Check if an active (non-terminal) task with this dedupe_key exists
  defp dedupe_exists?(dedupe_key) do
    count =
      from(t in TaskSchema,
        where: t.dedupe_key == ^dedupe_key and t.status in ["queued", "processing"]
      )
      |> Repo.aggregate(:count)

    count > 0
  end

  defp broadcast(project_id, event) do
    Phoenix.PubSub.broadcast(
      AstraAutoEx.PubSub,
      "project:#{project_id}",
      {:auto_chain_event, %{event: event}}
    )
  end
end
