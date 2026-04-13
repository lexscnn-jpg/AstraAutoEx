defmodule AstraAutoEx.AI.Gateway do
  @moduledoc """
  Routes AI requests to the appropriate provider based on model name.
  """

  alias AstraAutoEx.AI.Providers.{Fal, Ark, Google, Minimax, Apiyi, RunningHub}

  @provider_map %{
    "fal" => Fal,
    "ark" => Ark,
    "google" => Google,
    "minimax" => Minimax,
    "apiyi" => Apiyi,
    "runninghub" => RunningHub
  }

  def get_provider(provider_key) do
    Map.get(@provider_map, provider_key)
  end

  def generate_image(provider_key, request, config) do
    case get_provider(provider_key) do
      nil -> {:error, :unknown_provider}
      mod -> mod.generate_image(request, config)
    end
  end

  def generate_video(provider_key, request, config) do
    case get_provider(provider_key) do
      nil -> {:error, :unknown_provider}
      mod -> mod.generate_video(request, config)
    end
  end

  def chat(provider_key, request, config) do
    case get_provider(provider_key) do
      nil -> {:error, :unknown_provider}
      mod -> mod.chat(request, config)
    end
  end

  def chat_stream(provider_key, request, config) do
    case get_provider(provider_key) do
      nil -> {:error, :unknown_provider}
      mod -> mod.chat_stream(request, config)
    end
  end

  def text_to_speech(provider_key, request, config) do
    case get_provider(provider_key) do
      nil -> {:error, :unknown_provider}
      mod -> mod.text_to_speech(request, config)
    end
  end

  def poll_task(provider_key, external_id, config) do
    case get_provider(provider_key) do
      nil -> {:error, :unknown_provider}
      mod -> mod.poll_task(external_id, config)
    end
  end
end
