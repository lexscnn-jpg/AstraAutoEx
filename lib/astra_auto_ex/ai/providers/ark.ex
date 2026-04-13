defmodule AstraAutoEx.AI.Providers.Ark do
  @moduledoc """
  ARK (火山引擎) provider — Seedream image, Seedance video, Responses LLM.
  Ported 1:1 from original AstraAuto TypeScript implementation.

  Image models (Seedream):
  - doubao-seedream-4-5-251128 (default)
  - doubao-seedream-5-*  (3K resolution cap)

  Video models (Seedance):
  - doubao-seedance-1-0-pro-fast-251015
  - doubao-seedance-1-0-pro-250528
  - doubao-seedance-1-0-lite-i2v-250428
  - doubao-seedance-1-5-pro-251215
  - doubao-seedance-2-0-260128
  - doubao-seedance-2-0-fast-260128
  - Supports batch mode (-batch suffix → service_tier=flex)
  - Supports first/last frame mode

  LLM: Responses API (ark.cn-beijing.volces.com/api/v3/responses)

  Base URL: https://ark.cn-beijing.volces.com/api/v3
  Auth: Bearer {apiKey}
  """
  @behaviour AstraAutoEx.AI.Provider

  require Logger

  @base_url "https://ark.cn-beijing.volces.com/api/v3"
  @default_timeout 60_000
  @max_retries 3

  # ── Seedance model specs ──
  @seedance_model_specs %{
    "doubao-seedance-1-0-pro-fast-251015" => %{
      duration_min: 2,
      duration_max: 12,
      supports_first_last_frame: false,
      supports_generate_audio: false,
      supports_draft: false,
      supports_frames: true,
      resolution_options: ["480p", "720p", "1080p"]
    },
    "doubao-seedance-1-0-pro-250528" => %{
      duration_min: 2,
      duration_max: 12,
      supports_first_last_frame: true,
      supports_generate_audio: false,
      supports_draft: false,
      supports_frames: true,
      resolution_options: ["480p", "720p", "1080p"]
    },
    "doubao-seedance-1-0-lite-i2v-250428" => %{
      duration_min: 2,
      duration_max: 12,
      supports_first_last_frame: true,
      supports_generate_audio: false,
      supports_draft: false,
      supports_frames: true,
      resolution_options: ["480p", "720p", "1080p"]
    },
    "doubao-seedance-1-5-pro-251215" => %{
      duration_min: 4,
      duration_max: 12,
      supports_first_last_frame: true,
      supports_generate_audio: true,
      supports_draft: true,
      supports_frames: false,
      resolution_options: ["480p", "720p", "1080p"]
    },
    "doubao-seedance-2-0-260128" => %{
      duration_min: 4,
      duration_max: 15,
      supports_first_last_frame: true,
      supports_generate_audio: true,
      supports_draft: false,
      supports_frames: false,
      resolution_options: ["480p", "720p"]
    },
    "doubao-seedance-2-0-fast-260128" => %{
      duration_min: 4,
      duration_max: 15,
      supports_first_last_frame: true,
      supports_generate_audio: true,
      supports_draft: false,
      supports_frames: false,
      resolution_options: ["480p", "720p"]
    }
  }

  # ── 4K size map (Seedream 4.x, ≤ 4096x4096 ≈ 16.7M pixels) ──
  @size_map_4k %{
    "1:1" => "4096x4096",
    "16:9" => "5456x3072",
    "9:16" => "3072x5456",
    "4:3" => "4728x3544",
    "3:4" => "3544x4728",
    "3:2" => "5016x3344",
    "2:3" => "3344x5016",
    "21:9" => "6256x2680",
    "9:21" => "2680x6256"
  }

  # ── 3K size map (Seedream 5.0, ≤ ~10.4M pixels) ──
  @size_map_3k %{
    "1:1" => "3072x3072",
    "16:9" => "4096x2304",
    "9:16" => "2304x4096",
    "4:3" => "3648x2736",
    "3:4" => "2736x3648",
    "3:2" => "3888x2592",
    "2:3" => "2592x3888",
    "21:9" => "4704x2016",
    "9:21" => "2016x4704"
  }

  @impl true
  def capabilities, do: [:image, :video, :llm]

  @doc "Get Seedance model specs for validation."
  def seedance_model_specs, do: @seedance_model_specs

  # ══════════════════════════════════════════
  # Image Generation (Seedream)
  # ══════════════════════════════════════════

  @impl true
  def generate_image(request, config) do
    api_key = Map.fetch!(config, :api_key)
    model_id = Map.get(request, :model, "doubao-seedream-4-5-251128")
    aspect_ratio = Map.get(request, :aspect_ratio)
    direct_size = Map.get(request, :size)

    # Determine size from aspect ratio using model-appropriate map
    size =
      cond do
        direct_size ->
          direct_size

        aspect_ratio ->
          size_map = if seedream5?(model_id), do: @size_map_3k, else: @size_map_4k
          Map.get(size_map, aspect_ratio)

        true ->
          nil
      end

    body = %{
      "model" => model_id,
      "prompt" => Map.get(request, :prompt, ""),
      "sequential_image_generation" => "disabled",
      "response_format" => "url",
      "stream" => false,
      "watermark" => false
    }

    body = put_if(body, "size", size)

    # Reference images for image-to-image
    reference_images = Map.get(request, :reference_images, [])

    body =
      if is_list(reference_images) and length(reference_images) > 0 do
        Map.put(body, "image", reference_images)
      else
        body
      end

    url = "#{@base_url}/images/generations"
    headers = auth_headers(api_key)

    case do_request(:post, url, body, headers) do
      {:ok, %{"data" => data}} when is_list(data) ->
        image_urls =
          data
          |> Enum.map(fn item -> Map.get(item, "url", "") end)
          |> Enum.filter(fn url -> String.length(url) > 0 end)

        case image_urls do
          [image_url | _] ->
            {:ok, %{status: :completed, image_url: image_url, image_urls: image_urls}}

          [] ->
            {:error, "ARK returned no image URL"}
        end

      {:ok, body} ->
        {:error, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ══════════════════════════════════════════
  # Video Generation (Seedance)
  # ══════════════════════════════════════════

  @impl true
  def generate_video(request, config) do
    api_key = Map.fetch!(config, :api_key)
    model_id = Map.get(request, :model, "doubao-seedance-1-0-pro-fast-251015")
    image_url = Map.get(request, :image_url, "")
    prompt = Map.get(request, :prompt, "")

    # Parse batch mode
    is_batch = String.ends_with?(model_id, "-batch")
    real_model = if is_batch, do: String.replace_suffix(model_id, "-batch", ""), else: model_id

    # Build content array
    content = []

    content =
      if String.trim(prompt) != "",
        do: content ++ [%{"type" => "text", "text" => prompt}],
        else: content

    last_frame_url = Map.get(request, :last_frame_image_url)

    content =
      if last_frame_url do
        # First/last frame mode
        content ++
          [
            %{
              "type" => "image_url",
              "image_url" => %{"url" => image_url},
              "role" => "first_frame"
            },
            %{
              "type" => "image_url",
              "image_url" => %{"url" => last_frame_url},
              "role" => "last_frame"
            }
          ]
      else
        content ++ [%{"type" => "image_url", "image_url" => %{"url" => image_url}}]
      end

    body = %{"model" => real_model, "content" => content}

    body = put_if(body, "resolution", Map.get(request, :resolution))
    body = put_if(body, "ratio", Map.get(request, :aspect_ratio))
    body = put_if(body, "duration", Map.get(request, :duration))
    body = put_if(body, "frames", Map.get(request, :frames))
    body = put_if(body, "seed", Map.get(request, :seed))
    body = put_if(body, "camera_fixed", Map.get(request, :camera_fixed))
    body = put_if(body, "watermark", Map.get(request, :watermark))
    body = put_if(body, "return_last_frame", Map.get(request, :return_last_frame))
    body = put_if(body, "draft", Map.get(request, :draft))
    body = put_if(body, "generate_audio", Map.get(request, :generate_audio))
    body = put_if(body, "service_tier", Map.get(request, :service_tier))
    body = put_if(body, "execution_expires_after", Map.get(request, :execution_expires_after))

    # Batch mode overrides
    body =
      if is_batch do
        body
        |> Map.put("service_tier", "flex")
        |> Map.put_new("execution_expires_after", 86400)
      else
        body
      end

    url = "#{@base_url}/contents/generations/tasks"
    headers = auth_headers(api_key)

    case do_request(:post, url, body, headers) do
      {:ok, %{"id" => task_id}} ->
        {:ok, %{external_id: "ARK:VIDEO:#{task_id}", task_id: task_id}}

      {:ok, body} ->
        {:error, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ══════════════════════════════════════════
  # LLM — Responses API
  # ══════════════════════════════════════════

  @impl true
  def chat(request, config) do
    api_key = Map.fetch!(config, :api_key)
    model = Map.get(request, :model, "doubao-1-5-thinking-pro-250415")
    input = Map.get(request, :input, Map.get(request, :messages, []))

    body = %{"model" => model, "input" => input}
    body = put_if(body, "thinking", Map.get(request, :thinking))
    body = put_if(body, "temperature", Map.get(request, :temperature))

    url = "#{@base_url}/responses"
    headers = auth_headers(api_key)

    case do_request(:post, url, body, headers) do
      {:ok, data} ->
        text = extract_ark_text(data)
        {:ok, text}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ══════════════════════════════════════════
  # Async Task Polling
  # ══════════════════════════════════════════

  @impl true
  def poll_task(task_id, config) do
    api_key = Map.fetch!(config, :api_key)
    url = "#{@base_url}/contents/generations/tasks/#{task_id}"
    headers = [{"authorization", "Bearer #{api_key}"}]

    case Req.get(url, headers: headers, receive_timeout: 15_000) do
      {:ok, %{status: 200, body: %{"status" => "succeeded"} = data}} ->
        video_url = extract_content_url(data, "video_url")
        {:ok, %{status: :completed, video_url: video_url, result: data}}

      {:ok, %{status: 200, body: %{"status" => status}}}
      when status in ["processing", "queued", "running"] ->
        {:ok, %{status: :pending}}

      {:ok, %{status: 200, body: %{"status" => "failed", "error" => error}}} ->
        error_msg = extract_error_message(error)
        {:ok, %{status: :failed, error: error_msg}}

      {:ok, %{status: 200, body: %{"status" => "failed"} = body}} ->
        {:ok, %{status: :failed, error: Map.get(body, "message", "Task failed")}}

      {:ok, %{body: body}} ->
        {:error, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ══════════════════════════════════════════
  # Helpers
  # ══════════════════════════════════════════

  defp auth_headers(api_key) do
    [{"authorization", "Bearer #{api_key}"}, {"content-type", "application/json"}]
  end

  defp seedream5?(model_id), do: String.contains?(model_id, "seedream-5")

  defp put_if(map, _key, nil), do: map
  defp put_if(map, key, value), do: Map.put(map, key, value)

  # HTTP request with retry (exponential backoff, max 3 retries)
  defp do_request(method, url, body, headers, attempt \\ 1) do
    req_opts = [
      method: method,
      url: url,
      headers: headers,
      receive_timeout: @default_timeout
    ]

    req_opts = if body, do: Keyword.put(req_opts, :json, body), else: req_opts

    case Req.request(req_opts) do
      {:ok, %{status: status, body: resp_body}} when status in 200..299 ->
        {:ok, resp_body}

      {:ok, %{status: status}}
      when status in [408, 429, 500, 502, 503, 504] and attempt < @max_retries ->
        delay = (2000 * :math.pow(2, attempt - 1)) |> trunc()
        Logger.warning("[ARK] Retry #{attempt}/#{@max_retries} after #{delay}ms (HTTP #{status})")
        Process.sleep(delay)
        do_request(method, url, body, headers, attempt + 1)

      {:ok, %{status: status, body: resp_body}} ->
        {:error, %{status: status, body: resp_body}}

      {:error, reason} when attempt < @max_retries ->
        delay = (2000 * :math.pow(2, attempt - 1)) |> trunc()

        Logger.warning(
          "[ARK] Retry #{attempt}/#{@max_retries} after #{delay}ms (#{inspect(reason)})"
        )

        Process.sleep(delay)
        do_request(method, url, body, headers, attempt + 1)

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Extract text from Responses API output
  defp extract_ark_text(data) when is_map(data) do
    cond do
      is_binary(Map.get(data, "output_text")) ->
        Map.get(data, "output_text")

      true ->
        output = Map.get(data, "output", Map.get(data, "outputs", []))
        collect_text(output)
    end
  end

  defp extract_ark_text(_), do: ""

  defp collect_text(items) when is_list(items) do
    items
    |> Enum.map(&collect_text/1)
    |> Enum.filter(&(&1 != ""))
    |> Enum.join("")
  end

  defp collect_text(%{"type" => type}) when type in ["reasoning", "function_call"], do: ""
  defp collect_text(%{"output_text" => text}) when is_binary(text), do: text

  defp collect_text(%{"text" => text, "type" => type})
       when is_binary(text) and type != "reasoning", do: text

  defp collect_text(%{"text" => text}) when is_binary(text), do: text
  defp collect_text(%{"content" => content}) when is_binary(content), do: content
  defp collect_text(%{"content" => content}), do: collect_text(content)
  defp collect_text(_), do: ""

  # Extract video/image URL from task result content
  defp extract_content_url(%{"content" => content}, key) when is_map(content) do
    Map.get(content, key)
  end

  defp extract_content_url(%{"content" => content}, key) when is_list(content) do
    Enum.find_value(content, fn
      %{^key => %{"url" => url}} -> url
      _ -> nil
    end)
  end

  defp extract_content_url(_, _), do: nil

  # Extract friendly error message
  defp extract_error_message(%{"code" => "OutputVideoSensitiveContentDetected"}),
    do: "Video generation failed: content moderation rejected"

  defp extract_error_message(%{"code" => "InputImageSensitiveContentDetected"}),
    do: "Video generation failed: input image moderation rejected"

  defp extract_error_message(%{"message" => msg}) when is_binary(msg), do: msg
  defp extract_error_message(error) when is_map(error), do: inspect(error)
  defp extract_error_message(_), do: "Task failed"
end
