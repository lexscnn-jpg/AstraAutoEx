defmodule AstraAutoEx.AI.Providers.Apiyi do
  @moduledoc """
  API易 provider — three independent channels (ported 1:1 from original AstraAuto):

  1. LLM: OpenAI-compatible POST /v1/chat/completions
  2. Image: Google GenAI SDK — base_url without /v1, SDK appends /v1beta/models/...
  3. Video: VEO 3.1 async — POST /v1/videos, GET /v1/videos/{id}

  Video generation (VEO 3.1):
  - Text-to-video: POST /v1/videos, JSON body {model, prompt}
  - Image-to-video: POST /v1/videos, multipart/form-data with model, prompt, input_reference (File)
  - If image provided with non -fl model -> auto-upgrade to -fl variant
  - Landscape ratios (16:9, 3:2, 21:9) -> auto-add -landscape to model name
  - 8 model variants: veo-3.1, veo-3.1-landscape, veo-3.1-fast, veo-3.1-landscape-fast,
    + 4 -fl variants (veo-3.1-fl, veo-3.1-landscape-fl, veo-3.1-fast-fl, veo-3.1-landscape-fast-fl)

  APIYI VEO interface specifics (differs from Google direct):
  - Aspect ratio controlled via model name (-landscape), no aspect_ratio parameter
  - Audio included automatically, no generate_audio parameter
  - Fixed 8 second duration, no duration parameter
  - Image-to-video requires -fl model + multipart/form-data
  """
  @behaviour AstraAutoEx.AI.Provider

  require Logger

  @default_base_url "https://api.apiyi.com/v1"

  @impl true
  def capabilities, do: [:image, :video, :llm]

  defp base_url(config), do: Map.get(config, :base_url, @default_base_url)

  # ══════════════════════════════════════════
  # Channel 1: LLM (OpenAI-compatible)
  # ══════════════════════════════════════════

  @impl true
  def chat(request, config) do
    api_key = Map.fetch!(config, :api_key)
    url = "#{base_url(config)}/chat/completions"
    headers = [{"authorization", "Bearer #{api_key}"}, {"content-type", "application/json"}]

    body = %{
      "model" => Map.get(request, :model, "gemini-3.1-pro-preview"),
      "messages" => Map.get(request, :messages, []),
      "temperature" => Map.get(request, :temperature, 0.7),
      "max_tokens" => Map.get(request, :max_tokens, 4096)
    }

    case Req.post(url, headers: headers, json: body, receive_timeout: 120_000) do
      {:ok, %{status: 200, body: %{"choices" => [%{"message" => %{"content" => text}} | _]}}} ->
        {:ok, text}

      {:ok, %{body: body}} ->
        {:error, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def chat_stream(request, config) do
    api_key = Map.fetch!(config, :api_key)
    url = "#{base_url(config)}/chat/completions"
    headers = [{"authorization", "Bearer #{api_key}"}, {"content-type", "application/json"}]
    body = Map.merge(request, %{stream: true})

    stream =
      Stream.resource(
        fn ->
          Req.post!(url, headers: headers, json: body, into: :self, receive_timeout: 300_000)
        end,
        fn resp ->
          receive do
            {_ref, {:data, data}} -> {parse_sse_chunks(data), resp}
            {_ref, :done} -> {:halt, resp}
          after
            300_000 -> {:halt, resp}
          end
        end,
        fn _resp -> :ok end
      )

    {:ok, stream}
  end

  # ══════════════════════════════════════════
  # Channel 2: Image (Google GenAI SDK path)
  # base_url removes /v1 -> SDK appends /v1beta/models/{model}:generateContent
  # ══════════════════════════════════════════

  @impl true
  def generate_image(request, config) do
    api_key = Map.fetch!(config, :api_key)
    # Derive Google SDK base URL: remove trailing /v1
    gemini_base = base_url(config) |> String.replace(~r"/v1/?$", "")
    model = Map.get(request, :model, "gemini-3.1-flash-image-preview")
    url = "#{gemini_base}/v1beta/models/#{model}:generateContent"

    prompt = Map.get(request, :prompt, "")
    parts = [%{"text" => prompt}]

    # Add reference images as inline data if present
    parts =
      case Map.get(request, :reference_images) do
        nil ->
          parts

        refs when is_list(refs) ->
          ref_parts =
            Enum.take(refs, 14)
            |> Enum.map(fn ref ->
              %{
                "inline_data" => %{
                  "mime_type" => Map.get(ref, :mime_type, "image/png"),
                  "data" => ref.data
                }
              }
            end)

          parts ++ ref_parts

        _ ->
          parts
      end

    body = %{
      "contents" => [%{"parts" => parts}],
      "generationConfig" => %{
        "responseModalities" => ["IMAGE"],
        "imageConfig" => %{
          "aspectRatio" => Map.get(request, :aspect_ratio, "1:1")
        }
      },
      "safetySettings" => [
        %{"category" => "HARM_CATEGORY_HARASSMENT", "threshold" => "BLOCK_NONE"},
        %{"category" => "HARM_CATEGORY_HATE_SPEECH", "threshold" => "BLOCK_NONE"},
        %{"category" => "HARM_CATEGORY_SEXUALLY_EXPLICIT", "threshold" => "BLOCK_NONE"},
        %{"category" => "HARM_CATEGORY_DANGEROUS_CONTENT", "threshold" => "BLOCK_NONE"}
      ]
    }

    headers = [{"x-goog-api-key", api_key}, {"content-type", "application/json"}]

    case Req.post(url, headers: headers, json: body, receive_timeout: 90_000) do
      {:ok, %{status: 200, body: resp}} ->
        # Extract image from candidates[0].content.parts[].inlineData
        image_data = extract_image_from_gemini_response(resp)

        case image_data do
          {:ok, data} -> {:ok, %{status: :completed, image_data: data}}
          :error -> {:error, "No image in response"}
        end

      {:ok, %{body: body}} ->
        {:error, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ══════════════════════════════════════════
  # Channel 3: Video (VEO 3.1 Async)
  # POST /v1/videos -> async task_id
  # GET /v1/videos/{id} -> poll status
  #
  # Text-to-video: JSON body {model, prompt}
  # Image-to-video: multipart/form-data {model, prompt, input_reference}
  # ══════════════════════════════════════════

  @impl true
  def generate_video(request, config) do
    api_key = Map.fetch!(config, :api_key)
    url = "#{base_url(config)}/videos"

    # Apply model name transformations (landscape + fl auto-upgrade)
    model = transform_veo_model(request)
    prompt = Map.get(request, :prompt, "")

    # Determine if we have a reference image for image-to-video
    input_ref = resolve_input_reference(request)
    last_frame_ref = resolve_last_frame_reference(request)

    # Use frame mode when model is -fl and we have an image
    use_frame_mode = is_veo_frame_model?(model) and input_ref != nil

    if use_frame_mode do
      submit_multipart_video(url, api_key, model, prompt, input_ref, last_frame_ref)
    else
      submit_json_video(url, api_key, model, prompt)
    end
  end

  # Text-to-video: JSON body with only model + prompt
  defp submit_json_video(url, api_key, model, prompt) do
    headers = [{"authorization", "Bearer #{api_key}"}, {"content-type", "application/json"}]
    body = %{"model" => model, "prompt" => prompt}

    case Req.post(url, headers: headers, json: body, receive_timeout: 60_000) do
      {:ok, %{status: s, body: %{"id" => video_id}}} when s in 200..299 ->
        build_video_ok(video_id)

      {:ok, %{status: status, body: body}} ->
        Logger.warning("[Apiyi] Video create failed: HTTP #{status} #{inspect(body)}")
        {:error, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Image-to-video: multipart/form-data with model, prompt, input_reference file(s)
  defp submit_multipart_video(url, api_key, model, prompt, input_ref, last_frame_ref) do
    headers = [
      {"authorization", "Bearer #{api_key}"},
      {"accept", "application/json"}
    ]

    # Build multipart form parts; filter out nils from failed image resolution
    form_parts =
      [
        {"model", model},
        {"prompt", prompt},
        build_file_part("input_reference", input_ref, "input-reference.png"),
        if(last_frame_ref,
          do: build_file_part("input_reference", last_frame_ref, "last-frame-reference.png")
        )
      ]
      |> Enum.reject(&is_nil/1)

    case Req.post(url,
           headers: headers,
           form_multipart: form_parts,
           receive_timeout: 120_000
         ) do
      {:ok, %{status: s, body: %{"id" => video_id}}} when s in 200..299 ->
        build_video_ok(video_id)

      {:ok, %{status: status, body: body}} ->
        Logger.warning("[Apiyi] Video create (multipart) failed: HTTP #{status} #{inspect(body)}")
        {:error, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_video_ok(video_id) do
    provider_token = Base.url_encode64("apiyi", padding: false)
    {:ok, %{external_id: "OPENAI:VIDEO:#{provider_token}:#{video_id}", video_id: video_id}}
  end

  @impl true
  def poll_task(video_id, config) do
    api_key = Map.fetch!(config, :api_key)
    url = "#{base_url(config)}/videos/#{URI.encode(video_id)}"
    headers = [{"authorization", "Bearer #{api_key}"}]

    case Req.get(url, headers: headers, receive_timeout: 15_000) do
      {:ok, %{status: 200, body: %{"status" => "completed"} = task}} ->
        video_url = Map.get(task, "video_url", "") |> String.trim()

        if video_url != "" do
          {:ok, %{status: :completed, video_url: video_url}}
        else
          # Fallback: content endpoint
          content_url = "#{base_url(config)}/videos/#{URI.encode(video_id)}/content"

          {:ok,
           %{
             status: :completed,
             video_url: content_url,
             download_headers: %{"authorization" => "Bearer #{api_key}"}
           }}
        end

      {:ok, %{status: 200, body: %{"status" => status}}}
      when status in ["queued", "in_progress", "processing"] ->
        {:ok, %{status: :pending}}

      {:ok, %{status: 200, body: %{"status" => "failed"} = task}} ->
        error = get_in(task, ["error", "message"]) || Map.get(task, "error", "Failed")
        {:ok, %{status: :failed, error: error}}

      {:ok, %{body: body}} ->
        {:error, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ══════════════════════════════════════════
  # VEO Model Name Transformations
  # ══════════════════════════════════════════

  @landscape_ratios ["16:9", "3:2", "21:9"]

  @doc false
  def transform_veo_model(request) do
    model = Map.get(request, :model, "veo-3.1-fast")
    aspect_ratio = Map.get(request, :aspect_ratio, "9:16")

    has_ref = has_reference_image?(request)

    # Auto-insert -landscape for landscape aspect ratios
    model =
      if landscape?(aspect_ratio) and not String.contains?(model, "-landscape") do
        String.replace(model, "veo-3.1", "veo-3.1-landscape")
      else
        model
      end

    # Auto-upgrade to -fl model when reference image present
    model = if has_ref, do: ensure_fl_model(model), else: model

    model
  end

  defp has_reference_image?(request) do
    Map.has_key?(request, :image) or
      Map.has_key?(request, :image_url) or
      Map.has_key?(request, :reference_image) or
      Map.has_key?(request, :first_frame_image) or
      Map.has_key?(request, :input_reference)
  end

  defp landscape?(ratio) when ratio in @landscape_ratios, do: true
  defp landscape?(_), do: false

  # Insert -fl BEFORE -hd or -4k suffixes (matches original TS logic exactly)
  defp ensure_fl_model(model) do
    if is_veo_frame_model?(model) do
      model
    else
      case Regex.run(~r/-(hd|4k)$/, model) do
        [suffix | _] ->
          idx = String.length(model) - String.length(suffix)
          String.slice(model, 0, idx) <> "-fl" <> suffix

        nil ->
          model <> "-fl"
      end
    end
  end

  @doc """
  Check if a model ID is a VEO 3.1 model.
  Matches any model starting with "veo-3.1".
  """
  def is_apiyi_veo_model?(model_id), do: String.starts_with?(model_id, "veo-3.1")

  # Check if model is already a -fl (frame-to-video) variant.
  # -fl can appear mid-name (e.g. veo-3.1-fl-4k), not just at end.
  defp is_veo_frame_model?(model) do
    model
    |> String.replace(~r/[-.]/, " ")
    |> String.split()
    |> Enum.member?("fl")
  end

  # ══════════════════════════════════════════
  # Input Reference Resolution
  # ══════════════════════════════════════════

  # Resolve input reference image from request into binary data.
  # Supports: raw binary, base64 data URL, HTTP(S) URL to download.
  defp resolve_input_reference(request) do
    ref =
      Map.get(request, :input_reference) ||
        Map.get(request, :image) ||
        Map.get(request, :reference_image) ||
        Map.get(request, :first_frame_image) ||
        Map.get(request, :image_url)

    resolve_image_ref(ref)
  end

  defp resolve_last_frame_reference(request) do
    ref =
      Map.get(request, :last_frame_reference) ||
        Map.get(request, :last_frame_image) ||
        Map.get(request, :last_frame_image_url)

    resolve_image_ref(ref)
  end

  # Convert various image reference formats to {:binary, data, content_type}
  defp resolve_image_ref(nil), do: nil

  defp resolve_image_ref(ref) when is_binary(ref) do
    cond do
      # Raw binary (not a string / URL / base64 data URL)
      not String.valid?(ref) ->
        {:binary, ref, "image/png"}

      # Data URL: data:image/png;base64,...
      String.starts_with?(ref, "data:") ->
        case String.split(ref, ";base64,", parts: 2) do
          [header, b64_data] ->
            mime = String.replace_prefix(header, "data:", "")

            case Base.decode64(b64_data) do
              {:ok, binary} -> {:binary, binary, mime}
              :error -> nil
            end

          _ ->
            nil
        end

      # HTTP(S) URL -> download the image
      String.starts_with?(ref, "http://") or String.starts_with?(ref, "https://") ->
        download_image(ref)

      # Assume raw base64 string
      true ->
        case Base.decode64(ref) do
          {:ok, binary} -> {:binary, binary, "image/png"}
          :error -> nil
        end
    end
  end

  # Tuple format from upstream: {binary, content_type}
  defp resolve_image_ref({binary, content_type}) when is_binary(binary),
    do: {:binary, binary, content_type}

  defp resolve_image_ref(%{data: data, mime_type: mime}) when is_binary(data) do
    case Base.decode64(data) do
      {:ok, binary} -> {:binary, binary, mime}
      :error -> {:binary, data, mime}
    end
  end

  defp resolve_image_ref(_), do: nil

  defp download_image(url) do
    case Req.get(url, receive_timeout: 30_000, max_retries: 2) do
      {:ok, %{status: 200, body: body, headers: headers}} when is_binary(body) ->
        content_type =
          headers
          |> Enum.find_value("image/png", fn
            {"content-type", ct} when is_binary(ct) ->
              ct |> String.split(";") |> List.first()

            {"content-type", [ct | _]} when is_binary(ct) ->
              # Finch/Req on newer versions returns header values as list
              ct |> String.split(";") |> List.first()

            _ ->
              nil
          end)

        {:binary, body, content_type}

      {:ok, %{status: status}} ->
        Logger.warning("[Apiyi] Failed to download image from #{url}: HTTP #{status}")
        nil

      {:error, reason} ->
        Logger.warning("[Apiyi] Failed to download image from #{url}: #{inspect(reason)}")
        nil
    end
  end

  # Build a Req form_multipart file part from resolved image data.
  # Req's form_multipart format: {name, {body, [filename: ..., content_type: ...]}}
  defp build_file_part(field_name, {:binary, data, content_type}, default_filename) do
    {field_name, {data, filename: default_filename, content_type: content_type}}
  end

  # Return nil when the image resolution failed — caller filters these out.
  defp build_file_part(_field_name, nil, _default_filename), do: nil

  # ══════════════════════════════════════════
  # Helpers
  # ══════════════════════════════════════════

  defp extract_image_from_gemini_response(resp) do
    with %{"candidates" => [candidate | _]} <- resp,
         %{"content" => %{"parts" => parts}} <- candidate do
      case Enum.find(parts, &Map.has_key?(&1, "inlineData")) do
        %{"inlineData" => %{"data" => data, "mimeType" => mime}} ->
          {:ok, %{data: data, mime_type: mime}}

        %{"inlineData" => %{"data" => data}} ->
          {:ok, %{data: data, mime_type: "image/png"}}

        _ ->
          :error
      end
    else
      _ -> :error
    end
  end

  defp parse_sse_chunks(data) do
    data
    |> String.split("\n")
    |> Enum.filter(&String.starts_with?(&1, "data: "))
    |> Enum.map(&String.trim_leading(&1, "data: "))
    |> Enum.reject(&(&1 == "[DONE]"))
    |> Enum.flat_map(fn json_str ->
      case Jason.decode(json_str) do
        {:ok, %{"choices" => [%{"delta" => %{"content" => c}} | _]}} when is_binary(c) -> [c]
        _ -> []
      end
    end)
  end
end
