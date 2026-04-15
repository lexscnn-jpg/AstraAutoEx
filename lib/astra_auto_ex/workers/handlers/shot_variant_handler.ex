defmodule AstraAutoEx.Workers.Handlers.ShotVariant do
  @moduledoc """
  Generates 3 visual variants of an existing storyboard panel.

  Given a panel ID, reads the panel's current data (description, shot_type,
  camera_move), calls the LLM with the `NP_AGENT_SHOT_VARIANT_ANALYSIS`
  prompt to produce 3 alternative compositions, and returns them as a list.

  The variants are **not** written back to the panel — they are returned in
  the task result so the UI can present them for user selection.

  Payload keys:
    - `panel_id` (required) — the source panel
  """

  require Logger

  alias AstraAutoEx.Workers.Handlers.Helpers
  alias AstraAutoEx.AI.PromptCatalog
  alias AstraAutoEx.{Production, Characters, Locations, Tasks}

  @variant_count 3

  # --------------------------------------------------------------------------
  # Public API
  # --------------------------------------------------------------------------

  @spec execute(struct()) :: {:ok, map()} | {:error, term()}
  def execute(task) do
    payload = task.payload || %{}
    panel_id = payload["panel_id"] || task.target_id

    with {:ok, panel} <- fetch_panel(panel_id) do
      Helpers.update_progress(task, 5)
      Logger.info("[ShotVariant] Generating #{@variant_count} variants for panel #{panel_id}")

      context = gather_context(task, panel)
      Helpers.update_progress(task, 15)

      case generate_variants(task, panel, context) do
        {:ok, variants} when is_list(variants) ->
          Helpers.update_progress(task, 95)

          result = %{
            panel_id: panel_id,
            original: %{
              description: panel.description,
              shot_type: panel.shot_type,
              camera_move: panel.camera_move
            },
            variants: variants,
            variant_count: length(variants)
          }

          Logger.info(
            "[ShotVariant] Generated #{length(variants)} variants for panel #{panel_id}"
          )

          {:ok, result}

        {:error, reason} ->
          Tasks.update_task(task, %{error_message: inspect(reason)})
          {:error, reason}
      end
    else
      {:error, reason} ->
        Tasks.update_task(task, %{error_message: inspect(reason)})
        {:error, reason}
    end
  end

  # --------------------------------------------------------------------------
  # Variant generation
  # --------------------------------------------------------------------------

  @spec generate_variants(struct(), struct(), map()) ::
          {:ok, [map()]} | {:error, term()}
  defp generate_variants(task, panel, context) do
    bindings = %{
      panel_description: panel.description || "",
      shot_type: panel.shot_type || "medium shot",
      camera_move: panel.camera_move || "static",
      location: panel.location || "",
      characters_info: context[:characters_info] || ""
    }

    Helpers.update_progress(task, 25)

    prompt_text =
      case PromptCatalog.load_and_render(:NP_AGENT_SHOT_VARIANT_ANALYSIS, bindings) do
        {:ok, text} ->
          text

        {:error, _} ->
          build_fallback_prompt(bindings)
      end

    model_config = Helpers.get_model_config(task.user_id, task.project_id, :llm)
    provider = model_config["provider"]

    request = %{
      model: model_config["model"],
      messages: [
        %{
          "role" => "system",
          "content" =>
            "你是一位专业的影视摄影指导。请为给定的分镜面板生成#{@variant_count}种不同的镜头变体方案。每种变体使用不同的景别(shot_type)、运镜(camera_move)和画面描述(description)。返回JSON数组。"
        },
        %{"role" => "user", "content" => prompt_text}
      ]
    }

    Helpers.update_progress(task, 50)

    case Helpers.chat(task.user_id, provider, request) do
      {:ok, text} ->
        parse_variants(text)

      {:error, reason} ->
        {:error, reason}
    end
  end

  # --------------------------------------------------------------------------
  # Response parsing
  # --------------------------------------------------------------------------

  @spec parse_variants(String.t()) :: {:ok, [map()]} | {:error, String.t()}
  defp parse_variants(text) do
    case extract_json(text) do
      {:ok, variants} when is_list(variants) ->
        normalized =
          variants
          |> Enum.take(@variant_count)
          |> Enum.with_index(1)
          |> Enum.map(fn {v, idx} ->
            %{
              variant_index: idx,
              title: Map.get(v, "title", "Variant #{idx}"),
              description: Map.get(v, "description", ""),
              shot_type: Map.get(v, "shot_type", "medium shot"),
              camera_move: Map.get(v, "camera_move", Map.get(v, "camera_movement", "static")),
              rationale: Map.get(v, "rationale", Map.get(v, "reason", ""))
            }
          end)

        {:ok, normalized}

      {:ok, single} when is_map(single) ->
        # LLM returned a wrapper object — look for a "variants" key
        inner =
          Map.get(single, "variants", Map.get(single, "options", Map.get(single, "shots", [])))

        if is_list(inner) and length(inner) > 0 do
          parse_variants(Jason.encode!(inner))
        else
          {:ok, [normalize_single_variant(single, 1)]}
        end

      {:error, _} ->
        # Could not parse JSON — wrap raw text as a single variant
        {:ok,
         [
           %{
             variant_index: 1,
             title: "Variant 1",
             description: text,
             shot_type: "medium shot",
             camera_move: "static",
             rationale: "Auto-generated from raw LLM response"
           }
         ]}
    end
  end

  @spec normalize_single_variant(map(), integer()) :: map()
  defp normalize_single_variant(v, idx) do
    %{
      variant_index: idx,
      title: Map.get(v, "title", "Variant #{idx}"),
      description: Map.get(v, "description", ""),
      shot_type: Map.get(v, "shot_type", "medium shot"),
      camera_move: Map.get(v, "camera_move", Map.get(v, "camera_movement", "static")),
      rationale: Map.get(v, "rationale", "")
    }
  end

  # --------------------------------------------------------------------------
  # Context gathering
  # --------------------------------------------------------------------------

  @spec gather_context(struct(), struct()) :: map()
  defp gather_context(task, panel) do
    # Build character context from panel's character references
    characters_info =
      try do
        chars = Characters.list_characters(task.project_id)
        description = panel.description || ""

        chars
        |> Enum.filter(fn c ->
          name = c.name || ""
          String.contains?(description, name) or String.contains?(panel.characters || "", name)
        end)
        |> Enum.map(fn c -> "#{c.name}: #{c.introduction || ""}" end)
        |> Enum.join("; ")
      rescue
        _ -> ""
      end

    # Location context
    location_info =
      try do
        if panel.location && panel.location != "" do
          locs = Locations.list_locations(task.project_id)
          loc = Enum.find(locs, fn l -> l.name == panel.location end)
          if loc, do: "#{loc.name}: #{loc.description || ""}", else: panel.location
        else
          ""
        end
      rescue
        _ -> ""
      end

    %{
      characters_info: characters_info,
      location_info: location_info
    }
  end

  # --------------------------------------------------------------------------
  # Helpers
  # --------------------------------------------------------------------------

  @spec fetch_panel(String.t() | integer()) :: {:ok, struct()} | {:error, String.t()}
  defp fetch_panel(panel_id) do
    try do
      {:ok, Production.get_panel!(panel_id)}
    rescue
      Ecto.NoResultsError -> {:error, "Panel #{panel_id} not found"}
    end
  end

  @spec build_fallback_prompt(map()) :: String.t()
  defp build_fallback_prompt(bindings) do
    """
    Analyze the following storyboard panel and generate #{@variant_count} different shot variants.

    Current panel:
    - Description: #{bindings.panel_description}
    - Shot type: #{bindings.shot_type}
    - Camera movement: #{bindings.camera_move}
    - Location: #{bindings.location}
    - Characters: #{bindings.characters_info}

    For each variant, provide a different cinematic approach:
    1. A more dramatic/emotional version
    2. A wider establishing version
    3. A dynamic action-oriented version

    Return as JSON array:
    [
      {
        "title": "variant name",
        "description": "detailed visual description",
        "shot_type": "wide/medium/close_up/extreme_close_up/full/pov/dutch_angle",
        "camera_move": "static/pan_left/pan_right/dolly_in/dolly_out/crane_up/tracking",
        "rationale": "why this variant works"
      }
    ]
    """
  end

  @spec extract_json(String.t()) :: {:ok, map() | list()} | {:error, term()}
  defp extract_json(text) do
    json_str =
      case Regex.run(~r/```json\s*([\s\S]*?)```/, text) do
        [_, json] ->
          json

        nil ->
          case Regex.run(~r/\[[\s\S]*\]/, text) do
            [json] ->
              json

            nil ->
              case Regex.run(~r/\{[\s\S]*\}/, text) do
                [json] -> json
                nil -> text
              end
          end
      end

    Jason.decode(String.trim(json_str))
  end
end
