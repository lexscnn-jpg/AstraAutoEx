defmodule AstraAutoEx.AI.Providers.Fal do
  @moduledoc """
  FAL provider — unified image + video generation via Queue API.
  Ported 1:1 from original AstraAuto TypeScript implementation.

  Image models:
  - Banana Pro (2K/4K) — fal-ai/nano-banana-pro       (modelId: 'banana')
  - Banana 2  (1K/2K/4K) — fal-ai/nano-banana-2       (modelId: 'banana-2')

  Video models:
  - Wan 2.6 (fal-wan25) — wan/v2.6/image-to-video
  - Veo 3.1 (fal-veo31) — fal-ai/veo3.1/fast/image-to-video
  - Sora 2 (fal-sora2) — fal-ai/sora-2/image-to-video
  - Kling 2.5 Turbo Pro — fal-ai/kling-video/v2.5-turbo/pro/image-to-video
  - Kling 3 Standard — fal-ai/kling-video/v3/standard/image-to-video
  - Kling 3 Pro — fal-ai/kling-video/v3/pro/image-to-video

  Queue flow:
    POST queue.fal.run/{endpoint} → request_id
    GET  queue.fal.run/{owner}/{alias}/requests/{id}/status → status
    GET  response_url → result (images/video/audio)
  """
  @behaviour AstraAutoEx.AI.Provider

  @default_base_url "https://queue.fal.run"

  # ── Image endpoint mapping (modelId → FAL endpoint) ──
  @image_endpoints %{
    "banana" => %{base: "fal-ai/nano-banana-pro", edit: "fal-ai/nano-banana-pro/edit"},
    "banana-2" => %{base: "fal-ai/nano-banana-2", edit: "fal-ai/nano-banana-2/edit"}
  }

  # ── Video endpoint mapping ──
  @video_endpoints %{
    "fal-wan25" => "wan/v2.6/image-to-video",
    "fal-veo31" => "fal-ai/veo3.1/fast/image-to-video",
    "fal-sora2" => "fal-ai/sora-2/image-to-video",
    "fal-ai/kling-video/v2.5-turbo/pro/image-to-video" =>
      "fal-ai/kling-video/v2.5-turbo/pro/image-to-video",
    "fal-ai/kling-video/v3/standard/image-to-video" =>
      "fal-ai/kling-video/v3/standard/image-to-video",
    "fal-ai/kling-video/v3/pro/image-to-video" => "fal-ai/kling-video/v3/pro/image-to-video"
  }

  @impl true
  def capabilities, do: [:image, :video]

  defp base_url(config), do: Map.get(config, :base_url, @default_base_url)

  # ══════════════════════════════════════════
  # Image Generation (Banana Pro / Banana 2)
  # ══════════════════════════════════════════

  @impl true
  def generate_image(request, config) do
    api_key = Map.fetch!(config, :api_key)
    model_id = Map.get(request, :model_id, "banana")
    reference_images = Map.get(request, :reference_images, [])
    has_refs = is_list(reference_images) and length(reference_images) > 0

    # Select endpoint: edit variant when reference images present
    endpoint_config = Map.get(@image_endpoints, model_id, @image_endpoints["banana"])
    endpoint = if has_refs, do: endpoint_config.edit, else: endpoint_config.base

    body = %{
      "prompt" => Map.get(request, :prompt, ""),
      "num_images" => 1,
      "output_format" => Map.get(request, :output_format, "png")
    }

    body = put_if(body, "aspect_ratio", Map.get(request, :aspect_ratio))
    body = put_if(body, "resolution", Map.get(request, :resolution))

    # Add reference images as data URLs
    body =
      if has_refs do
        Map.put(body, "image_urls", reference_images)
      else
        body
      end

    url = build_queue_url(config, endpoint)
    headers = auth_headers(api_key)

    case Req.post(url, headers: headers, json: body, receive_timeout: 60_000) do
      {:ok, %{status: s, body: %{"request_id" => request_id}}} when s in 200..299 ->
        {:ok,
         %{
           external_id: "FAL:IMAGE:#{endpoint}:#{request_id}",
           request_id: request_id,
           endpoint: endpoint
         }}

      {:ok, %{status: status, body: resp_body}} ->
        {:error, %{status: status, body: resp_body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ══════════════════════════════════════════
  # Video Generation (Wan/Veo/Sora/Kling)
  # ══════════════════════════════════════════

  @impl true
  def generate_video(request, config) do
    api_key = Map.fetch!(config, :api_key)
    model_id = Map.get(request, :model_id, "fal-wan25")
    image_url = Map.get(request, :image_url, "")
    prompt = Map.get(request, :prompt, "")

    endpoint = Map.get(@video_endpoints, model_id)
    unless endpoint, do: raise("FAL_VIDEO_MODEL_UNSUPPORTED: #{model_id}")

    # Build per-model input body
    input = build_video_input(model_id, image_url, prompt, request)

    url = build_queue_url(config, endpoint)
    headers = auth_headers(api_key)

    case Req.post(url, headers: headers, json: input, receive_timeout: 60_000) do
      {:ok, %{status: s, body: %{"request_id" => request_id}}} when s in 200..299 ->
        {:ok,
         %{
           external_id: "FAL:VIDEO:#{endpoint}:#{request_id}",
           request_id: request_id,
           endpoint: endpoint
         }}

      {:ok, %{status: status, body: resp_body}} ->
        {:error, %{status: status, body: resp_body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ══════════════════════════════════════════
  # Async Task Polling
  # ══════════════════════════════════════════

  @impl true
  def poll_task(request_id, config) do
    api_key = Map.fetch!(config, :api_key)
    endpoint = Map.get(config, :endpoint, "")

    # Parse endpoint: owner/alias (ignore path for status query)
    {owner, alias_name} = parse_fal_endpoint(endpoint)
    base_endpoint = "#{owner}/#{alias_name}"

    status_url = build_queue_url(config, "#{base_endpoint}/requests/#{request_id}/status?logs=0")
    headers = [{"authorization", "Key #{api_key}"}]

    case Req.get(status_url, headers: headers, receive_timeout: 15_000) do
      {:ok, %{status: 200, body: %{"status" => "COMPLETED"} = data}} ->
        # Fetch result from response_url or constructed URL
        result_url =
          Map.get(data, "response_url") ||
            build_queue_url(config, "#{endpoint}/requests/#{request_id}")

        fetch_fal_result(result_url, api_key)

      {:ok, %{status: 200, body: %{"status" => status}}}
      when status in ["IN_QUEUE", "IN_PROGRESS"] ->
        {:ok, %{status: :pending}}

      {:ok, %{status: 200, body: %{"status" => "FAILED"} = data}} ->
        {:ok, %{status: :failed, error: Map.get(data, "error", "Task failed")}}

      {:ok, %{body: body}} ->
        {:error, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ══════════════════════════════════════════
  # Per-model Video Input Builders
  # ══════════════════════════════════════════

  defp build_video_input("fal-wan25", image_url, prompt, request) do
    input = %{"image_url" => image_url, "prompt" => prompt}
    input = put_if(input, "resolution", Map.get(request, :resolution))
    duration = Map.get(request, :duration)
    if is_number(duration), do: Map.put(input, "duration", to_string(duration)), else: input
  end

  defp build_video_input("fal-veo31", image_url, prompt, request) do
    input = %{"image_url" => image_url, "prompt" => prompt, "generate_audio" => false}
    input = put_if(input, "aspect_ratio", Map.get(request, :aspect_ratio))
    duration = Map.get(request, :duration)
    if is_number(duration), do: Map.put(input, "duration", "#{duration}s"), else: input
  end

  defp build_video_input("fal-sora2", image_url, prompt, request) do
    input = %{"image_url" => image_url, "prompt" => prompt, "delete_video" => false}
    input = put_if(input, "aspect_ratio", Map.get(request, :aspect_ratio))
    input = put_if(input, "duration", Map.get(request, :duration))
    input
  end

  defp build_video_input(
         "fal-ai/kling-video/v2.5-turbo/pro/image-to-video",
         image_url,
         prompt,
         request
       ) do
    input = %{
      "image_url" => image_url,
      "prompt" => prompt,
      "negative_prompt" => "blur, distort, and low quality",
      "cfg_scale" => 0.5
    }

    duration = Map.get(request, :duration)
    if is_number(duration), do: Map.put(input, "duration", to_string(duration)), else: input
  end

  # Kling 3 Standard + Pro share the same input format
  defp build_video_input("fal-ai/kling-video/v3/" <> _, image_url, prompt, request) do
    input = %{
      "start_image_url" => image_url,
      "prompt" => prompt,
      "generate_audio" => false
    }

    input = put_if(input, "aspect_ratio", Map.get(request, :aspect_ratio))
    duration = Map.get(request, :duration)
    if is_number(duration), do: Map.put(input, "duration", to_string(duration)), else: input
  end

  defp build_video_input(_model_id, image_url, prompt, _request) do
    %{"image_url" => image_url, "prompt" => prompt}
  end

  # ══════════════════════════════════════════
  # Helpers
  # ══════════════════════════════════════════

  defp build_queue_url(config, path) do
    normalized = String.replace_leading(path, "/", "")
    "#{base_url(config)}/#{normalized}"
  end

  defp auth_headers(api_key) do
    [{"authorization", "Key #{api_key}"}, {"content-type", "application/json"}]
  end

  # Parse FAL endpoint: "fal-ai/veo3.1/fast/image-to-video" → {"fal-ai", "veo3.1"}
  defp parse_fal_endpoint(endpoint) do
    parts = String.split(endpoint, "/")
    owner = Enum.at(parts, 0, "")
    alias_name = Enum.at(parts, 1, "")
    {owner, alias_name}
  end

  defp fetch_fal_result(result_url, api_key) do
    headers = [{"authorization", "Key #{api_key}"}, {"accept", "application/json"}]

    case Req.get(result_url, headers: headers, receive_timeout: 30_000) do
      {:ok, %{status: 200, body: result}} ->
        # Extract URL from result: video > audio > image
        url =
          get_in(result, ["video", "url"]) ||
            get_in(result, ["audio", "url"]) ||
            get_in(result, ["images", Access.at(0), "url"])

        if url do
          {:ok, %{status: :completed, result_url: url, result: result}}
        else
          {:ok, %{status: :completed, result: result}}
        end

      {:ok, %{status: 422, body: body}} ->
        # Content policy violation or expired result
        {:ok,
         %{status: :failed, error: "Content policy violation or expired result: #{inspect(body)}"}}

      {:ok, %{status: 500, body: body}} ->
        {:ok, %{status: :failed, error: "Downstream service error: #{inspect(body)}"}}

      {:ok, %{body: body}} ->
        {:error, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp put_if(map, _key, nil), do: map
  defp put_if(map, key, value), do: Map.put(map, key, value)
end
