defmodule AstraAutoEx.Workers.Handlers.StoryboardInsert do
  @moduledoc """
  Inserts a new panel between existing panels in a storyboard, with full
  context awareness.

  Reads the panels immediately before and after the insertion point, feeds
  their description / shot_type / camera_move to the LLM (using the
  `NP_AGENT_STORYBOARD_INSERT` prompt template), creates the new Panel
  record, and shifts all subsequent panels' `panel_index` by +1.

  Payload keys:
    - `storyboard_id` (required) — the storyboard to insert into
    - `insert_after_index` (required) — panel_index after which to insert
    - `user_input` — optional user guidance for the new panel
  """

  require Logger

  import Ecto.Query

  alias AstraAutoEx.Repo
  alias AstraAutoEx.Workers.Handlers.Helpers
  alias AstraAutoEx.AI.PromptCatalog
  alias AstraAutoEx.{Production, Characters, Locations, Tasks}
  alias AstraAutoEx.Production.Panel

  # --------------------------------------------------------------------------
  # Public API
  # --------------------------------------------------------------------------

  @spec execute(struct()) :: {:ok, map()} | {:error, term()}
  def execute(task) do
    payload = task.payload || %{}
    storyboard_id = payload["storyboard_id"]
    insert_after = payload["insert_after_index"]

    with {:ok, storyboard_id} <- require_field(storyboard_id, "storyboard_id"),
         {:ok, insert_after} <- require_int(insert_after, "insert_after_index") do
      Helpers.update_progress(task, 5)
      Logger.info("[StoryboardInsert] Inserting after index #{insert_after} in #{storyboard_id}")

      panels = Production.list_panels(storyboard_id) |> Enum.sort_by(& &1.panel_index)

      prev_panel = Enum.find(panels, fn p -> p.panel_index == insert_after end)
      next_panel = Enum.find(panels, fn p -> p.panel_index == insert_after + 1 end)

      Helpers.update_progress(task, 15)

      # Gather project-level context for the prompt
      context = gather_context(task)

      case generate_panel_data(task, prev_panel, next_panel, context, payload) do
        {:ok, panel_data} ->
          Helpers.update_progress(task, 70)

          # Shift subsequent panels
          shift_panels(storyboard_id, insert_after)

          # Create the new panel
          new_index = insert_after + 1
          storyboard = Production.get_storyboard!(storyboard_id)

          attrs = %{
            storyboard_id: storyboard_id,
            episode_id: storyboard.episode_id,
            panel_index: new_index,
            description: Map.get(panel_data, "description", ""),
            shot_type: Map.get(panel_data, "shot_type", "medium shot"),
            camera_move: Map.get(panel_data, "camera_move", "static"),
            characters: Map.get(panel_data, "characters", ""),
            location: Map.get(panel_data, "location", prev_panel && prev_panel.location),
            acting_notes: Map.get(panel_data, "acting_notes", "")
          }

          case Production.create_panel(attrs) do
            {:ok, panel} ->
              Helpers.update_progress(task, 95)
              Logger.info("[StoryboardInsert] Created panel #{panel.id} at index #{new_index}")

              {:ok,
               %{
                 panel_id: panel.id,
                 panel_index: new_index,
                 description: panel.description,
                 shot_type: panel.shot_type,
                 camera_move: panel.camera_move
               }}

            {:error, changeset} ->
              reason = "Failed to create panel: #{inspect(changeset.errors)}"
              Tasks.update_task(task, %{error_message: reason})
              {:error, reason}
          end

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
  # LLM panel generation
  # --------------------------------------------------------------------------

  @spec generate_panel_data(struct(), struct() | nil, struct() | nil, map(), map()) ::
          {:ok, map()} | {:error, term()}
  defp generate_panel_data(task, prev_panel, next_panel, context, payload) do
    bindings = %{
      prev_panel_json: panel_to_json(prev_panel),
      next_panel_json: panel_to_json(next_panel),
      characters_full_description: context[:characters_desc] || "",
      locations_description: context[:locations_desc] || "",
      props_description: context[:props_desc] || "",
      user_input: payload["user_input"] || "Insert a natural transition panel"
    }

    Helpers.update_progress(task, 25)

    prompt_text =
      case PromptCatalog.load_and_render(:NP_AGENT_STORYBOARD_INSERT, bindings) do
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
          "content" => "你是专业分镜师。根据前后面板的上下文，生成一个自然过渡的新面板。返回JSON格式。"
        },
        %{"role" => "user", "content" => prompt_text}
      ]
    }

    Helpers.update_progress(task, 50)

    case Helpers.chat(task.user_id, provider, request) do
      {:ok, text} ->
        case extract_json(text) do
          {:ok, data} when is_map(data) ->
            {:ok, data}

          _ ->
            {:ok,
             %{"description" => text, "shot_type" => "medium shot", "camera_move" => "static"}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # --------------------------------------------------------------------------
  # Panel index shifting
  # --------------------------------------------------------------------------

  @spec shift_panels(String.t(), integer()) :: :ok
  defp shift_panels(storyboard_id, insert_after) do
    from(p in Panel,
      where: p.storyboard_id == ^storyboard_id and p.panel_index > ^insert_after
    )
    |> Repo.update_all(inc: [panel_index: 1])

    :ok
  end

  # --------------------------------------------------------------------------
  # Context gathering
  # --------------------------------------------------------------------------

  @spec gather_context(struct()) :: map()
  defp gather_context(task) do
    characters_desc =
      try do
        Characters.list_characters(task.project_id)
        |> Enum.map(fn c -> "#{c.name}: #{c.introduction || ""}" end)
        |> Enum.join("\n")
      rescue
        _ -> ""
      end

    locations_desc =
      try do
        Locations.list_locations(task.project_id)
        |> Enum.map(fn l -> "#{l.name}: #{l.description || ""}" end)
        |> Enum.join("\n")
      rescue
        _ -> ""
      end

    %{
      characters_desc: characters_desc,
      locations_desc: locations_desc,
      props_desc: ""
    }
  end

  # --------------------------------------------------------------------------
  # Helpers
  # --------------------------------------------------------------------------

  @spec panel_to_json(struct() | nil) :: String.t()
  defp panel_to_json(nil), do: "{}"

  defp panel_to_json(panel) do
    Jason.encode!(%{
      description: panel.description || "",
      shot_type: panel.shot_type || "",
      camera_move: panel.camera_move || "",
      characters: panel.characters || "",
      location: panel.location || ""
    })
  end

  @spec build_fallback_prompt(map()) :: String.t()
  defp build_fallback_prompt(bindings) do
    """
    Insert a new storyboard panel between the following two panels.
    The new panel should provide a natural visual transition.

    Previous panel: #{bindings.prev_panel_json}
    Next panel: #{bindings.next_panel_json}

    Characters available: #{bindings.characters_full_description}
    Locations available: #{bindings.locations_description}
    User guidance: #{bindings.user_input}

    Return JSON with these fields:
    {"description": "visual description of the panel",
     "shot_type": "wide/medium/close_up/extreme_close_up",
     "camera_move": "static/pan_left/pan_right/dolly_in/dolly_out/tilt_up/tilt_down",
     "characters": "comma-separated character names",
     "location": "location name",
     "acting_notes": "character expression and action notes"}
    """
  end

  @spec require_field(term(), String.t()) :: {:ok, term()} | {:error, String.t()}
  defp require_field(nil, name), do: {:error, "Missing required field: #{name}"}
  defp require_field("", name), do: {:error, "Missing required field: #{name}"}
  defp require_field(value, _name), do: {:ok, value}

  @spec require_int(term(), String.t()) :: {:ok, integer()} | {:error, String.t()}
  defp require_int(nil, name), do: {:error, "Missing required field: #{name}"}
  defp require_int(val, _name) when is_integer(val), do: {:ok, val}

  defp require_int(val, name) when is_binary(val) do
    case Integer.parse(val) do
      {int, _} -> {:ok, int}
      :error -> {:error, "#{name} must be an integer, got: #{val}"}
    end
  end

  defp require_int(val, name), do: {:error, "#{name} must be an integer, got: #{inspect(val)}"}

  @spec extract_json(String.t()) :: {:ok, map()} | {:error, term()}
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
