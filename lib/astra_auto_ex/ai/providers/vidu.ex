defmodule AstraAutoEx.AI.Providers.Vidu do
  @moduledoc """
  Vidu provider — lip sync and video generation.
  Base URL: https://api.vidu.cn/ent/v2
  Auth: Token {api_key}
  Poll: GET /tasks/{task_id}
  Statuses: processing → success / failed
  """
  @behaviour AstraAutoEx.AI.Provider

  @base_url "https://api.vidu.cn/ent/v2"

  @impl true
  def capabilities, do: [:video, :lip_sync]

  @impl true
  def generate_video(request, config) do
    api_key = Map.fetch!(config, :api_key)
    url = "#{@base_url}/lip-sync"
    headers = [{"authorization", "Token #{api_key}"}, {"content-type", "application/json"}]

    body = %{
      "video_url" => request[:video_url] || request[:image_url],
      "audio_url" => request[:audio_url]
    }

    case Req.post(url, headers: headers, json: body, receive_timeout: 60_000) do
      {:ok, %{status: s, body: %{"task_id" => task_id}}} when s in 200..299 ->
        {:ok, %{external_id: "VIDU:VIDEO:#{task_id}", task_id: task_id}}

      {:ok, %{status: status, body: resp_body}} ->
        {:error, "Vidu request failed (#{status}): #{inspect(resp_body)}"}

      {:error, reason} ->
        {:error, "Vidu request error: #{inspect(reason)}"}
    end
  end

  @impl true
  def poll_task(task_id, config) do
    api_key = Map.fetch!(config, :api_key)
    url = "#{@base_url}/tasks/#{task_id}"
    headers = [{"authorization", "Token #{api_key}"}]

    case Req.get(url, headers: headers, receive_timeout: 15_000) do
      {:ok, %{status: 200, body: %{"state" => "success"} = body}} ->
        video_url =
          get_in(body, ["creations", Access.at(0), "url"]) ||
            Map.get(body, "video_url")

        {:ok, %{status: :completed, video_url: video_url, result: body}}

      {:ok, %{status: 200, body: %{"state" => state}}}
      when state in ["processing", "queued", "pending"] ->
        {:ok, %{status: :pending}}

      {:ok, %{status: 200, body: %{"state" => "failed"} = body}} ->
        {:ok, %{status: :failed, error: Map.get(body, "err_msg", "Task failed")}}

      {:ok, %{body: body}} ->
        {:error, body}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
