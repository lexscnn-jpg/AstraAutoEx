defmodule AstraAutoEx.Workers.Handlers.Helpers do
  @moduledoc """
  Shared utilities for task handlers.
  Provides provider config loading, AI dispatch, progress reporting.
  """

  require Logger

  alias AstraAutoEx.{Accounts, Tasks}
  alias AstraAutoEx.Storage.Server, as: Storage

  @doc "Load provider config (api_key, base_url) for a user + provider."
  def get_provider_config(user_id, provider_name) do
    case Accounts.get_user_preference(user_id) do
      nil ->
        {:error, "No provider config found. Please configure #{provider_name} API key."}

      pref ->
        configs = pref.provider_configs || %{}

        case Map.get(configs, provider_name) do
          nil -> {:error, "#{provider_name} not configured. Please add API key in Profile."}
          config -> {:ok, atomize_keys(config)}
        end
    end
  end

  @doc "Get the provider module for a given provider name."
  def provider_module(provider_name) do
    case provider_name do
      "fal" -> AstraAutoEx.AI.Providers.Fal
      "ark" -> AstraAutoEx.AI.Providers.Ark
      "google" -> AstraAutoEx.AI.Providers.Google
      "minimax" -> AstraAutoEx.AI.Providers.Minimax
      "apiyi" -> AstraAutoEx.AI.Providers.Apiyi
      "runninghub" -> AstraAutoEx.AI.Providers.RunningHub
      _ -> nil
    end
  end

  @doc "Dispatch an image generation request with cost tracking."
  def generate_image(user_id, provider_name, request) do
    tracked_call(user_id, provider_name, "image", "generate_image", fn mod, config ->
      mod.generate_image(request, config)
    end)
  end

  @doc "Dispatch a video generation request with cost tracking."
  def generate_video(user_id, provider_name, request) do
    tracked_call(user_id, provider_name, "video", "generate_video", fn mod, config ->
      mod.generate_video(request, config)
    end)
  end

  @doc "Dispatch a TTS request with cost tracking."
  def text_to_speech(user_id, provider_name, request) do
    tracked_call(user_id, provider_name, "voice", "text_to_speech", fn mod, config ->
      mod.text_to_speech(request, config)
    end)
  end

  @doc "Dispatch a chat/LLM request with automatic cost tracking."
  def chat(user_id, provider_name, request) do
    start = System.monotonic_time(:millisecond)
    request = normalize_chat_request(request)

    result =
      with {:ok, config} <- get_provider_config(user_id, provider_name),
           mod when not is_nil(mod) <- provider_module(provider_name) do
        case mod.chat(request, config) do
          {:ok, %{content: content}} -> {:ok, content}
          {:ok, text} when is_binary(text) -> {:ok, text}
          other -> other
        end
      else
        nil -> {:error, "Unknown provider: #{provider_name}"}
        error -> error
      end

    # Track API call cost
    duration = System.monotonic_time(:millisecond) - start
    status = if match?({:ok, _}, result), do: "success", else: "failed"
    pipeline_step = Map.get(request, "action") || Map.get(request, :action) || "chat"

    try do
      AstraAutoEx.Billing.CostTracker.log_call(%{
        user_id: user_id,
        model_key: provider_name,
        model_type: "text",
        pipeline_step: to_string(pipeline_step),
        status: status,
        duration_ms: duration
      })
    rescue
      _ -> :ok
    end

    result
  end

  @doc "Poll an async task."
  def poll_task(user_id, provider_name, external_id, extra_config \\ %{}) do
    with {:ok, config} <- get_provider_config(user_id, provider_name),
         mod when not is_nil(mod) <- provider_module(provider_name) do
      config = Map.merge(config, atomize_keys(extra_config))

      if function_exported?(mod, :poll_task, 2) do
        mod.poll_task(external_id, config)
      else
        {:error, "Provider #{provider_name} does not support polling"}
      end
    else
      nil -> {:error, "Unknown provider: #{provider_name}"}
      error -> error
    end
  end

  @doc "Update task progress (0-100)."
  def update_progress(task, progress) do
    Tasks.update_task(task, %{progress: progress})
  end

  @doc "Download a URL and upload to storage, returning storage key."
  def download_to_storage(url, storage_key, opts \\ []) do
    Storage.download_and_upload(url, storage_key, opts)
  end

  @doc "Get a fetchable URL for a storage key."
  def storage_url(storage_key) do
    Storage.get_signed_url(storage_key)
  end

  @doc "Parse the provider:type:id format from external_id."
  def parse_external_id(external_id) do
    case String.split(external_id, ":", parts: 3) do
      [provider, type, id] ->
        {:ok, %{provider: provider, type: type, id: id}}

      [provider, type, subtype, id] ->
        {:ok, %{provider: provider, type: type, subtype: subtype, id: id}}

      _ ->
        {:error, "Invalid external_id format: #{external_id}"}
    end
  end

  @doc "Get the model config for a pipeline step or model type."
  def get_model_config(user_id, _project_id, step_or_type) do
    key = to_string(step_or_type)

    case Accounts.get_user_preference(user_id) do
      nil ->
        default_model(step_or_type)

      pref ->
        selections = pref.model_selections || %{}

        # Try exact step match first, then fallback type match
        case Map.get(selections, key) do
          nil -> find_by_type(selections, key) || default_model(step_or_type)
          config -> config
        end
    end
  end

  # Find first selection matching the given model type (llm, image, video, etc.)
  defp find_by_type(selections, type) do
    type_steps = %{
      "llm" => ~w(analysis character location storyboard edit),
      "image" => ~w(image),
      "video" => ~w(video),
      "voice" => ~w(voice tts),
      "music" => ~w(music)
    }

    case Map.get(type_steps, type) do
      nil ->
        nil

      steps ->
        Enum.find_value(steps, fn step -> Map.get(selections, step) end)
    end
  end

  defp default_model(:image), do: %{"provider" => "minimax", "model" => "image-01"}
  defp default_model(:video), do: %{"provider" => "minimax", "model" => "minimax-hailuo-2.3"}
  defp default_model(:tts), do: %{"provider" => "minimax", "model" => "speech-2.8-hd"}
  defp default_model(:llm), do: %{"provider" => "minimax", "model" => "MiniMax-M2.7-highspeed"}
  defp default_model(:music), do: %{"provider" => "minimax", "model" => "music-2.6"}
  defp default_model(_), do: %{"provider" => "minimax", "model" => "MiniMax-M2.7-highspeed"}

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) -> {String.to_existing_atom(k), v}
      {k, v} -> {k, v}
    end)
  rescue
    _ -> Map.new(map, fn {k, v} -> {safe_to_atom(k), v} end)
  end

  defp safe_to_atom(k) when is_atom(k), do: k
  defp safe_to_atom(k) when is_binary(k), do: String.to_atom(k)

  # Tracked API call wrapper — logs to billing
  defp tracked_call(user_id, provider_name, model_type, pipeline_step, fun) do
    start = System.monotonic_time(:millisecond)

    result =
      with {:ok, config} <- get_provider_config(user_id, provider_name),
           mod when not is_nil(mod) <- provider_module(provider_name) do
        fun.(mod, config)
      else
        nil -> {:error, "Unknown provider: #{provider_name}"}
        error -> error
      end

    duration = System.monotonic_time(:millisecond) - start
    status = if match?({:ok, _}, result), do: "success", else: "failed"

    try do
      AstraAutoEx.Billing.CostTracker.log_call(%{
        user_id: user_id,
        model_key: to_string(provider_name),
        model_type: model_type,
        pipeline_step: pipeline_step,
        status: status,
        duration_ms: duration
      })
    rescue
      _ -> :ok
    end

    result
  end

  # Normalize chat request: convert Google's `contents` format to OpenAI's `messages` format
  # so all providers receive a consistent request shape.
  defp normalize_chat_request(request) do
    has_messages =
      Map.has_key?(request, "messages") || Map.has_key?(request, :messages)

    if has_messages do
      request
    else
      # Convert Google `contents` format to `messages`
      contents = Map.get(request, :contents, Map.get(request, "contents", []))

      messages =
        Enum.flat_map(contents, fn content ->
          parts = Map.get(content, "parts", Map.get(content, :parts, []))
          role = Map.get(content, "role", Map.get(content, :role, "user"))

          Enum.map(parts, fn part ->
            text = Map.get(part, "text", Map.get(part, :text, ""))
            %{"role" => to_string(role), "content" => text}
          end)
        end)

      model = Map.get(request, :model, Map.get(request, "model"))

      request
      |> Map.put("messages", messages)
      |> Map.put("model", model)
      |> Map.drop([:contents, "contents"])
    end
  end
end
