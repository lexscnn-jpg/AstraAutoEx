defmodule AstraAutoEx.Workers.Handlers.ImagePanel do
  @moduledoc """
  Generates panel image from storyboard description.
  Loads panel → builds prompt → calls image provider → saves imageUrl.
  Auto-triggers video+voice when all panels have images.
  """
  require Logger
  alias AstraAutoEx.Workers.Handlers.Helpers
  alias AstraAutoEx.{Production, Characters, Locations, Tasks}
  alias AstraAutoEx.AI.{SceneEnhancer, ArtStyles}

  def execute(task) do
    payload = task.payload || %{}
    panel_id = payload["panel_id"] || task.target_id

    Helpers.update_progress(task, 5)

    # Load panel with storyboard context
    panel = Production.get_panel!(panel_id)
    storyboard = Production.get_storyboard!(panel.storyboard_id)
    episode = Production.get_episode!(storyboard.episode_id)

    # Load characters and locations for context
    characters = Characters.list_characters(task.project_id)
    locations = Locations.list_locations(task.project_id)

    Helpers.update_progress(task, 20)

    # Build prompt from panel description + context
    prompt = build_panel_prompt(panel, storyboard, characters, locations)

    # Get model config
    model_config = Helpers.get_model_config(task.user_id, task.project_id, :image)
    provider = model_config["provider"]
    model = model_config["model"]

    # Collect reference images (character + location appearances + user uploads)
    reference_images = collect_reference_images(panel, characters, task.project_id)

    # Merge user-uploaded reference images from payload
    user_refs = payload["user_ref_images"] || []
    all_refs = (reference_images ++ user_refs) |> Enum.take(5)

    # Append user ref prompt if provided
    ref_prompt_suffix = payload["ref_prompt"] || ""

    final_prompt =
      if ref_prompt_suffix != "",
        do: prompt <> "\n[Reference Style] #{ref_prompt_suffix}",
        else: prompt

    candidate_count = payload["candidate_count"] || 1

    # Build subject_reference for MiniMax consistency (first ref image as reference)
    subject_ref =
      case all_refs do
        [first_url | _] when is_binary(first_url) and first_url != "" ->
          [%{"type" => "image_url", "image_url" => %{"url" => first_url}}]

        _ ->
          nil
      end

    request = %{
      prompt: final_prompt,
      model: model,
      aspect_ratio: payload["aspect_ratio"] || "16:9",
      reference_images: all_refs,
      subject_reference: subject_ref
    }

    Helpers.update_progress(task, 40)

    if candidate_count > 1 do
      # Multi-candidate mode: generate N images, store all as candidates
      results =
        1..candidate_count
        |> Enum.map(fn _i ->
          Helpers.generate_image(task.user_id, provider, request)
        end)

      urls =
        results
        |> Enum.flat_map(fn
          {:ok, %{status: :completed, image_urls: urls}} -> urls
          {:ok, %{status: :completed, image_url: url}} when is_binary(url) -> [url]
          _ -> []
        end)

      if length(urls) > 0 do
        # First candidate becomes the main image
        Production.update_panel(panel, %{
          image_url: hd(urls),
          candidate_images: %{"urls" => urls, "selected" => 0}
        })

        Helpers.update_progress(task, 95)
        maybe_auto_trigger_video_voice(task, episode)
        {:ok, %{image_urls: urls, candidate_count: length(urls)}}
      else
        {:error, "All candidate generations failed"}
      end
    else
      # Single image mode (default)
      case Helpers.generate_image(task.user_id, provider, request) do
        {:ok, %{status: :completed, image_urls: [url | _]}} ->
          Production.update_panel(panel, %{image_url: url})
          Helpers.update_progress(task, 95)
          maybe_auto_trigger_video_voice(task, episode)
          {:ok, %{image_url: url}}

        {:ok, %{status: :completed, image_url: url}} when is_binary(url) ->
          Production.update_panel(panel, %{image_url: url})
          Helpers.update_progress(task, 95)
          maybe_auto_trigger_video_voice(task, episode)
          {:ok, %{image_url: url}}

        {:ok, %{external_id: ext_id} = result} ->
          Tasks.update_task(task, %{external_id: ext_id, status: "processing"})
          {:ok, result}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp build_panel_prompt(panel, storyboard, characters, _locations) do
    description = panel.description || ""
    shot_type = panel.shot_type || "medium shot"
    camera = panel.camera_move || ""

    # Find character names referenced in description
    char_context =
      characters
      |> Enum.filter(fn c -> String.contains?(description, c.name || "") end)
      |> Enum.map(fn c -> "#{c.name}: #{c.introduction || ""}" end)
      |> Enum.join("; ")

    # Get art style prompt from project settings
    art_style = storyboard.image_history && storyboard.image_history["art_style"]
    style_suffix = if art_style, do: ArtStyles.get_prompt(art_style), else: ""

    # Infer scene type from shot_type for camera enhancement
    scene_type = infer_scene_type(shot_type)

    parts =
      [
        "[Shot] #{shot_type}#{if camera != "", do: ", #{camera}", else: ""}",
        "[Scene] #{description}",
        if(char_context != "", do: "[Characters] #{char_context}", else: nil),
        # Scene enhancer: inject camera style based on scene_type
        SceneEnhancer.enhance_image_prompt("", scene_type) |> String.trim(),
        # Art style suffix
        if(style_suffix != "", do: "[Style] #{style_suffix}", else: nil)
      ]
      |> Enum.reject(&(&1 == nil or &1 == ""))
      |> Enum.join("\n")

    parts
  end

  defp infer_scene_type(shot_type) do
    cond do
      shot_type in ~w(close_up extreme_close_up) -> "emotion"
      shot_type in ~w(full wide extreme_wide) -> "epic"
      shot_type in ~w(pov dutch_angle) -> "suspense"
      true -> "daily"
    end
  end

  defp collect_reference_images(panel, characters, project_id) do
    # Parse character names from panel's characters field (string, comma-separated)
    char_names_str = panel.characters || ""

    char_names =
      char_names_str
      |> String.split(~r/[,;，、]/)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    # Also check description for character name mentions
    description = panel.description || ""

    # Match characters using alias-aware matching
    matched_chars =
      char_names
      |> Enum.map(fn name -> find_character_by_name(characters, name) end)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq_by(& &1.id)

    # Also match characters whose name appears directly in description
    desc_matches =
      characters
      |> Enum.filter(fn c ->
        name = c.name || ""
        name != "" and String.contains?(description, name)
      end)

    matched_chars = Enum.uniq_by(matched_chars ++ desc_matches, & &1.id)

    # Collect appearance images from matched characters
    char_images =
      matched_chars
      |> Enum.flat_map(fn c ->
        case Characters.list_appearances(c.id) do
          appearances when is_list(appearances) ->
            appearances
            |> Enum.filter(fn a -> a.image_url && a.image_url != "" end)
            |> Enum.map(& &1.image_url)
            |> Enum.take(1)

          _ ->
            []
        end
      end)

    # Also collect location reference images if available
    location_name = panel.location || ""

    location_images =
      if location_name != "" do
        Locations.list_locations_by_name(project_id, location_name)
        |> Enum.flat_map(fn loc ->
          (loc.images || [])
          |> Enum.filter(fn img -> img.image_url && img.image_url != "" end)
          |> Enum.take(1)
          |> Enum.map(& &1.image_url)
        end)
        |> Enum.take(1)
      else
        []
      end

    (char_images ++ location_images) |> Enum.take(4)
  end

  # Find a character by name with alias "/" splitting and case-insensitive matching.
  defp find_character_by_name(characters, name) do
    # 1. Exact match
    exact = Enum.find(characters, &(&1.name == name))

    if exact do
      exact
    else
      # 2. Alias "/" split match (case-insensitive)
      Enum.find(characters, fn char ->
        aliases =
          (char.name || "")
          |> String.split("/")
          |> Enum.map(&String.trim/1)
          |> Enum.map(&String.downcase/1)

        String.downcase(name || "") in aliases
      end)
    end
  end

  defp maybe_auto_trigger_video_voice(task, episode) do
    payload = task.payload || %{}

    if payload["full_auto_chain"] do
      # Check if all panels in episode have images
      storyboards = Production.list_storyboards(episode.id)
      all_panels = Enum.flat_map(storyboards, fn sb -> Production.list_panels(sb.id) end)
      all_have_images = Enum.all?(all_panels, fn p -> p.image_url && p.image_url != "" end)

      if all_have_images do
        Logger.info("[ImagePanel] All panels have images, auto-triggering video+voice")
        # Queue video + voice tasks for each panel
        Enum.each(all_panels, fn panel ->
          Tasks.create_task(%{
            user_id: task.user_id,
            project_id: task.project_id,
            episode_id: episode.id,
            type: "video_panel",
            target_type: "panel",
            target_id: panel.id,
            payload: %{"panel_id" => panel.id, "full_auto_chain" => true}
          })
        end)
      end
    end
  end
end

defmodule AstraAutoEx.Workers.Handlers.ImageCharacter do
  @moduledoc "Generates character appearance image."
  alias AstraAutoEx.Workers.Handlers.Helpers
  alias AstraAutoEx.Characters
  alias AstraAutoEx.AI.PromptCatalog

  def execute(task) do
    payload = task.payload || %{}
    appearance_id = payload["appearance_id"] || task.target_id

    Helpers.update_progress(task, 10)

    appearance = Characters.get_appearance!(appearance_id)
    character = Characters.get_character!(appearance.character_id)

    model_config = Helpers.get_model_config(task.user_id, task.project_id, :image)
    provider = model_config["provider"]

    base_prompt =
      "Character portrait: #{character.name}. #{character.introduction || ""}. #{appearance.description || ""}"

    # Append character prompt suffix for three-view sheet generation
    suffix = PromptCatalog.character_prompt_suffix()

    prompt =
      if suffix != "" do
        "#{base_prompt}\uFF0C#{suffix}"
      else
        base_prompt
      end

    # Get primary appearance for reference (style consistency)
    reference_images =
      case Characters.list_appearances(character.id) do
        [primary | _] when primary.id != appearance_id and is_binary(primary.image_url) ->
          [primary.image_url]

        _ ->
          []
      end

    request = %{
      prompt: prompt,
      model: model_config["model"],
      aspect_ratio: payload["aspect_ratio"] || "3:4",
      reference_images: reference_images
    }

    Helpers.update_progress(task, 40)

    case Helpers.generate_image(task.user_id, provider, request) do
      {:ok, %{status: :completed, image_url: url}} ->
        Characters.update_appearance(appearance, %{image_url: url})
        {:ok, %{image_url: url}}

      {:ok, %{external_id: _} = result} ->
        {:ok, result}

      {:error, reason} ->
        {:error, reason}
    end
  end
end

defmodule AstraAutoEx.Workers.Handlers.ImageLocation do
  @moduledoc "Generates location/prop image."
  alias AstraAutoEx.Workers.Handlers.Helpers
  alias AstraAutoEx.Locations
  alias AstraAutoEx.AI.PromptCatalog

  def execute(task) do
    payload = task.payload || %{}
    location_id = payload["location_id"] || task.target_id

    Helpers.update_progress(task, 10)

    location = Locations.get_location!(location_id)

    model_config = Helpers.get_model_config(task.user_id, task.project_id, :image)
    provider = model_config["provider"]

    base_prompt = "Scene location: #{location.name}. #{location.description || ""}"

    # Append location prompt suffix (currently empty, but ready for future use)
    suffix = PromptCatalog.location_prompt_suffix()

    prompt =
      if suffix != "" do
        "#{base_prompt}\uFF0C#{suffix}"
      else
        base_prompt
      end

    request = %{
      prompt: prompt,
      model: model_config["model"],
      aspect_ratio: payload["aspect_ratio"] || "16:9"
    }

    Helpers.update_progress(task, 40)

    case Helpers.generate_image(task.user_id, provider, request) do
      {:ok, %{status: :completed, image_url: url}} ->
        Locations.update_location(location, %{image_url: url})
        {:ok, %{image_url: url}}

      {:ok, %{external_id: _} = result} ->
        {:ok, result}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
