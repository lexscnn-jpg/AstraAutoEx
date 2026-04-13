defmodule AstraAutoEx.AI.Providers.Google do
  @moduledoc """
  Google Official provider — Gemini image, Imagen, Veo video, Gemini LLM.
  Ported 1:1 from original AstraAuto TypeScript implementation.

  Image generation:
  - Gemini 3 Pro Image — generateContent with IMAGE modality
  - Gemini 2.5 Flash Image — generateContent with IMAGE modality
  - Imagen 4 — generateImages endpoint

  Video generation:
  - Veo 3.1 — generateVideos (async, poll via operations)
  - Supports first/last frame, audio generation

  LLM:
  - Gemini 2.5 Flash / Pro — generateContent + streamGenerateContent

  Base URL: https://generativelanguage.googleapis.com
  Auth: key={apiKey} query param
  """
  @behaviour AstraAutoEx.AI.Provider

  @base_url "https://generativelanguage.googleapis.com"

  @impl true
  def capabilities, do: [:image, :video, :llm]

  # ══════════════════════════════════════════
  # Image Generation — Gemini (generateContent + IMAGE modality)
  # ══════════════════════════════════════════

  @impl true
  def generate_image(request, config) do
    api_key = Map.fetch!(config, :api_key)
    model = Map.get(request, :model, "gemini-3-pro-image-preview")

    # Detect Imagen models → use different endpoint
    if String.starts_with?(model, "imagen") do
      generate_imagen(request, api_key, model)
    else
      generate_gemini_image(request, api_key, model)
    end
  end

  defp generate_gemini_image(request, api_key, model) do
    prompt = Map.get(request, :prompt, "")
    reference_images = Map.get(request, :reference_images, [])
    aspect_ratio = Map.get(request, :aspect_ratio)
    resolution = Map.get(request, :resolution)

    # Build content parts: reference images + prompt text
    parts = build_image_parts(reference_images) ++ [%{"text" => prompt}]

    # Safety settings (disable filtering)
    safety_settings = [
      %{"category" => "HARM_CATEGORY_HARASSMENT", "threshold" => "BLOCK_NONE"},
      %{"category" => "HARM_CATEGORY_HATE_SPEECH", "threshold" => "BLOCK_NONE"},
      %{"category" => "HARM_CATEGORY_SEXUALLY_EXPLICIT", "threshold" => "BLOCK_NONE"},
      %{"category" => "HARM_CATEGORY_DANGEROUS_CONTENT", "threshold" => "BLOCK_NONE"}
    ]

    # Image config
    image_config = %{}
    image_config = put_if(image_config, "aspectRatio", aspect_ratio)
    image_config = put_if(image_config, "imageSize", resolution)

    generation_config = %{"responseModalities" => ["TEXT", "IMAGE"]}

    generation_config =
      if map_size(image_config) > 0 do
        Map.put(generation_config, "imageConfig", image_config)
      else
        generation_config
      end

    body = %{
      "contents" => [%{"parts" => parts}],
      "generationConfig" => generation_config,
      "safetySettings" => safety_settings
    }

    url = "#{@base_url}/v1beta/models/#{model}:generateContent?key=#{api_key}"

    case Req.post(url, json: body, receive_timeout: 120_000) do
      {:ok, %{status: 200, body: resp}} ->
        extract_gemini_image(resp)

      {:ok, %{status: status, body: body}} ->
        {:error, %{status: status, body: body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Imagen 4 — generateImages endpoint
  defp generate_imagen(request, api_key, model) do
    prompt = Map.get(request, :prompt, "")
    aspect_ratio = Map.get(request, :aspect_ratio)

    config = %{"numberOfImages" => 1}
    config = put_if(config, "aspectRatio", aspect_ratio)

    body = %{
      "model" => model,
      "prompt" => prompt,
      "config" => config
    }

    url = "#{@base_url}/v1beta/models/#{model}:generateImages?key=#{api_key}"

    case Req.post(url, json: body, receive_timeout: 120_000) do
      {:ok,
       %{status: 200, body: %{"generatedImages" => [%{"image" => %{"imageBytes" => b64}} | _]}}} ->
        {:ok, %{status: :completed, b64_json: b64, image_url: "data:image/png;base64,#{b64}"}}

      {:ok, %{status: 200, body: body}} ->
        {:error, "Imagen returned no image: #{inspect(body)}"}

      {:ok, %{status: status, body: body}} ->
        {:error, %{status: status, body: body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ══════════════════════════════════════════
  # Video Generation — Veo (generateVideos, async)
  # ══════════════════════════════════════════

  @impl true
  def generate_video(request, config) do
    api_key = Map.fetch!(config, :api_key)
    model = Map.get(request, :model, "veo-3.1-generate-preview")
    prompt = Map.get(request, :prompt, "")
    image_url = Map.get(request, :image_url)
    aspect_ratio = Map.get(request, :aspect_ratio)
    resolution = Map.get(request, :resolution)
    duration = Map.get(request, :duration)
    generate_audio = Map.get(request, :generate_audio)
    last_frame_url = Map.get(request, :last_frame_image_url)

    body = %{"model" => model}
    body = if String.trim(prompt) != "", do: Map.put(body, "prompt", prompt), else: body

    # Video generation config
    vconfig = %{}
    vconfig = put_if(vconfig, "aspectRatio", aspect_ratio)
    vconfig = put_if(vconfig, "resolution", resolution)

    vconfig =
      if is_number(duration), do: Map.put(vconfig, "durationSeconds", duration), else: vconfig

    vconfig =
      if is_boolean(generate_audio),
        do: Map.put(vconfig, "generateAudio", generate_audio),
        else: vconfig

    # First frame image (image-to-video)
    body =
      if image_url do
        inline_data = data_url_to_inline_data(image_url)
        if inline_data, do: Map.put(body, "image", inline_data), else: body
      else
        body
      end

    # Last frame (requires image input)
    vconfig =
      if last_frame_url do
        inline_data = data_url_to_inline_data(last_frame_url)
        if inline_data, do: Map.put(vconfig, "lastFrame", inline_data), else: vconfig
      else
        vconfig
      end

    body = if map_size(vconfig) > 0, do: Map.put(body, "config", vconfig), else: body

    url = "#{@base_url}/v1beta/models/#{model}:generateVideos?key=#{api_key}"

    case Req.post(url, json: body, receive_timeout: 60_000) do
      {:ok, %{status: 200, body: resp}} ->
        operation_name = extract_operation_name(resp)

        if operation_name do
          {:ok, %{external_id: "GOOGLE:VIDEO:#{operation_name}", operation_name: operation_name}}
        else
          {:error, "Veo returned no operation name: #{inspect(resp)}"}
        end

      {:ok, %{status: status, body: body}} ->
        {:error, %{status: status, body: body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ══════════════════════════════════════════
  # LLM — Gemini generateContent
  # ══════════════════════════════════════════

  @impl true
  def chat(request, config) do
    api_key = Map.fetch!(config, :api_key)
    model = Map.get(request, :model, "gemini-2.5-flash")
    url = "#{@base_url}/v1beta/models/#{model}:generateContent?key=#{api_key}"

    case Req.post(url, json: request, receive_timeout: 120_000) do
      {:ok, %{status: 200, body: resp}} ->
        text = extract_gemini_text(resp)

        if text != "" do
          {:ok, text}
        else
          finish_reason = get_in(resp, ["candidates", Access.at(0), "finishReason"])

          if finish_reason in ["SAFETY", "PROHIBITED_CONTENT"] do
            {:error, "Content filtered by safety policy"}
          else
            {:error, "Gemini returned empty response (finishReason: #{finish_reason})"}
          end
        end

      {:ok, %{status: status, body: body}} ->
        {:error, %{status: status, body: body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ══════════════════════════════════════════
  # LLM — Gemini streamGenerateContent (SSE)
  # ══════════════════════════════════════════

  @impl true
  def chat_stream(request, config) do
    api_key = Map.fetch!(config, :api_key)
    model = Map.get(request, :model, "gemini-2.5-flash")
    url = "#{@base_url}/v1beta/models/#{model}:streamGenerateContent?alt=sse&key=#{api_key}"

    stream =
      Stream.resource(
        fn -> Req.post!(url, json: request, into: :self, receive_timeout: 300_000) end,
        fn resp ->
          receive do
            {_ref, {:data, data}} ->
              chunks =
                data
                |> String.split("\n")
                |> Enum.filter(&String.starts_with?(&1, "data: "))
                |> Enum.map(&String.trim_leading(&1, "data: "))
                |> Enum.flat_map(fn json_str ->
                  case Jason.decode(json_str) do
                    {:ok, resp} -> [extract_gemini_text(resp)]
                    _ -> []
                  end
                end)
                |> Enum.filter(&(&1 != ""))

              {chunks, resp}

            {_ref, :done} ->
              {:halt, resp}
          after
            300_000 -> {:halt, resp}
          end
        end,
        fn _resp -> :ok end
      )

    {:ok, stream}
  end

  # ══════════════════════════════════════════
  # Async Task Polling (Veo operations)
  # ══════════════════════════════════════════

  @impl true
  def poll_task(operation_name, config) do
    api_key = Map.fetch!(config, :api_key)
    url = "#{@base_url}/v1beta/#{operation_name}?key=#{api_key}"

    case Req.get(url, receive_timeout: 15_000) do
      {:ok, %{status: 200, body: %{"done" => true, "response" => response}}} ->
        video_url =
          get_in(response, [
            "generateVideoResponse",
            "generatedSamples",
            Access.at(0),
            "video",
            "uri"
          ])

        {:ok, %{status: :completed, video_url: video_url, result: response}}

      {:ok, %{status: 200, body: %{"done" => false}}} ->
        {:ok, %{status: :pending}}

      {:ok, %{status: 200, body: %{"error" => error}}} ->
        {:ok, %{status: :failed, error: Map.get(error, "message", "Operation failed")}}

      {:ok, %{body: body}} ->
        {:error, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ══════════════════════════════════════════
  # Helpers
  # ══════════════════════════════════════════

  defp put_if(map, _key, nil), do: map
  defp put_if(map, key, value), do: Map.put(map, key, value)

  # Build inline image parts from reference images (data URLs or raw base64)
  defp build_image_parts(images) when is_list(images) do
    images
    |> Enum.take(14)
    |> Enum.flat_map(fn image_data ->
      cond do
        String.starts_with?(image_data, "data:") ->
          case parse_data_url(image_data) do
            {mime, data} -> [%{"inlineData" => %{"mimeType" => mime, "data" => data}}]
            nil -> []
          end

        String.starts_with?(image_data, "http") ->
          # URL reference — pass as fileData for Gemini
          [%{"fileData" => %{"fileUri" => image_data}}]

        true ->
          # Raw base64
          [%{"inlineData" => %{"mimeType" => "image/png", "data" => image_data}}]
      end
    end)
  end

  defp build_image_parts(_), do: []

  # Parse data URL → {mime_type, base64_data}
  defp parse_data_url(data_url) do
    case String.split(data_url, ";base64,", parts: 2) do
      [header, data] ->
        mime = String.replace_prefix(header, "data:", "")
        {mime, data}

      _ ->
        nil
    end
  end

  # Convert data URL to inline data map for Veo
  defp data_url_to_inline_data(url) do
    if String.starts_with?(url, "data:") do
      case parse_data_url(url) do
        {mime, data} -> %{"mimeType" => mime, "imageBytes" => data}
        nil -> nil
      end
    else
      nil
    end
  end

  # Extract operation name from generateVideos response
  defp extract_operation_name(resp) when is_map(resp) do
    Map.get(resp, "name") ||
      get_in(resp, ["operation", "name"]) ||
      Map.get(resp, "operationName") ||
      Map.get(resp, "id")
  end

  defp extract_operation_name(_), do: nil

  # Extract text from Gemini generateContent response
  defp extract_gemini_text(resp) when is_map(resp) do
    candidates = Map.get(resp, "candidates", [])

    case candidates do
      [first | _] ->
        parts = get_in(first, ["content", "parts"]) || []

        parts
        |> Enum.reject(fn part ->
          # Skip thought/reasoning parts
          Map.get(part, "thought") == true or
            (is_binary(Map.get(part, "type")) and
               String.contains?(String.downcase(Map.get(part, "type", "")), "thought"))
        end)
        |> Enum.map(fn part -> Map.get(part, "text", "") end)
        |> Enum.filter(&is_binary/1)
        |> Enum.join("")

      _ ->
        ""
    end
  end

  defp extract_gemini_text(_), do: ""

  # Extract image from Gemini generateContent response (IMAGE modality)
  defp extract_gemini_image(resp) when is_map(resp) do
    candidates = Map.get(resp, "candidates", [])

    case candidates do
      [first | _] ->
        parts = get_in(first, ["content", "parts"]) || []
        image_part = Enum.find(parts, fn part -> Map.has_key?(part, "inlineData") end)

        if image_part do
          inline = Map.get(image_part, "inlineData", %{})
          b64 = Map.get(inline, "data", "")
          mime = Map.get(inline, "mimeType", "image/png")

          if b64 != "" do
            {:ok, %{status: :completed, b64_json: b64, image_url: "data:#{mime};base64,#{b64}"}}
          else
            check_safety_rejection(first)
          end
        else
          check_safety_rejection(first)
        end

      _ ->
        {:error, "Gemini returned no candidates"}
    end
  end

  defp extract_gemini_image(_), do: {:error, "Invalid response"}

  defp check_safety_rejection(candidate) do
    case Map.get(candidate, "finishReason") do
      reason when reason in ["IMAGE_SAFETY", "SAFETY"] ->
        {:error, "Content filtered by safety policy"}

      _ ->
        {:error, "Gemini returned no image"}
    end
  end
end
