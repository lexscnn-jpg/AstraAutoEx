defmodule AstraAutoEx.Workers.Handlers.AICreateCharacter do
  @moduledoc "AI-assisted character creation from description."
  alias AstraAutoEx.Workers.Handlers.Helpers
  alias AstraAutoEx.Characters

  def execute(task) do
    payload = task.payload || %{}

    Helpers.update_progress(task, 10)

    model_config = Helpers.get_model_config(task.user_id, task.project_id, :llm)
    provider = model_config["provider"]

    prompt = """
    Create a detailed character profile from this description:
    #{payload["description"] || ""}

    Return JSON: {"name": "", "gender": "", "age": "", "personality": "",
    "physical_description": "", "appearance_prompt": "detailed visual description for image generation"}
    """

    request = %{model: model_config["model"], contents: [%{"parts" => [%{"text" => prompt}]}]}

    Helpers.update_progress(task, 40)

    case Helpers.chat(task.user_id, provider, request) do
      {:ok, text} ->
        case extract_json(text) do
          {:ok, data} ->
            {:ok, char} =
              Characters.create_character(%{
                project_id: task.project_id,
                name: Map.get(data, "name", "Character"),
                gender: Map.get(data, "gender"),
                age: Map.get(data, "age"),
                description: Map.get(data, "physical_description", ""),
                personality: Map.get(data, "personality", "")
              })

            # Create appearance with AI-generated prompt
            appearance_prompt = Map.get(data, "appearance_prompt", "")

            if appearance_prompt != "" do
              Characters.create_appearance(%{
                character_id: char.id,
                description: appearance_prompt,
                is_primary: true
              })
            end

            {:ok, %{character_id: char.id, name: char.name}}

          {:error, _} ->
            {:ok, %{raw: text}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_json(text) do
    json_str =
      case Regex.run(~r/\{[\s\S]*\}/, text) do
        [json] -> json
        nil -> text
      end

    Jason.decode(String.trim(json_str))
  end
end

defmodule AstraAutoEx.Workers.Handlers.AICreateLocation do
  @moduledoc "AI-assisted location creation from description."
  alias AstraAutoEx.Workers.Handlers.Helpers
  alias AstraAutoEx.Locations

  def execute(task) do
    payload = task.payload || %{}

    model_config = Helpers.get_model_config(task.user_id, task.project_id, :llm)
    provider = model_config["provider"]

    prompt = """
    Create a detailed location profile:
    #{payload["description"] || ""}

    Return JSON: {"name": "", "description": "detailed visual description", "mood": "", "lighting": ""}
    """

    request = %{model: model_config["model"], contents: [%{"parts" => [%{"text" => prompt}]}]}

    case Helpers.chat(task.user_id, provider, request) do
      {:ok, text} ->
        case extract_json(text) do
          {:ok, data} ->
            {:ok, loc} =
              Locations.create_location(%{
                project_id: task.project_id,
                name: Map.get(data, "name", "Location"),
                description: Map.get(data, "description", "")
              })

            {:ok, %{location_id: loc.id, name: loc.name}}

          _ ->
            {:ok, %{raw: text}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_json(text) do
    json_str =
      case Regex.run(~r/\{[\s\S]*\}/, text) do
        [json] -> json
        nil -> text
      end

    Jason.decode(String.trim(json_str))
  end
end

defmodule AstraAutoEx.Workers.Handlers.AIModifyAppearance do
  @moduledoc "AI-assisted modification of character appearance prompt."
  alias AstraAutoEx.Workers.Handlers.Helpers

  def execute(task) do
    payload = task.payload || %{}

    model_config = Helpers.get_model_config(task.user_id, task.project_id, :llm)
    provider = model_config["provider"]

    prompt = """
    Modify this character appearance description based on the instruction:
    Original: #{payload["original_description"] || ""}
    Instruction: #{payload["modification"] || ""}

    Return JSON: {"description": "updated visual description"}
    """

    request = %{model: model_config["model"], contents: [%{"parts" => [%{"text" => prompt}]}]}

    case Helpers.chat(task.user_id, provider, request) do
      {:ok, text} -> {:ok, %{result: text}}
      {:error, reason} -> {:error, reason}
    end
  end
end

defmodule AstraAutoEx.Workers.Handlers.AIModifyShotPrompt do
  @moduledoc "AI-assisted modification of shot/panel prompt."
  alias AstraAutoEx.Workers.Handlers.Helpers

  def execute(task) do
    payload = task.payload || %{}

    model_config = Helpers.get_model_config(task.user_id, task.project_id, :llm)
    provider = model_config["provider"]

    prompt = """
    Modify this shot description based on the instruction:
    Original: #{payload["original_description"] || ""}
    Instruction: #{payload["modification"] || ""}
    Shot type: #{payload["shot_type"] || "medium shot"}

    Return JSON: {"description": "...", "shot_type": "...", "camera_movement": "..."}
    """

    request = %{model: model_config["model"], contents: [%{"parts" => [%{"text" => prompt}]}]}

    case Helpers.chat(task.user_id, provider, request) do
      {:ok, text} -> {:ok, %{result: text}}
      {:error, reason} -> {:error, reason}
    end
  end
end
