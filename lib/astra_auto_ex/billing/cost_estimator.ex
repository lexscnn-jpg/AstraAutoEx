defmodule AstraAutoEx.Billing.CostEstimator do
  @moduledoc """
  Pre-task cost estimation based on model pricing tables.
  Provides estimated costs before running generation tasks.
  """

  # Pricing per unit (approximate, in USD cents)
  @llm_prices %{
    "gemini-2.5-flash" => %{input: 0.015, output: 0.06},
    "gemini-3.1-pro-preview" => %{input: 0.125, output: 0.50},
    "claude-sonnet-4.5" => %{input: 0.30, output: 1.50},
    "claude-opus-4-6" => %{input: 1.50, output: 7.50},
    "gpt-4o" => %{input: 0.25, output: 1.00}
  }

  # Per-image pricing (cents)
  @image_prices %{
    "image-01" => 4.0,
    "nano-banana-2" => 2.0,
    "nano-banana-pro" => 3.0,
    "seedream-4.0" => 3.5,
    "seedream-4.5" => 5.0,
    "imagen-4.0" => 4.0,
    "imagen-ultra" => 8.0
  }

  # Per-video pricing (cents, ~5s clip)
  @video_prices %{
    "minimax-hailuo-2.3" => 15.0,
    "seedance-2.0" => 20.0,
    "seedance-2.0-fast" => 12.0,
    "seedance-1.5-pro" => 18.0,
    "seedance-1.0-pro" => 10.0,
    "veo-3.1-fast" => 25.0,
    "kling-2.5-turbo-pro" => 15.0,
    "wan-2.6" => 12.0
  }

  # Per-request TTS pricing (cents, ~10s audio)
  @voice_prices %{
    "speech-2.8-hd" => 1.5,
    "speech-2.5" => 1.0
  }

  @doc "Estimate cost for a batch of image generation tasks."
  def estimate_images(model, count) do
    price = Map.get(@image_prices, model, 4.0)
    %{model: model, count: count, unit_cost: price, total: price * count, currency: "cents"}
  end

  @doc "Estimate cost for a batch of video generation tasks."
  def estimate_videos(model, count) do
    price = Map.get(@video_prices, model, 15.0)
    %{model: model, count: count, unit_cost: price, total: price * count, currency: "cents"}
  end

  @doc "Estimate cost for a batch of TTS tasks."
  def estimate_voices(model, count) do
    price = Map.get(@voice_prices, model, 1.5)
    %{model: model, count: count, unit_cost: price, total: price * count, currency: "cents"}
  end

  @doc "Estimate cost for an LLM call based on approximate token counts."
  def estimate_llm(model, input_tokens, output_tokens \\ 2000) do
    prices = Map.get(@llm_prices, model, %{input: 0.10, output: 0.40})
    input_cost = input_tokens / 1000 * prices.input
    output_cost = output_tokens / 1000 * prices.output
    total = input_cost + output_cost

    %{
      model: model,
      input_tokens: input_tokens,
      output_tokens: output_tokens,
      input_cost: Float.round(input_cost, 4),
      output_cost: Float.round(output_cost, 4),
      total: Float.round(total, 4),
      currency: "cents"
    }
  end

  @doc "Estimate total pipeline cost for an episode."
  def estimate_episode(panel_count, voice_line_count, opts \\ []) do
    image_model = Keyword.get(opts, :image_model, "image-01")
    video_model = Keyword.get(opts, :video_model, "minimax-hailuo-2.3")
    voice_model = Keyword.get(opts, :voice_model, "speech-2.8-hd")
    llm_model = Keyword.get(opts, :llm_model, "gemini-2.5-flash")

    images = estimate_images(image_model, panel_count)
    videos = estimate_videos(video_model, panel_count)
    voices = estimate_voices(voice_model, voice_line_count)
    # Approximate: story analysis ~3k tokens input, storyboard ~5k
    llm = estimate_llm(llm_model, 8000, 4000)

    total = images.total + videos.total + voices.total + llm.total

    %{
      images: images,
      videos: videos,
      voices: voices,
      llm: llm,
      total: Float.round(total, 2),
      currency: "cents"
    }
  end

  @doc "Format cost as human-readable string."
  def format_cost(cents) when is_number(cents) do
    if cents >= 100 do
      "$#{Float.round(cents / 100, 2)}"
    else
      "#{Float.round(cents * 1.0, 1)}¢"
    end
  end
end
