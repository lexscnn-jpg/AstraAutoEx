defmodule AstraAutoEx.AI.Providers.Minimax do
  @moduledoc """
  MiniMax (海螺) provider — video (Hailuo), TTS (Speech), music, image.
  Base URL: https://api.minimaxi.com/v1
  Ported 1:1 from original AstraAuto TypeScript implementation.
  """
  @behaviour AstraAutoEx.AI.Provider

  # MiniMax has two domains: api.minimaxi.com (international) and api.minimax.chat (China)
  # Default to api.minimax.chat as it's more accessible from mainland China
  @default_base_url "https://api.minimax.chat/v1"

  defp base_url(config), do: Map.get(config, :base_url, @default_base_url)

  @video_model_specs %{
    "minimax-hailuo-2.3" => "MiniMax-Hailuo-2.3",
    "minimax-hailuo-2.3-fast" => "MiniMax-Hailuo-2.3-Fast",
    "minimax-hailuo-02" => "MiniMax-Hailuo-02",
    "t2v-01" => "T2V-01",
    "t2v-01-director" => "T2V-01-Director"
  }

  @impl true
  def capabilities, do: [:chat, :image, :video, :tts, :music]

  # ── Chat / LLM ──

  @impl true
  def chat(request, config) do
    api_key = Map.fetch!(config, :api_key)
    url = "#{base_url(config)}/text/chatcompletion_v2"
    headers = auth_headers(api_key)

    messages = Map.get(request, "messages", Map.get(request, :messages, []))
    model = Map.get(request, "model", Map.get(request, :model, "MiniMax-M2.7-highspeed"))
    max_tokens = Map.get(request, "max_tokens", Map.get(request, :max_tokens, 4096))

    body = %{
      "model" => model,
      "messages" => messages,
      "max_tokens" => max_tokens,
      "temperature" => Map.get(request, "temperature", Map.get(request, :temperature, 0.7))
    }

    case Req.post(url, headers: headers, json: body, receive_timeout: 120_000) do
      {:ok,
       %{
         status: 200,
         body:
           %{
             "base_resp" => %{"status_code" => 0},
             "choices" => [%{"message" => %{"content" => content}} | _]
           } = resp
       }} ->
        usage = Map.get(resp, "usage", %{})

        {:ok,
         %{
           content: content,
           input_tokens: Map.get(usage, "prompt_tokens", 0),
           output_tokens: Map.get(usage, "completion_tokens", 0)
         }}

      {:ok, %{status: 200, body: %{"base_resp" => %{"status_msg" => msg}}}} ->
        {:error, msg}

      {:ok, %{body: body}} ->
        {:error, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ── Video Generation ──

  @impl true
  def generate_video(request, config) do
    api_key = Map.fetch!(config, :api_key)
    url = "#{base_url(config)}/video_generation"
    headers = auth_headers(api_key)

    model_key = Map.get(request, :model, "minimax-hailuo-2.3")
    api_model = Map.get(@video_model_specs, model_key, model_key)

    body = %{
      "model" => api_model,
      "prompt" => Map.get(request, :prompt, ""),
      "prompt_optimizer" => true
    }

    body = put_if(body, "duration", Map.get(request, :duration))
    body = put_if(body, "resolution", Map.get(request, :resolution))
    body = put_if(body, "first_frame_image", Map.get(request, :first_frame_image))
    body = put_if(body, "last_frame_image", Map.get(request, :last_frame_image))

    case Req.post(url, headers: headers, json: body, receive_timeout: 60_000) do
      {:ok, %{status: 200, body: %{"base_resp" => %{"status_code" => 0}, "task_id" => task_id}}} ->
        {:ok, %{external_id: "MINIMAX:VIDEO:#{task_id}", task_id: task_id}}

      {:ok, %{status: 200, body: %{"base_resp" => %{"status_msg" => msg}}}} ->
        {:error, msg}

      {:ok, %{body: body}} ->
        {:error, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ── Image Generation ──

  @impl true
  def generate_image(request, config) do
    api_key = Map.fetch!(config, :api_key)
    url = "#{base_url(config)}/image_generation"
    headers = auth_headers(api_key)

    prompt = Map.get(request, :prompt, "") |> String.slice(0..1499)

    body = %{
      "model" => Map.get(request, :model, "image-01"),
      "prompt" => prompt,
      "aspect_ratio" => Map.get(request, :aspect_ratio, "1:1"),
      "prompt_optimizer" => true
    }

    body =
      case Map.get(request, :subject_reference) do
        nil -> body
        ref -> Map.put(body, "subject_reference", ref)
      end

    case Req.post(url, headers: headers, json: body, receive_timeout: 60_000) do
      {:ok,
       %{
         status: 200,
         body: %{"base_resp" => %{"status_code" => 0}, "data" => %{"image_urls" => urls}}
       }} ->
        {:ok, %{status: :completed, image_urls: urls}}

      {:ok, %{status: 200, body: %{"base_resp" => %{"status_code" => 0}, "task_id" => task_id}}}
      when task_id != "" ->
        {:ok, %{external_id: "MINIMAX:IMAGE:#{task_id}", task_id: task_id}}

      {:ok, %{status: 200, body: %{"base_resp" => %{"status_msg" => msg}}}} ->
        {:error, msg}

      {:ok, %{body: body}} ->
        {:error, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ── TTS (Text-to-Speech) ──

  @impl true
  def text_to_speech(request, config) do
    api_key = Map.fetch!(config, :api_key)
    url = "#{base_url(config)}/t2a_v2"
    headers = auth_headers(api_key)

    text = Map.get(request, :text, "") |> String.slice(0..9999)

    body = %{
      "model" => Map.get(request, :model, "speech-2.8-hd"),
      "text" => text,
      "voice_setting" =>
        Map.get(request, :voice_setting, %{
          "voice_id" => Map.get(request, :voice_id, "Calm_Woman"),
          "speed" => Map.get(request, :speed, 1.0)
        }),
      "audio_setting" => %{
        "format" => "wav",
        "sample_rate" => 32000,
        "bitrate" => 128_000,
        "channel" => 1
      },
      "output_format" => "hex"
    }

    case Req.post(url, headers: headers, json: body, receive_timeout: 60_000) do
      {:ok,
       %{
         status: 200,
         body: %{
           "base_resp" => %{"status_code" => 0},
           "data" => %{"audio" => %{"audio_file" => %{"file_id" => file_id}}}
         }
       }} ->
        retrieve_file(file_id, config)

      {:ok, %{status: 200, body: %{"base_resp" => %{"status_code" => 0}} = resp}} ->
        # Direct hex audio in response
        audio_hex = get_in(resp, ["data", "audio", "data"])

        if audio_hex do
          {:ok, %{status: :completed, audio_hex: audio_hex, format: "wav"}}
        else
          {:ok, %{status: :completed, result: resp}}
        end

      {:ok, %{status: 200, body: %{"base_resp" => %{"status_msg" => msg}}}} ->
        {:error, msg}

      {:ok, %{body: body}} ->
        {:error, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ── Music Generation ──

  def generate_music(request, config) do
    api_key = Map.fetch!(config, :api_key)
    url = "#{base_url(config)}/music_generation"
    headers = auth_headers(api_key)

    body = %{
      "model" => Map.get(request, :model, "music-2.6"),
      "prompt" => Map.get(request, :prompt, ""),
      "audio_setting" => %{
        "format" => "mp3",
        "sample_rate" => 44100,
        "bitrate" => 256_000
      },
      "output_format" => "url"
    }

    body = put_if(body, "lyrics", Map.get(request, :lyrics))
    body = put_if(body, "is_instrumental", Map.get(request, :is_instrumental))

    case Req.post(url, headers: headers, json: body, receive_timeout: 120_000) do
      {:ok,
       %{
         status: 200,
         body: %{"base_resp" => %{"status_code" => 0}, "data" => %{"audio" => audio}}
       }} ->
        {:ok, %{status: :completed, audio: audio}}

      {:ok, %{status: 200, body: %{"base_resp" => %{"status_msg" => msg}}}} ->
        {:error, msg}

      {:ok, %{body: body}} ->
        {:error, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ── Voice List (300+ system voices) ──

  @doc "Fetch all available system voices from MiniMax API."
  def list_voices(config) do
    api_key = Map.fetch!(config, :api_key)
    url = "#{base_url(config)}/voices"
    headers = auth_headers(api_key)

    case Req.get(url, headers: headers, receive_timeout: 15_000) do
      {:ok, %{status: 200, body: %{"base_resp" => %{"status_code" => 0}} = resp}} ->
        voices = Map.get(resp, "voices", Map.get(resp, "voice_list", []))

        presets =
          Enum.map(voices, fn v ->
            %{
              id: v["voice_id"] || v["id"] || "",
              name: v["name"] || v["voice_id"] || "",
              gender: normalize_gender(v["gender"]),
              language: v["language"] || "zh",
              description: v["description"] || v["desc"] || "",
              category: v["category"] || v["tag"] || "system",
              preview_url: v["audition_url"] || v["preview_url"]
            }
          end)

        {:ok, presets}

      {:ok, %{status: 200, body: body}} ->
        # Fallback: try alternate response format
        voices = Map.get(body, "data", Map.get(body, "voices", []))

        if is_list(voices) && length(voices) > 0 do
          presets =
            Enum.map(voices, fn v ->
              %{
                id: v["voice_id"] || v["id"] || "",
                name: v["name"] || "",
                gender: normalize_gender(v["gender"]),
                language: v["language"] || "zh",
                description: v["description"] || "",
                category: v["category"] || "system",
                preview_url: v["audition_url"]
              }
            end)

          {:ok, presets}
        else
          {:error, "Unexpected voice list format"}
        end

      {:ok, %{body: body}} ->
        {:error, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp normalize_gender("male"), do: "male"
  defp normalize_gender("female"), do: "female"
  defp normalize_gender("Male"), do: "male"
  defp normalize_gender("Female"), do: "female"
  defp normalize_gender(g) when is_binary(g), do: String.downcase(g)
  defp normalize_gender(_), do: "unknown"

  # ── Voice Design ──

  def design_voice(request, config) do
    api_key = Map.fetch!(config, :api_key)
    url = "#{base_url(config)}/voice_design"
    headers = auth_headers(api_key)

    body = %{
      "prompt" => Map.get(request, :prompt, ""),
      "preview_text" => Map.get(request, :preview_text, "你好，这是一段测试语音。")
    }

    body = put_if(body, "voice_id", Map.get(request, :voice_id))

    case Req.post(url, headers: headers, json: body, receive_timeout: 30_000) do
      {:ok, %{status: 200, body: %{"base_resp" => %{"status_code" => 0}} = resp}} ->
        {:ok,
         %{
           voice_id: Map.get(resp, "voice_id"),
           trial_audio: Map.get(resp, "trial_audio")
         }}

      {:ok, %{status: 200, body: %{"base_resp" => %{"status_msg" => msg}}}} ->
        {:error, msg}

      {:ok, %{body: body}} ->
        {:error, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ── Async Task Polling ──

  @impl true
  def poll_task(task_id, config) do
    api_key = Map.fetch!(config, :api_key)
    url = "#{base_url(config)}/query/video_generation?task_id=#{task_id}"
    headers = auth_headers(api_key)

    case Req.get(url, headers: headers, receive_timeout: 15_000) do
      {:ok,
       %{
         status: 200,
         body: %{
           "base_resp" => %{"status_code" => 0},
           "status" => "Success",
           "file_id" => file_id
         }
       }} ->
        case retrieve_file(file_id, config) do
          {:ok, %{download_url: download_url}} ->
            {:ok, %{status: :completed, video_url: download_url}}

          error ->
            error
        end

      {:ok, %{status: 200, body: %{"status" => "Processing"}}} ->
        {:ok, %{status: :pending}}

      {:ok, %{status: 200, body: %{"status" => "Failed"} = body}} ->
        {:ok,
         %{status: :failed, error: Map.get(body, "error_message", "Video generation failed")}}

      {:ok, %{status: 200, body: %{"base_resp" => %{"status_msg" => msg}}}} ->
        {:error, msg}

      {:ok, %{body: body}} ->
        {:error, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ── File Retrieval ──

  defp retrieve_file(file_id, config) do
    api_key = Map.fetch!(config, :api_key)
    url = "#{base_url(config)}/files/retrieve?file_id=#{file_id}"
    headers = auth_headers(api_key)

    case Req.get(url, headers: headers, receive_timeout: 30_000) do
      {:ok, %{status: 200, body: %{"file" => %{"download_url" => download_url}}}} ->
        {:ok, %{download_url: download_url, file_id: file_id}}

      {:ok, %{body: body}} ->
        {:error, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ── Helpers ──

  defp auth_headers(api_key) do
    [{"authorization", "Bearer #{api_key}"}, {"content-type", "application/json"}]
  end

  defp put_if(map, _key, nil), do: map
  defp put_if(map, key, value), do: Map.put(map, key, value)
end
