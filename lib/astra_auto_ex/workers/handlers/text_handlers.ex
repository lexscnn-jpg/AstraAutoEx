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
      analysis_config = Helpers.get_model_config(task.user_id, task.project_id, "analysis")
      storyboard_config = Helpers.get_model_config(task.user_id, task.project_id, "storyboard")
      provider = analysis_config["provider"]
      model = analysis_config["model"]
      sb_provider = storyboard_config["provider"]
      sb_model = storyboard_config["model"]

      # Step 1: Character analysis
      Helpers.update_progress(task, 15)

      char_result =
        analyze_step(
          task.user_id,
          provider,
          model,
          novel_text,
          "分析以下故事文本，提取所有角色。每个角色需要：name(姓名), gender(性别), age(年龄), personality(性格), appearance(外貌描述)。返回JSON数组。"
        )

      # Step 2: Location analysis
      Helpers.update_progress(task, 30)

      loc_result =
        analyze_step(
          task.user_id,
          provider,
          model,
          novel_text,
          "分析以下故事文本，提取所有场景/地点。每个场景需要：name(名称), description(描述), mood(氛围)。返回JSON数组。"
        )

      # Step 3: Clip splitting
      Helpers.update_progress(task, 50)

      clips_result =
        analyze_step(
          task.user_id,
          provider,
          model,
          novel_text,
          "将以下故事拆分为连续的片段/场景(clips)。每个片段需要：title(标题), summary(概要), characters(涉及角色), location(场景), dialogue(对白摘要)。返回JSON数组。"
        )

      # Step 4: Screenplay conversion
      Helpers.update_progress(task, 70)

      screenplay =
        analyze_step(
          task.user_id,
          sb_provider,
          sb_model,
          novel_text,
          "将以下故事转换为分镜剧本格式。每个clip包含3-6个panels。每个clip顶层需要：title(标题), summary(概要), characters(角色数组), location(主场景)。每个panel需要：description(画面描述), shot_type(镜头类型: wide/medium/close_up), camera_move(运镜: static/pan/dolly), dialogue(对白), characters(出场角色数组), location(场景名)。返回JSON数组: [{\"title\":\"\",\"summary\":\"\",\"characters\":[],\"location\":\"\",\"panels\":[{...}]}]"
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
        # Collect all characters + locations across clips, write to global tables
        sync_global_assets(task.user_id, task.project_id, episode.id, clips)

        Enum.with_index(clips, fn clip_data, idx ->
          panels = Map.get(clip_data, "panels", [])

          # Derive clip-level aggregates from panels if not explicit
          clip_characters =
            Map.get(clip_data, "characters") ||
              panels |> Enum.flat_map(&list_of_strings(Map.get(&1, "characters"))) |> Enum.uniq()

          clip_location =
            Map.get(clip_data, "location") ||
              panels |> Enum.map(&Map.get(&1, "location")) |> Enum.reject(&is_nil/1) |> List.first()

          {:ok, clip} =
            Production.create_clip(%{
              episode_id: episode.id,
              clip_index: idx,
              summary: to_string_field(Map.get(clip_data, "summary", Map.get(clip_data, "title", ""))),
              content: to_string_field(Map.get(clip_data, "content", "")),
              characters: to_string_field(clip_characters),
              location: to_string_field(clip_location || ""),
              screenplay: Jason.encode!(clip_data)
            })

          # Create storyboard for this clip
          {:ok, sb} =
            Production.create_storyboard(%{
              episode_id: episode.id,
              clip_id: clip.id
            })

          # Create panels
          Enum.with_index(panels, fn panel_data, pidx ->
            Production.create_panel(%{
              storyboard_id: sb.id,
              episode_id: episode.id,
              description: Map.get(panel_data, "description", ""),
              shot_type: Map.get(panel_data, "shot_type", "medium shot"),
              camera_move: Map.get(panel_data, "camera", Map.get(panel_data, "camera_move", "")),
              characters: to_string_field(Map.get(panel_data, "characters", "")),
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

  defp list_of_strings(val) when is_list(val), do: Enum.map(val, &to_string/1)
  defp list_of_strings(val) when is_binary(val), do: String.split(val, ~r/[,，、]\s*/, trim: true)
  defp list_of_strings(_), do: []

  # Aggregate characters/locations across clips → upsert to global tables.
  # Without this, the assets panel on the Script stage stays empty even though
  # individual clips have character names (the schemas are populated per-clip only).
  defp sync_global_assets(user_id, project_id, episode_id, clips) when is_list(clips) do
    existing_char_names =
      project_id
      |> Characters.list_characters()
      |> Enum.map(& &1.name)
      |> MapSet.new()

    existing_loc_names =
      project_id
      |> Locations.list_locations()
      |> Enum.map(& &1.name)
      |> MapSet.new()

    # Characters: flatten clip-level + panel-level
    char_names =
      clips
      |> Enum.flat_map(fn c ->
        top = list_of_strings(Map.get(c, "characters"))
        panel_chars = Map.get(c, "panels", []) |> Enum.flat_map(&list_of_strings(Map.get(&1, "characters")))
        top ++ panel_chars
      end)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq()

    for name <- char_names, not MapSet.member?(existing_char_names, name) do
      Characters.create_character(%{
        user_id: user_id,
        project_id: project_id,
        episode_id: episode_id,
        name: name,
        introduction: ""
      })
    end

    # Locations: similar
    loc_names =
      clips
      |> Enum.flat_map(fn c ->
        top = list_of_strings(Map.get(c, "location"))
        panel_locs = Map.get(c, "panels", []) |> Enum.map(&Map.get(&1, "location")) |> Enum.reject(&is_nil/1)
        top ++ panel_locs
      end)
      |> Enum.map(&to_string/1)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq()

    for name <- loc_names, not MapSet.member?(existing_loc_names, name) do
      Locations.create_location(%{
        user_id: user_id,
        project_id: project_id,
        episode_id: episode_id,
        name: name,
        summary: ""
      })
    end

    :ok
  end

  defp sync_global_assets(_user_id, _project_id, _episode_id, _other), do: :ok

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
                camera_move: Map.get(data, "camera_movement", panel.camera_move)
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
                  clip_index: idx,
                  content: to_string_field(Map.get(clip, "dialogue") || Map.get(clip, "content") || ""),
                  summary: to_string_field(Map.get(clip, "summary", "")),
                  location: to_string_field(Map.get(clip, "location", "")),
                  characters: to_string_field(Map.get(clip, "characters", "")),
                  props: to_string_field(Map.get(clip, "props", "")),
                  duration: (Map.get(clip, "duration_estimate") || Map.get(clip, "duration") || 30) / 1.0
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

  # Local helper: normalize LLM-returned field to a schema-friendly string.
  # LLM often returns arrays for characters/props; schema column is :string.
  defp to_string_field(val) when is_list(val), do: Enum.join(val, ", ")
  defp to_string_field(val) when is_binary(val), do: val
  defp to_string_field(_), do: ""
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
