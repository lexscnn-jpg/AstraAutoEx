defmodule AstraAutoEx.Workers.Handlers.AnalyzeNovel do
  @moduledoc """
  Analyzes novel text to extract characters, locations, and props.
  Calls LLM with novel excerpt → parses JSON → creates assets.
  """
  alias AstraAutoEx.Workers.Handlers.Helpers
  alias AstraAutoEx.{Characters, Locations}

  def execute(task) do
    payload = task.payload || %{}
    novel_text = payload["novel_text"] || ""

    if String.trim(novel_text) == "" do
      {:error, "No novel text provided for analysis"}
    else
      Helpers.update_progress(task, 10)

      model_config = Helpers.get_model_config(task.user_id, task.project_id, :llm)
      provider = model_config["provider"]

      # Parallel analysis: characters + locations + props
      prompt = """
      Analyze the following novel text and extract:
      1. Characters: name, gender, age estimate, personality, physical description
      2. Locations: name, description, mood/atmosphere
      3. Props: name, description, significance

      Return as JSON: {"characters": [...], "locations": [...], "props": [...]}

      Novel text:
      #{String.slice(novel_text, 0..8000)}
      """

      request = %{
        model: model_config["model"],
        contents: [%{"parts" => [%{"text" => prompt}]}]
      }

      Helpers.update_progress(task, 40)

      case Helpers.chat(task.user_id, provider, request) do
        {:ok, text} ->
          result = parse_and_persist_analysis(text, task)
          Helpers.update_progress(task, 95)
          {:ok, result}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp parse_and_persist_analysis(text, task) do
    case extract_json(text) do
      {:ok, data} ->
        chars = Map.get(data, "characters", [])
        locs = Map.get(data, "locations", [])

        created_chars =
          Enum.map(chars, fn c ->
            {:ok, char} =
              Characters.create_character(%{
                project_id: task.project_id,
                name: Map.get(c, "name", "Unknown"),
                gender: Map.get(c, "gender"),
                age: Map.get(c, "age"),
                description: Map.get(c, "description", ""),
                personality: Map.get(c, "personality", "")
              })

            char.name
          end)

        created_locs =
          Enum.map(locs, fn l ->
            {:ok, loc} =
              Locations.create_location(%{
                project_id: task.project_id,
                name: Map.get(l, "name", "Unknown"),
                description: Map.get(l, "description", "")
              })

            loc.name
          end)

        %{characters: created_chars, locations: created_locs, raw: text}

      {:error, _} ->
        %{raw: text, parse_error: "Could not parse JSON from LLM response"}
    end
  end

  defp extract_json(text) do
    # Try to find JSON block in response
    json_str =
      case Regex.run(~r/```json\s*([\s\S]*?)```/, text) do
        [_, json] ->
          json

        nil ->
          case Regex.run(~r/\{[\s\S]*\}/, text) do
            [json] -> json
            nil -> text
          end
      end

    Jason.decode(String.trim(json_str))
  end
end

defmodule AstraAutoEx.Workers.Handlers.StoryToScript do
  @moduledoc """
  Orchestrates story-to-script pipeline:
  analyze characters → analyze locations → split clips → screenplay convert.
  """
  alias AstraAutoEx.Workers.Handlers.Helpers
  alias AstraAutoEx.{Production, Characters, Locations, Tasks}

  def execute(task) do
    payload = task.payload || %{}
    episode_id = payload["episode_id"] || task.episode_id

    Helpers.update_progress(task, 5)

    episode = Production.get_episode!(episode_id)
    novel_text = payload["novel_text"] || episode.novel_text || ""

    if String.trim(novel_text) == "" do
      {:error, "No novel text for script conversion"}
    else
      model_config = Helpers.get_model_config(task.user_id, task.project_id, :llm)
      provider = model_config["provider"]

      # Step 1: Character analysis
      Helpers.update_progress(task, 15)

      char_result =
        analyze_step(
          task.user_id,
          provider,
          model_config["model"],
          novel_text,
          "Extract all characters with their descriptions, personality, and appearance from the text. Return JSON array."
        )

      # Step 2: Location analysis
      Helpers.update_progress(task, 30)

      loc_result =
        analyze_step(
          task.user_id,
          provider,
          model_config["model"],
          novel_text,
          "Extract all locations/scenes with descriptions and mood. Return JSON array."
        )

      # Step 3: Clip splitting
      Helpers.update_progress(task, 50)

      clips_result =
        analyze_step(
          task.user_id,
          provider,
          model_config["model"],
          novel_text,
          "Split the story into sequential clips (scenes). Each clip should have: title, summary, characters involved, location, dialogue excerpts. Return JSON array."
        )

      # Step 4: Screenplay conversion
      Helpers.update_progress(task, 70)

      screenplay =
        analyze_step(
          task.user_id,
          provider,
          model_config["model"],
          novel_text,
          "Convert each clip into a screenplay format with: shot descriptions, camera angles, character actions, dialogue, and visual notes. Return JSON array of clips with panels."
        )

      # Persist results
      Helpers.update_progress(task, 85)
      persist_script_results(task, episode, screenplay)

      Helpers.update_progress(task, 95)

      # Auto-trigger storyboard
      if payload["auto_continue"] do
        Tasks.create_task(%{
          user_id: task.user_id,
          project_id: task.project_id,
          episode_id: episode_id,
          type: "script_to_storyboard_run",
          target_type: "episode",
          target_id: episode_id,
          payload: %{"episode_id" => episode_id, "auto_continue" => true}
        })
      end

      {:ok, %{characters: char_result, locations: loc_result, clips: clips_result}}
    end
  end

  defp analyze_step(user_id, provider, model, text, instruction) do
    prompt = "#{instruction}\n\nText:\n#{String.slice(text, 0..6000)}"
    request = %{model: model, contents: [%{"parts" => [%{"text" => prompt}]}]}

    case Helpers.chat(user_id, provider, request) do
      {:ok, result} -> result
      {:error, _} -> nil
    end
  end

  defp persist_script_results(task, episode, screenplay) do
    # Create clips and panels from screenplay
    case extract_json(screenplay) do
      {:ok, clips} when is_list(clips) ->
        Enum.with_index(clips, fn clip_data, idx ->
          {:ok, clip} =
            Production.create_clip(%{
              episode_id: episode.id,
              project_id: task.project_id,
              title: Map.get(clip_data, "title", "Clip #{idx + 1}"),
              summary: Map.get(clip_data, "summary", ""),
              sort_order: idx
            })

          # Create storyboard for this clip
          {:ok, sb} =
            Production.create_storyboard(%{
              episode_id: episode.id,
              clip_id: clip.id,
              sort_order: idx
            })

          # Create panels
          panels = Map.get(clip_data, "panels", [])

          Enum.with_index(panels, fn panel_data, pidx ->
            Production.create_panel(%{
              storyboard_id: sb.id,
              episode_id: episode.id,
              description: Map.get(panel_data, "description", ""),
              shot_type: Map.get(panel_data, "shot_type", "medium shot"),
              camera_move: Map.get(panel_data, "camera", ""),
              characters: Map.get(panel_data, "characters", "") |> to_string_field(),
              location: Map.get(panel_data, "location", ""),
              acting_notes: Map.get(panel_data, "dialogue", ""),
              panel_index: pidx
            })
          end)
        end)

      _ ->
        :ok
    end
  end

  defp to_string_field(val) when is_list(val), do: Enum.join(val, ", ")
  defp to_string_field(val) when is_binary(val), do: val
  defp to_string_field(_), do: ""

  defp extract_json(nil), do: {:error, nil}

  defp extract_json(text) when is_binary(text) do
    json_str =
      case Regex.run(~r/```json\s*([\s\S]*?)```/, text) do
        [_, json] ->
          json

        nil ->
          case Regex.run(~r/\[[\s\S]*\]/, text) do
            [json] -> json
            nil -> text
          end
      end

    Jason.decode(String.trim(json_str))
  end

  defp extract_json(_), do: {:error, :invalid}
end

defmodule AstraAutoEx.Workers.Handlers.ScriptToStoryboard do
  @moduledoc """
  Converts script clips to detailed storyboard panels.
  Adds cinematography, acting, and visual details.
  """
  alias AstraAutoEx.Workers.Handlers.Helpers
  alias AstraAutoEx.{Production, Tasks}

  def execute(task) do
    payload = task.payload || %{}
    episode_id = payload["episode_id"] || task.episode_id

    Helpers.update_progress(task, 10)

    episode = Production.get_episode!(episode_id)
    clips = Production.list_clips(episode.id)

    if Enum.empty?(clips) do
      {:error, "No clips found. Run story-to-script first."}
    else
      model_config = Helpers.get_model_config(task.user_id, task.project_id, :llm)
      provider = model_config["provider"]

      # Process each clip's storyboard
      Enum.with_index(clips, fn clip, idx ->
        progress = 10 + div(idx * 70, max(length(clips), 1))
        Helpers.update_progress(task, progress)

        storyboards = Production.list_storyboards_by_clip(clip.id)

        Enum.each(storyboards, fn sb ->
          panels = Production.list_panels(sb.id)
          enhance_panels(task.user_id, provider, model_config["model"], panels)
        end)
      end)

      Helpers.update_progress(task, 90)

      # Auto-trigger image generation
      if payload["auto_continue"] do
        storyboards = Production.list_storyboards(episode.id)
        panels = Enum.flat_map(storyboards, &Production.list_panels(&1.id))

        Enum.each(panels, fn panel ->
          Tasks.create_task(%{
            user_id: task.user_id,
            project_id: task.project_id,
            episode_id: episode_id,
            type: "image_panel",
            target_type: "panel",
            target_id: panel.id,
            payload: %{"panel_id" => panel.id, "full_auto_chain" => payload["auto_continue"]}
          })
        end)
      end

      {:ok, %{episode_id: episode_id, clips_processed: length(clips)}}
    end
  end

  defp enhance_panels(user_id, provider, model, panels) do
    Enum.each(panels, fn panel ->
      prompt = """
      Enhance this storyboard panel with cinematography details:
      Original: #{panel.description || ""}
      Shot type: #{panel.shot_type || "medium shot"}

      Add: detailed visual description, lighting, color palette, camera movement, character expressions.
      Return JSON: {"description": "...", "shot_type": "...", "camera_movement": "...", "lighting": "...", "photography_rules": "..."}
      """

      request = %{model: model, contents: [%{"parts" => [%{"text" => prompt}]}]}

      case Helpers.chat(user_id, provider, request) do
        {:ok, text} ->
          case extract_json(text) do
            {:ok, data} ->
              Production.update_panel(panel, %{
                description: Map.get(data, "description", panel.description),
                shot_type: Map.get(data, "shot_type", panel.shot_type),
                camera_movement: Map.get(data, "camera_movement", panel.camera_movement)
              })

            _ ->
              :ok
          end

        _ ->
          :ok
      end
    end)
  end

  defp extract_json(text) do
    json_str =
      case Regex.run(~r/```json\s*([\s\S]*?)```/, text) do
        [_, json] ->
          json

        nil ->
          case Regex.run(~r/\{[\s\S]*\}/, text) do
            [json] -> json
            nil -> text
          end
      end

    Jason.decode(String.trim(json_str))
  end
end

defmodule AstraAutoEx.Workers.Handlers.ClipsBuild do
  @moduledoc "Splits story text into sequential clips (scenes)."
  alias AstraAutoEx.Workers.Handlers.Helpers
  alias AstraAutoEx.Production

  def execute(task) do
    payload = task.payload || %{}
    novel_text = payload["novel_text"] || ""
    episode_id = payload["episode_id"] || task.episode_id

    if String.trim(novel_text) == "" do
      {:error, "No text to split into clips"}
    else
      Helpers.update_progress(task, 10)

      model_config = Helpers.get_model_config(task.user_id, task.project_id, :llm)
      provider = model_config["provider"]

      prompt = """
      Split this story into sequential clips/scenes for a short drama.
      Each clip = one continuous scene at one location.

      Return JSON array: [{"title": "", "summary": "", "location": "", "characters": "", "dialogue": "", "duration_estimate": 30}]

      Story:
      #{String.slice(novel_text, 0..6000)}
      """

      request = %{model: model_config["model"], contents: [%{"parts" => [%{"text" => prompt}]}]}

      Helpers.update_progress(task, 40)

      case Helpers.chat(task.user_id, provider, request) do
        {:ok, text} ->
          case extract_json_array(text) do
            {:ok, clips_data} ->
              episode = Production.get_episode!(episode_id)

              Enum.with_index(clips_data, fn clip, idx ->
                Production.create_clip(%{
                  episode_id: episode.id,
                  project_id: task.project_id,
                  clip_index: idx,
                  content: Map.get(clip, "dialogue", ""),
                  summary: Map.get(clip, "summary", ""),
                  location: Map.get(clip, "location", ""),
                  characters: Map.get(clip, "characters", ""),
                  duration: Map.get(clip, "duration_estimate", 30) / 1.0
                })
              end)

              Helpers.update_progress(task, 95)
              {:ok, %{clips_created: length(clips_data)}}

            _ ->
              {:ok, %{raw: text}}
          end

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp extract_json_array(text) do
    json_str =
      case Regex.run(~r/```json\s*([\s\S]*?)```/, text) do
        [_, json] ->
          json

        nil ->
          case Regex.run(~r/\[[\s\S]*\]/, text) do
            [json] -> json
            nil -> text
          end
      end

    case Jason.decode(String.trim(json_str)) do
      {:ok, list} when is_list(list) -> {:ok, list}
      {:ok, _} -> {:error, :not_array}
      err -> err
    end
  end
end

defmodule AstraAutoEx.Workers.Handlers.ScreenplayConvert do
  @moduledoc "Converts clips to detailed screenplay format with panel descriptions."
  alias AstraAutoEx.Workers.Handlers.Helpers
  alias AstraAutoEx.Production

  def execute(task) do
    payload = task.payload || %{}
    episode_id = payload["episode_id"] || task.episode_id

    Helpers.update_progress(task, 10)
    episode = Production.get_episode!(episode_id)
    clips = Production.list_clips(episode.id)

    if Enum.empty?(clips) do
      {:error, "No clips to convert. Run clips_build first."}
    else
      model_config = Helpers.get_model_config(task.user_id, task.project_id, :llm)
      provider = model_config["provider"]

      clips_text =
        clips
        |> Enum.map(fn c ->
          "Clip #{c.clip_index + 1}: #{c.summary}\nLocation: #{c.location}\nCharacters: #{c.characters}"
        end)
        |> Enum.join("\n\n")

      prompt = """
      Convert these clips into a visual screenplay with panels.
      Each clip should have 3-6 panels. Each panel:
      - description: what we see
      - shot_type: extreme_wide/wide/full/medium/close_up/extreme_close_up
      - camera_move: static/pan_left/dolly_in/etc
      - dialogue: character dialogue if any
      - characters: characters visible

      Return JSON: [{"clip_index": 0, "panels": [{"description": "", "shot_type": "", "camera_move": "", "dialogue": "", "characters": ""}]}]

      Clips:
      #{clips_text}
      """

      request = %{model: model_config["model"], contents: [%{"parts" => [%{"text" => prompt}]}]}

      Helpers.update_progress(task, 50)

      case Helpers.chat(task.user_id, provider, request) do
        {:ok, text} ->
          persist_screenplay(task, episode, clips, text)
          Helpers.update_progress(task, 95)
          {:ok, %{status: "converted"}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp persist_screenplay(_task, episode, clips, text) do
    case extract_json(text) do
      {:ok, data} when is_list(data) ->
        Enum.each(data, fn clip_data ->
          clip_idx = Map.get(clip_data, "clip_index", 0)
          clip = Enum.find(clips, fn c -> c.clip_index == clip_idx end)

          if clip do
            {:ok, sb} =
              Production.create_storyboard(%{
                episode_id: episode.id,
                clip_id: clip.id
              })

            panels = Map.get(clip_data, "panels", [])

            Enum.with_index(panels, fn p, pidx ->
              Production.create_panel(%{
                storyboard_id: sb.id,
                episode_id: episode.id,
                panel_index: pidx,
                description: Map.get(p, "description", ""),
                shot_type: Map.get(p, "shot_type", "medium"),
                camera_move: Map.get(p, "camera_move", "static"),
                characters: Map.get(p, "characters", ""),
                location: clip.location
              })
            end)
          end
        end)

      _ ->
        :ok
    end
  end

  defp extract_json(text) do
    json_str =
      case Regex.run(~r/```json\s*([\s\S]*?)```/, text) do
        [_, json] ->
          json

        nil ->
          case Regex.run(~r/\[[\s\S]*\]/, text) do
            [json] -> json
            nil -> text
          end
      end

    Jason.decode(String.trim(json_str))
  end
end

defmodule AstraAutoEx.Workers.Handlers.ImportScript do
  @moduledoc "Imports an external script and creates clips + storyboard."
  alias AstraAutoEx.Workers.Handlers.Helpers
  alias AstraAutoEx.{Production, Tasks}

  def execute(task) do
    payload = task.payload || %{}
    script_text = payload["script_text"] || ""
    episode_id = payload["episode_id"] || task.episode_id

    if String.trim(script_text) == "" do
      {:error, "No script text to import"}
    else
      Helpers.update_progress(task, 10)

      # Directly create clips from script (each paragraph = a clip)
      paragraphs =
        script_text
        |> String.split(~r/\n{2,}/)
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))

      episode = Production.get_episode!(episode_id)

      Enum.with_index(paragraphs, fn para, idx ->
        {:ok, clip} =
          Production.create_clip(%{
            episode_id: episode.id,
            project_id: task.project_id,
            clip_index: idx,
            content: para,
            summary: String.slice(para, 0..100)
          })

        {:ok, sb} =
          Production.create_storyboard(%{
            episode_id: episode.id,
            clip_id: clip.id
          })

        Production.create_panel(%{
          storyboard_id: sb.id,
          episode_id: episode.id,
          panel_index: 0,
          description: para,
          shot_type: "medium"
        })
      end)

      Helpers.update_progress(task, 80)

      # Auto-trigger storyboard enhancement
      if payload["auto_continue"] do
        Tasks.create_task(%{
          user_id: task.user_id,
          project_id: task.project_id,
          episode_id: episode_id,
          type: "script_to_storyboard_run",
          target_type: "episode",
          target_id: episode_id,
          payload: %{"episode_id" => episode_id, "auto_continue" => true}
        })
      end

      {:ok, %{clips_created: length(paragraphs)}}
    end
  end
end
