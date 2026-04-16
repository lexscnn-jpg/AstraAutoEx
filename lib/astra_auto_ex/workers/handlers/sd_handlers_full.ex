defmodule AstraAutoEx.Workers.Handlers.ShortDrama do
  @moduledoc """
  Short Drama creation handler — dispatches 8 sub-tasks for the full
  micro-drama production pipeline.

  Each sub-task loads the matching prompt template from `PromptCatalog`,
  calls the configured LLM, parses the JSON result, and persists to
  the appropriate storage (series_plan / episode_script / etc.).

  Task types dispatched via `task.type`:
    - sd_topic_selection
    - sd_story_outline
    - sd_character_dev
    - sd_episode_directory
    - sd_episode_script
    - sd_quality_review
    - sd_compliance_check
    - sd_overseas_adapt
  """

  require Logger

  alias AstraAutoEx.Workers.Handlers.Helpers
  alias AstraAutoEx.AI.PromptCatalog
  alias AstraAutoEx.Tasks

  @type_to_prompt %{
    "sd_topic_selection" => :SD_TOPIC_SELECTION,
    "sd_story_outline" => :SD_STORY_OUTLINE,
    "sd_character_dev" => :SD_CHARACTER_DEV,
    "sd_episode_directory" => :SD_EPISODE_DIRECTORY,
    "sd_episode_script" => :SD_EPISODE_SCRIPT,
    "sd_quality_review" => :SD_QUALITY_REVIEW,
    "sd_compliance_check" => :SD_COMPLIANCE_CHECK,
    "sd_overseas_adapt" => :SD_OVERSEAS_ADAPT
  }

  # --------------------------------------------------------------------------
  # Public API
  # --------------------------------------------------------------------------

  @spec execute(struct()) :: {:ok, map()} | {:error, term()}
  def execute(task) do
    task_type = task.type

    case Map.get(@type_to_prompt, task_type) do
      nil ->
        {:error, "Unknown short drama task type: #{task_type}"}

      prompt_id ->
        dispatch(task, prompt_id, task_type)
    end
  end

  # --------------------------------------------------------------------------
  # Dispatch — common flow for all 8 steps
  # --------------------------------------------------------------------------

  @spec dispatch(struct(), atom(), String.t()) :: {:ok, map()} | {:error, term()}
  defp dispatch(task, prompt_id, step_name) do
    payload = task.payload || %{}

    Helpers.update_progress(task, 5)
    Logger.info("[ShortDrama] Starting step: #{step_name}")

    with {:ok, bindings} <- build_bindings(step_name, payload),
         {:ok, prompt_text} <- load_prompt(prompt_id, bindings),
         {:ok, llm_response} <- call_llm(task, prompt_text) do
      Helpers.update_progress(task, 80)

      result = parse_and_persist(step_name, task, llm_response)
      Helpers.update_progress(task, 95)

      Logger.info("[ShortDrama] Step #{step_name} completed")
      {:ok, %{step: step_name, result: result}}
    else
      {:error, reason} ->
        Logger.error("[ShortDrama] Step #{step_name} failed: #{inspect(reason)}")
        Tasks.update_task(task, %{error_message: inspect(reason)})
        {:error, reason}
    end
  end

  # --------------------------------------------------------------------------
  # Step-specific binding builders
  # --------------------------------------------------------------------------

  @spec build_bindings(String.t(), map()) :: {:ok, map()} | {:error, String.t()}
  defp build_bindings("sd_topic_selection", payload) do
    {:ok,
     %{
       topic_keyword: payload["topic_keyword"] || payload["input_text"] || "",
       genre_preferences: payload["genre_preferences"] || "all",
       target_audience: payload["target_audience"] || "18-35 female",
       platform: payload["platform"] || "douyin"
     }}
  end

  defp build_bindings("sd_story_outline", payload) do
    {:ok,
     %{
       topic_report:
         payload["topic_report"] || payload["input_text"] ||
           load_previous_result(payload["project_id"], "sd_topic_selection"),
       episode_count: payload["episode_count"] || "80",
       tone: payload["tone"] || "emotional"
     }}
  end

  defp build_bindings("sd_character_dev", payload) do
    {:ok,
     %{
       story_outline:
         payload["story_outline"] || payload["input_text"] ||
           load_previous_result(payload["project_id"], "sd_story_outline"),
       genre: payload["genre"] || "romance"
     }}
  end

  defp build_bindings("sd_episode_directory", payload) do
    {:ok,
     %{
       story_outline:
         payload["story_outline"] || payload["input_text"] ||
           load_previous_result(payload["project_id"], "sd_story_outline"),
       characters:
         payload["characters"] || load_previous_result(payload["project_id"], "sd_character_dev"),
       episode_count: payload["episode_count"] || "80"
     }}
  end

  defp build_bindings("sd_episode_script", payload) do
    {:ok,
     %{
       episode_number: payload["episode_number"] || "1",
       episode_title: payload["episode_title"] || "",
       episode_conflict: payload["episode_conflict"] || "",
       story_outline: payload["story_outline"] || "",
       characters: payload["characters"] || "",
       previous_episode_summary: payload["previous_episode_summary"] || "N/A"
     }}
  end

  defp build_bindings("sd_quality_review", payload) do
    {:ok,
     %{
       episode_script: payload["episode_script"] || payload["input_text"] || "",
       episode_number: payload["episode_number"] || "1"
     }}
  end

  defp build_bindings("sd_compliance_check", payload) do
    {:ok,
     %{
       script_content: payload["script_content"] || payload["input_text"] || "",
       target_market: payload["target_market"] || "china_mainland"
     }}
  end

  defp build_bindings("sd_overseas_adapt", payload) do
    {:ok,
     %{
       original_script: payload["original_script"] || payload["input_text"] || "",
       target_platform: payload["target_platform"] || "ReelShort",
       target_language: payload["target_language"] || "en"
     }}
  end

  defp build_bindings(unknown, _payload) do
    {:error, "No bindings builder for step: #{unknown}"}
  end

  # Look up the most recent completed task of a given type within a project,
  # return its raw LLM output (or "" if none). Used for auto-chaining so
  # step N can read step N-1's output without the caller having to pass it.
  defp load_previous_result(nil, _type), do: ""

  defp load_previous_result(project_id, prev_type) when is_binary(project_id) do
    load_previous_result(String.to_integer(project_id), prev_type)
  rescue
    _ -> ""
  end

  defp load_previous_result(project_id, prev_type) when is_integer(project_id) do
    import Ecto.Query, only: [from: 2]

    q =
      from(t in AstraAutoEx.Tasks.Task,
        where:
          t.project_id == ^project_id and t.type == ^prev_type and t.status == "completed",
        order_by: [desc: t.finished_at],
        limit: 1
      )

    case AstraAutoEx.Repo.one(q) do
      %{result: %{"raw" => raw}} when is_binary(raw) -> raw |> String.slice(0..5999)
      _ -> ""
    end
  end

  defp load_previous_result(_, _), do: ""

  # --------------------------------------------------------------------------
  # Prompt loading
  # --------------------------------------------------------------------------

  @spec load_prompt(atom(), map()) :: {:ok, String.t()} | {:error, term()}
  defp load_prompt(prompt_id, bindings) do
    case PromptCatalog.load_and_render(prompt_id, bindings) do
      {:ok, text} ->
        {:ok, text}

      {:error, {:file_read, _path, _reason}} ->
        # Template file not yet created — fall back to inline instruction
        Logger.warning("[ShortDrama] Prompt template not found for #{prompt_id}, using fallback")
        {:ok, build_fallback_prompt(prompt_id, bindings)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec build_fallback_prompt(atom(), map()) :: String.t()
  defp build_fallback_prompt(prompt_id, bindings) do
    context =
      bindings
      |> Enum.map(fn {k, v} -> "#{k}: #{v}" end)
      |> Enum.join("\n")

    """
    You are a professional micro-drama (短剧) screenwriter.
    Task: #{prompt_id}

    Context:
    #{context}

    Please complete this task and return your response as valid JSON.
    """
  end

  # --------------------------------------------------------------------------
  # LLM call
  # --------------------------------------------------------------------------

  @spec call_llm(struct(), String.t()) :: {:ok, String.t()} | {:error, term()}
  defp call_llm(task, prompt_text) do
    model_config = Helpers.get_model_config(task.user_id, task.project_id, :llm)
    provider = model_config["provider"]

    request = %{
      model: model_config["model"],
      messages: [
        %{"role" => "system", "content" => "你是一位专业的微短剧编剧和策划专家。请用中文回答，返回结构化JSON。"},
        %{"role" => "user", "content" => prompt_text}
      ]
    }

    Helpers.update_progress(task, 40)
    Helpers.chat(task.user_id, provider, request)
  end

  # --------------------------------------------------------------------------
  # Result parsing & persistence
  # --------------------------------------------------------------------------

  @spec parse_and_persist(String.t(), struct(), String.t()) :: map()
  defp parse_and_persist(step_name, task, llm_response) do
    parsed = extract_json(llm_response)

    # Store the result in task's result field for downstream consumption
    result_data = %{
      "step" => step_name,
      "raw" => llm_response,
      "parsed" => parsed
    }

    Tasks.update_task(task, %{result: result_data})

    # Step-specific persistence
    persist_step_result(step_name, task, parsed)

    result_data
  end

  @spec persist_step_result(String.t(), struct(), term()) :: :ok
  defp persist_step_result("sd_topic_selection", _task, _parsed), do: :ok
  defp persist_step_result("sd_story_outline", _task, _parsed), do: :ok
  defp persist_step_result("sd_character_dev", _task, _parsed), do: :ok
  defp persist_step_result("sd_episode_directory", _task, _parsed), do: :ok

  defp persist_step_result("sd_episode_script", task, parsed) when is_map(parsed) do
    # Auto-trigger quality review if configured
    payload = task.payload || %{}

    if payload["auto_review"] do
      script_text = Map.get(parsed, "script", Jason.encode!(parsed))

      Tasks.create_task(%{
        user_id: task.user_id,
        project_id: task.project_id,
        type: "sd_quality_review",
        target_type: "project",
        target_id: task.project_id,
        payload: %{
          "input_text" => script_text,
          "episode_script" => script_text,
          "episode_number" => payload["episode_number"] || "1"
        }
      })
    end

    :ok
  end

  defp persist_step_result("sd_quality_review", _task, _parsed), do: :ok
  defp persist_step_result("sd_compliance_check", _task, _parsed), do: :ok
  defp persist_step_result("sd_overseas_adapt", _task, _parsed), do: :ok
  defp persist_step_result(_step, _task, _parsed), do: :ok

  # --------------------------------------------------------------------------
  # JSON extraction
  # --------------------------------------------------------------------------

  @spec extract_json(String.t()) :: map() | list() | nil
  defp extract_json(text) when is_binary(text) do
    json_str =
      case Regex.run(~r/```json\s*([\s\S]*?)```/, text) do
        [_, json] ->
          json

        nil ->
          case Regex.run(~r/\{[\s\S]*\}/, text) do
            [json] ->
              json

            nil ->
              case Regex.run(~r/\[[\s\S]*\]/, text) do
                [json] -> json
                nil -> nil
              end
          end
      end

    case json_str && Jason.decode(String.trim(json_str)) do
      {:ok, data} -> data
      _ -> nil
    end
  end

  defp extract_json(_), do: nil
end
