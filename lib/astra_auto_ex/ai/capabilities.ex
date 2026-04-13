defmodule AstraAutoEx.AI.Capabilities do
  @moduledoc """
  Model capability registry. Maps model names to providers and capabilities.
  """

  @models %{
    # FAL models
    "flux-pro" => %{provider: "fal", type: :image},
    "flux-dev" => %{provider: "fal", type: :image},
    "flux-schnell" => %{provider: "fal", type: :image},
    "kling-v1" => %{provider: "fal", type: :video},
    "kling-v1.5" => %{provider: "fal", type: :video},
    "kling-v2" => %{provider: "fal", type: :video},
    "kling-v2.5" => %{provider: "fal", type: :video},
    # ARK models
    "seedream-3" => %{provider: "ark", type: :image},
    "seedream-4k" => %{provider: "ark", type: :image},
    "seedream-5k" => %{provider: "ark", type: :image},
    "seedance-1.0" => %{provider: "ark", type: :video},
    "seedance-1.5" => %{provider: "ark", type: :video},
    "seedance-2.0" => %{provider: "ark", type: :video},
    # Google models
    "imagen-3" => %{provider: "google", type: :image},
    "imagen-4" => %{provider: "google", type: :image},
    "gemini-2.0-flash" => %{provider: "google", type: :llm},
    "gemini-2.5-pro" => %{provider: "google", type: :llm},
    "gemini-2.5-flash" => %{provider: "google", type: :llm},
    "veo-2" => %{provider: "google", type: :video},
    "veo-3" => %{provider: "google", type: :video},
    # MiniMax models
    "hailuo-2.3" => %{provider: "minimax", type: :video},
    "hailuo-02" => %{provider: "minimax", type: :video},
    "speech-02-hd" => %{provider: "minimax", type: :tts},
    "music-01" => %{provider: "minimax", type: :music},
    # API易 models
    "veo-3.1-fast" => %{provider: "apiyi", type: :video},
    "veo-3.1" => %{provider: "apiyi", type: :video}
  }

  def get_model(model_name), do: Map.get(@models, model_name)

  def provider_for(model_name) do
    case get_model(model_name) do
      %{provider: p} -> p
      nil -> nil
    end
  end

  def type_for(model_name) do
    case get_model(model_name) do
      %{type: t} -> t
      nil -> nil
    end
  end

  def list_models(provider \\ nil) do
    if provider do
      @models |> Enum.filter(fn {_, v} -> v.provider == provider end) |> Map.new()
    else
      @models
    end
  end
end
