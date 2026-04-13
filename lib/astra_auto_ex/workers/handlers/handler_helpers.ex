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

  @doc "Dispatch an image generation request to the appropriate provider."
  def generate_image(user_id, provider_name, request) do
    with {:ok, config} <- get_provider_config(user_id, provider_name),
         mod when not is_nil(mod) <- provider_module(provider_name) do
      mod.generate_image(request, config)
    else
      nil -> {:error, "Unknown provider: #{provider_name}"}
      error -> error
    end
  end

  @doc "Dispatch a video generation request."
  def generate_video(user_id, provider_name, request) do
    with {:ok, config} <- get_provider_config(user_id, provider_name),
         mod when not is_nil(mod) <- provider_module(provider_name) do
      mod.generate_video(request, config)
    else
      nil -> {:error, "Unknown provider: #{provider_name}"}
      error -> error
    end
  end

  @doc "Dispatch a TTS request."
  def text_to_speech(user_id, provider_name, request) do
    with {:ok, config} <- get_provider_config(user_id, provider_name),
         mod when not is_nil(mod) <- provider_module(provider_name) do
      mod.text_to_speech(request, config)
    else
      nil -> {:error, "Unknown provider: #{provider_name}"}
      error -> error
    end
  end

  @doc "Dispatch a chat/LLM request."
  def chat(user_id, provider_name, request) do
    with {:ok, config} <- get_provider_config(user_id, provider_name),
         mod when not is_nil(mod) <- provider_module(provider_name) do
      mod.chat(request, config)
    else
      nil -> {:error, "Unknown provider: #{provider_name}"}
      error -> error
    end
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

  @doc "Get the default model config for a project/user."
  def get_model_config(user_id, _project_id, model_type) do
    case Accounts.get_user_preference(user_id) do
      nil ->
        default_model(model_type)

      pref ->
        selections = pref.model_selections || %{}
        Map.get(selections, to_string(model_type)) || default_model(model_type)
    end
  end

  defp default_model(:image), do: %{"provider" => "minimax", "model" => "image-01"}
  defp default_model(:video), do: %{"provider" => "minimax", "model" => "minimax-hailuo-2.3"}
  defp default_model(:tts), do: %{"provider" => "minimax", "model" => "speech-2.8-hd"}
  defp default_model(:llm), do: %{"provider" => "google", "model" => "gemini-2.5-flash"}
  defp default_model(:music), do: %{"provider" => "minimax", "model" => "music-2.6"}
  defp default_model(_), do: %{"provider" => "google", "model" => "gemini-2.5-flash"}

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
end
