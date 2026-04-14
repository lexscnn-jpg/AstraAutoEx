defmodule AstraAutoEx.AI.Providers.Bailian do
  @moduledoc """
  Bailian (DashScope) provider — lip sync and video generation via Alibaba Cloud.
  Base URL: https://dashscope.aliyuncs.com/api/v1
  Auth: Bearer {api_key}
  Submit: POST /services/aigc/image2video/video-synthesis (with X-DashScope-Async header)
  Poll: GET /tasks/{task_id}
  Statuses: PENDING → RUNNING → SUCCEEDED / FAILED
  """
  @behaviour AstraAutoEx.AI.Provider

  @base_url "https://dashscope.aliyuncs.com/api/v1"

  @impl true
  def capabilities, do: [:video, :lip_sync]

  @impl true
  def generate_video(request, config) do
    api_key = Map.fetch!(config, :api_key)
    model = request[:model] || "videoretalk"

    url = "#{@base_url}/services/aigc/image2video/video-synthesis"

    headers = [
      {"authorization", "Bearer #{api_key}"},
      {"content-type", "application/json"},
      {"x-dashscope-async", "enable"},
      {"x-dashscope-oss-resource-resolve", "enable"}
    ]

    body = %{
      "model" => model,
      "input" => %{
        "video_url" => request[:video_url] || request[:image_url],
        "audio_url" => request[:audio_url]
      }
    }

    case Req.post(url, headers: headers, json: body, receive_timeout: 60_000) do
      {:ok, %{status: s, body: %{"output" => %{"task_id" => task_id}}}} when s in 200..299 ->
        {:ok, %{external_id: "BAILIAN:VIDEO:#{task_id}", task_id: task_id}}

      {:ok, %{status: status, body: resp_body}} ->
        {:error, "Bailian request failed (#{status}): #{inspect(resp_body)}"}

      {:error, reason} ->
        {:error, "Bailian request error: #{inspect(reason)}"}
    end
  end

  @impl true
  def poll_task(task_id, config) do
    api_key = Map.fetch!(config, :api_key)
    url = "#{@base_url}/tasks/#{task_id}"
    headers = [{"authorization", "Bearer #{api_key}"}]

    case Req.get(url, headers: headers, receive_timeout: 15_000) do
      {:ok, %{status: 200, body: %{"output" => %{"task_status" => "SUCCEEDED"} = output}}} ->
        video_url =
          Map.get(output, "video_url") ||
            get_in(output, ["results", Access.at(0), "url"])

        {:ok, %{status: :completed, video_url: video_url, result: output}}

      {:ok, %{status: 200, body: %{"output" => %{"task_status" => status}}}}
      when status in ["PENDING", "RUNNING"] ->
        {:ok, %{status: :pending}}

      {:ok, %{status: 200, body: %{"output" => %{"task_status" => "FAILED"} = output}}} ->
        {:ok, %{status: :failed, error: Map.get(output, "message", "Task failed")}}

      {:ok, %{body: body}} ->
        {:error, body}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
