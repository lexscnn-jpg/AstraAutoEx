defmodule AstraAutoEx.AI.EntityExtractor do
  @moduledoc """
  Extracts characters, locations, and props from script text using LLM.
  Ported from original project's orchestrator.ts (3-phase parallel analysis).
  """
  require Logger

  alias AstraAutoEx.Workers.Handlers.Helpers

  @doc """
  Extract all entities from script text in parallel.
  Returns `{:ok, %{characters: [...], locations: [...], props: [...]}}`.
  """
  def extract_all(user_id, script_text, opts \\ []) do
    provider = Keyword.get(opts, :provider, nil)
    model = Keyword.get(opts, :model, nil)

    # Get LLM model config
    model_config =
      if provider && model do
        %{"provider" => provider, "model" => model}
      else
        Helpers.get_model_config(user_id, nil, :llm)
      end

    provider = model_config["provider"]

    # Phase 1: Parallel LLM analysis
    tasks = [
      Task.async(fn -> extract_characters(user_id, provider, model_config, script_text) end),
      Task.async(fn -> extract_locations(user_id, provider, model_config, script_text) end),
      Task.async(fn -> extract_props(user_id, provider, model_config, script_text) end)
    ]

    results = Task.await_many(tasks, 120_000)

    characters = parse_result(Enum.at(results, 0), "characters")
    locations = parse_result(Enum.at(results, 1), "locations")
    props = parse_result(Enum.at(results, 2), "props")

    Logger.info(
      "[EntityExtractor] Extracted #{length(characters)} characters, #{length(locations)} locations, #{length(props)} props"
    )

    {:ok, %{characters: characters, locations: locations, props: props}}
  end

  @doc """
  Assign extracted entities to panels based on description matching.
  Updates panel.characters, panel.location, panel.props fields.
  """
  def assign_entities_to_panels(panels, %{characters: characters, locations: locations, props: props}) do
    Enum.map(panels, fn panel ->
      desc = (panel.description || "") |> String.downcase()

      matched_chars =
        characters
        |> Enum.filter(fn c -> String.contains?(desc, String.downcase(c["name"] || "")) end)
        |> Enum.map(& &1["name"])

      matched_location =
        locations
        |> Enum.find(fn l -> String.contains?(desc, String.downcase(l["name"] || "")) end)

      matched_props =
        props
        |> Enum.filter(fn p -> String.contains?(desc, String.downcase(p["name"] || "")) end)
        |> Enum.map(& &1["name"])

      %{
        panel_id: panel.id,
        characters: matched_chars,
        location: if(matched_location, do: matched_location["name"]),
        props: matched_props
      }
    end)
  end

  # ── Private ──

  defp extract_characters(user_id, provider, model_config, script_text) do
    prompt = """
    分析以下剧本/故事文本，提取所有出场角色。

    对每个角色，返回：
    - name: 角色名称
    - gender: 性别（男/女/未知）
    - description: 一句话外貌描述（用于生成角色设定图）
    - personality: 一句话性格特点
    - aliases: 别名列表（如有）

    仅返回 JSON 数组，不要包含其他文字。格式：
    [{"name": "...", "gender": "...", "description": "...", "personality": "...", "aliases": []}]

    剧本文本：
    #{String.slice(script_text, 0, 8000)}
    """

    request = %{
      messages: [%{role: "user", content: prompt}],
      model: model_config["model"],
      temperature: 0.3,
      action: "extract_characters"
    }

    Helpers.chat(user_id, provider, request)
  end

  defp extract_locations(user_id, provider, model_config, script_text) do
    prompt = """
    分析以下剧本/故事文本，提取所有出现的场景/地点。

    对每个场景，返回：
    - name: 场景名称
    - description: 环境描述（氛围、时间、天气、特征）
    - type: 场景类型（室内/室外/虚拟）

    仅返回 JSON 数组，不要包含其他文字。格式：
    [{"name": "...", "description": "...", "type": "..."}]

    剧本文本：
    #{String.slice(script_text, 0, 8000)}
    """

    request = %{
      messages: [%{role: "user", content: prompt}],
      model: model_config["model"],
      temperature: 0.3,
      action: "extract_locations"
    }

    Helpers.chat(user_id, provider, request)
  end

  defp extract_props(user_id, provider, model_config, script_text) do
    prompt = """
    分析以下剧本/故事文本，提取所有重要道具/物品。

    仅提取对剧情有推动作用的关键道具，忽略普通日常用品。
    对每个道具，返回：
    - name: 道具名称
    - type: 类型（weapon/tool/accessory/vehicle/food/other）
    - description: 外观描述
    - significance: 剧情作用（一句话）

    仅返回 JSON 数组，不要包含其他文字。格式：
    [{"name": "...", "type": "...", "description": "...", "significance": "..."}]

    剧本文本：
    #{String.slice(script_text, 0, 8000)}
    """

    request = %{
      messages: [%{role: "user", content: prompt}],
      model: model_config["model"],
      temperature: 0.3,
      action: "extract_props"
    }

    Helpers.chat(user_id, provider, request)
  end

  defp parse_result({:ok, result}, key) do
    # The LLM result typically has a text field with JSON
    text =
      cond do
        is_map(result) && Map.has_key?(result, :text) -> result.text
        is_map(result) && Map.has_key?(result, "text") -> result["text"]
        is_map(result) && Map.has_key?(result, :content) -> result.content
        is_binary(result) -> result
        true -> ""
      end

    # Extract JSON from the text (handle markdown code blocks)
    json_text =
      text
      |> String.replace(~r/```json\n?/, "")
      |> String.replace(~r/```\n?/, "")
      |> String.trim()

    case Jason.decode(json_text) do
      {:ok, list} when is_list(list) -> list
      {:ok, %{^key => list}} when is_list(list) -> list
      _ ->
        Logger.warning("[EntityExtractor] Failed to parse #{key} from: #{String.slice(json_text, 0, 200)}")
        []
    end
  end

  defp parse_result({:error, reason}, key) do
    Logger.warning("[EntityExtractor] Failed to extract #{key}: #{inspect(reason)}")
    []
  end

  defp parse_result(_, key) do
    Logger.warning("[EntityExtractor] Unexpected result for #{key}")
    []
  end
end
