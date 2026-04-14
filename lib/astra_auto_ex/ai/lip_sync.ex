defmodule AstraAutoEx.AI.LipSync do
  @moduledoc """
  Lip sync orchestration — routes lip sync requests to the appropriate provider.

  Supported providers:
    - FAL (Kling lip sync): fal-ai/kling-video/lipsync/audio-to-video
    - Vidu: api.vidu.cn/ent/v2/lip-sync
    - Bailian (DashScope): videoretalk model

  Flow: video_url + audio_url → provider submission → async task_id → poll for result
  """
  require Logger

  alias AstraAutoEx.Workers.Handlers.Helpers

  @type lip_sync_params :: %{
          video_url: String.t(),
          audio_url: String.t(),
          model_key: String.t() | nil
        }

  @default_model_key "fal::fal-ai/kling-video/lipsync/audio-to-video"

  @doc "Submit a lip sync job. Returns {:ok, result} with external_id for polling."
  @spec submit(String.t(), lip_sync_params()) :: {:ok, map()} | {:error, any()}
  def submit(user_id, params) do
    model_key = params[:model_key] || @default_model_key
    {provider, model_id} = parse_model_key(model_key)

    Logger.info("[LipSync] Submitting: provider=#{provider}, model=#{model_id}")

    case provider do
      "fal" -> submit_fal(user_id, params, model_id)
      "vidu" -> submit_vidu(user_id, params, model_id)
      "bailian" -> submit_bailian(user_id, params, model_id)
      _ -> {:error, "Unsupported lip sync provider: #{provider}"}
    end
  end

  # ── FAL Lip Sync ──

  defp submit_fal(user_id, params, model_id) do
    endpoint = model_id

    with {:ok, config} <- Helpers.get_provider_config(user_id, "fal") do
      api_key = config[:api_key]
      base_url = config[:base_url] || "https://queue.fal.run"

      body = %{
        "video_url" => params.video_url,
        "audio_url" => params.audio_url
      }

      url = "#{base_url}/#{endpoint}"
      headers = [{"authorization", "Key #{api_key}"}, {"content-type", "application/json"}]

      case Req.post(url, headers: headers, json: body, receive_timeout: 60_000) do
        {:ok, %{status: s, body: %{"request_id" => request_id}}} when s in 200..299 ->
          external_id = "FAL:VIDEO:#{endpoint}:#{request_id}"
          Logger.info("[LipSync.FAL] Submitted: #{external_id}")
          {:ok, %{external_id: external_id, request_id: request_id, provider: "fal"}}

        {:ok, %{status: status, body: resp_body}} ->
          {:error, "FAL lip sync failed (#{status}): #{inspect(resp_body)}"}

        {:error, reason} ->
          {:error, "FAL lip sync request error: #{inspect(reason)}"}
      end
    end
  end

  # ── Vidu Lip Sync ──

  defp submit_vidu(user_id, params, _model_id) do
    with {:ok, config} <- Helpers.get_provider_config(user_id, "vidu") do
      api_key = config[:api_key]

      body = %{
        "video_url" => params.video_url,
        "audio_url" => params.audio_url
      }

      url = "https://api.vidu.cn/ent/v2/lip-sync"
      headers = [{"authorization", "Token #{api_key}"}, {"content-type", "application/json"}]

      case Req.post(url, headers: headers, json: body, receive_timeout: 60_000) do
        {:ok, %{status: s, body: %{"task_id" => task_id}}} when s in 200..299 ->
          external_id = "VIDU:VIDEO:#{task_id}"
          Logger.info("[LipSync.Vidu] Submitted: #{external_id}")
          {:ok, %{external_id: external_id, request_id: task_id, provider: "vidu"}}

        {:ok, %{status: status, body: resp_body}} ->
          {:error, "Vidu lip sync failed (#{status}): #{inspect(resp_body)}"}

        {:error, reason} ->
          {:error, "Vidu lip sync request error: #{inspect(reason)}"}
      end
    end
  end

  # ── Bailian Lip Sync (DashScope) ──

  defp submit_bailian(user_id, params, model_id) do
    model = if model_id == "", do: "videoretalk", else: model_id

    with {:ok, config} <- Helpers.get_provider_config(user_id, "bailian") do
      api_key = config[:api_key]

      body = %{
        "model" => model,
        "input" => %{
          "video_url" => params.video_url,
          "audio_url" => params.audio_url
        }
      }

      url = "https://dashscope.aliyuncs.com/api/v1/services/aigc/image2video/video-synthesis"

      headers = [
        {"authorization", "Bearer #{api_key}"},
        {"content-type", "application/json"},
        {"x-dashscope-async", "enable"},
        {"x-dashscope-oss-resource-resolve", "enable"}
      ]

      case Req.post(url, headers: headers, json: body, receive_timeout: 60_000) do
        {:ok, %{status: s, body: %{"output" => %{"task_id" => task_id}}}} when s in 200..299 ->
          external_id = "BAILIAN:VIDEO:#{task_id}"
          Logger.info("[LipSync.Bailian] Submitted: #{external_id}")
          {:ok, %{external_id: external_id, request_id: task_id, provider: "bailian"}}

        {:ok, %{status: status, body: resp_body}} ->
          {:error, "Bailian lip sync failed (#{status}): #{inspect(resp_body)}"}

        {:error, reason} ->
          {:error, "Bailian lip sync request error: #{inspect(reason)}"}
      end
    end
  end

  # ── Helpers ──

  @doc "Parse model key format 'provider::model_id' into {provider, model_id}."
  @spec parse_model_key(String.t()) :: {String.t(), String.t()}
  def parse_model_key(model_key) do
    case String.split(model_key, "::", parts: 2) do
      [provider, model_id] -> {provider, model_id}
      [provider] -> {provider, ""}
    end
  end
end
