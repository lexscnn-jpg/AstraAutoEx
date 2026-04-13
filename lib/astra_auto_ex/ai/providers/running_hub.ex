defmodule AstraAutoEx.AI.Providers.RunningHub do
  @moduledoc """
  RunningHub provider — 238+ models, POST-based polling.
  Base URL: https://www.runninghub.cn/openapi/v2
  Submit: POST {base}/endpoint → {"taskId": "xxx"}
  Poll: POST {base}/query body: {"taskId": "xxx"}
  Statuses: CREATE → QUEUED → RUNNING → SUCCESS / FAILED / CANCEL
  """
  @behaviour AstraAutoEx.AI.Provider

  @base_url "https://www.runninghub.cn/openapi/v2"

  @impl true
  def capabilities, do: [:image, :video, :llm, :audio]

  @impl true
  def generate_image(request, config) do
    submit_task(request, config, "IMAGE")
  end

  @impl true
  def generate_video(request, config) do
    submit_task(request, config, "VIDEO")
  end

  @impl true
  def text_to_speech(request, config) do
    submit_task(request, config, "AUDIO")
  end

  @impl true
  def chat(request, config) do
    submit_task(request, config, "TEXT")
  end

  @impl true
  def poll_task(task_id, config) do
    api_key = Map.fetch!(config, :api_key)
    url = "#{@base_url}/query"
    headers = [{"authorization", "Bearer #{api_key}"}, {"content-type", "application/json"}]

    case Req.post(url, headers: headers, json: %{taskId: task_id}, receive_timeout: 30_000) do
      {:ok, %{status: 200, body: %{"status" => "SUCCESS"} = body}} ->
        results = Map.get(body, "results", [])

        url =
          results |> List.first(%{}) |> then(&(Map.get(&1, "url") || Map.get(&1, "outputUrl")))

        {:ok, %{status: :completed, result_url: url, results: results}}

      {:ok, %{status: 200, body: %{"status" => status}}}
      when status in ["CREATE", "QUEUED", "RUNNING"] ->
        {:ok, %{status: :pending}}

      {:ok, %{status: 200, body: %{"status" => status} = body}}
      when status in ["FAILED", "CANCEL"] ->
        {:ok, %{status: :failed, error: Map.get(body, "message", status)}}

      {:ok, %{body: body}} ->
        {:error, body}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp submit_task(request, config, type) do
    api_key = Map.fetch!(config, :api_key)
    endpoint = Map.get(request, :endpoint, "submit")
    url = "#{@base_url}/#{endpoint}"
    headers = [{"authorization", "Bearer #{api_key}"}, {"content-type", "application/json"}]
    body = Map.drop(request, [:endpoint])

    case Req.post(url, headers: headers, json: body, receive_timeout: 60_000, max_retries: 3) do
      {:ok, %{status: 200, body: %{"taskId" => task_id}}} ->
        {:ok, %{external_id: "RUNNINGHUB:#{type}:#{task_id}", task_id: task_id}}

      {:ok, %{body: body}} ->
        {:error, body}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
