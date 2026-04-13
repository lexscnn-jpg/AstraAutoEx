defmodule AstraAutoEx.Workers.Handlers.ImagePanel do
  @moduledoc """
  Generates panel image from storyboard description.
  Loads panel → builds prompt → calls image provider → saves imageUrl.
  Auto-triggers video+voice when all panels have images.
  """
  require Logger
  alias AstraAutoEx.Workers.Handlers.Helpers
  alias AstraAutoEx.{Production, Characters, Locations, Tasks}

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

    # Collect reference images (character appearances)
    reference_images = collect_reference_images(panel, characters)

    request = %{
      prompt: prompt,
      model: model,
      aspect_ratio: payload["aspect_ratio"] || "16:9",
      reference_images: reference_images
    }

    Helpers.update_progress(task, 40)

    case Helpers.generate_image(task.user_id, provider, request) do
      {:ok, %{status: :completed, image_url: url}} ->
        # Save to panel
        Production.update_panel(panel, %{image_url: url})
        Helpers.update_progress(task, 95)

        # Auto-trigger downstream if full-auto mode
        maybe_auto_trigger_video_voice(task, episode)

        {:ok, %{image_url: url}}

      {:ok, %{external_id: ext_id} = result} ->
        # Async task - save external_id for polling
        Tasks.update_task(task, %{external_id: ext_id, status: "processing"})
        {:ok, result}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_panel_prompt(panel, _storyboard, characters, _locations) do
    description = panel.description || ""
    shot_type = panel.shot_type || "medium shot"
    camera = panel.camera_movement || ""

    # Find character names referenced in description
    char_context =
      characters
      |> Enum.filter(fn c -> String.contains?(description, c.name || "") end)
      |> Enum.map(fn c -> "#{c.name}: #{c.description || ""}" end)
      |> Enum.join("; ")

    parts =
      [
        "[Shot] #{shot_type}#{if camera != "", do: ", #{camera}", else: ""}",
        "[Scene] #{description}",
        if(char_context != "", do: "[Characters] #{char_context}", else: nil)
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join("\n")

    parts
  end

  defp collect_reference_images(panel, characters) do
    # Get character appearance images referenced in this panel
    char_names = panel.characters || []

    characters
    |> Enum.filter(fn c -> c.name in char_names end)
    |> Enum.flat_map(fn c ->
      case Characters.list_appearances(c.id) do
        [%{image_url: url} | _] when is_binary(url) and url != "" -> [url]
        _ -> []
      end
    end)
    |> Enum.take(4)
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

  def execute(task) do
    payload = task.payload || %{}
    appearance_id = payload["appearance_id"] || task.target_id

    Helpers.update_progress(task, 10)

    appearance = Characters.get_appearance!(appearance_id)
    character = Characters.get_character!(appearance.character_id)

    model_config = Helpers.get_model_config(task.user_id, task.project_id, :image)
    provider = model_config["provider"]

    prompt =
      "Character portrait: #{character.name}. #{character.description || ""}. #{appearance.description || ""}"

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

  def execute(task) do
    payload = task.payload || %{}
    location_id = payload["location_id"] || task.target_id

    Helpers.update_progress(task, 10)

    location = Locations.get_location!(location_id)

    model_config = Helpers.get_model_config(task.user_id, task.project_id, :image)
    provider = model_config["provider"]

    prompt = "Scene location: #{location.name}. #{location.description || ""}"

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
