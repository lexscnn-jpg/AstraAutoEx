defmodule AstraAutoEx.Workers.AsyncPollWorker do
  @moduledoc """
  Periodically polls external providers for tasks that are in "processing"
  state with an external_id. Routes through AsyncPoller → Gateway → Provider.

  On completion: updates the target entity (panel video_url, lip_sync_video_url, etc.)
  and marks the task completed.
  """
  use GenServer

  require Logger

  alias AstraAutoEx.Tasks
  alias AstraAutoEx.AI.AsyncPoller

  @poll_interval :timer.seconds(15)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    unless Application.get_env(:astra_auto_ex, :disable_scheduler) do
      schedule_poll()
    end

    {:ok, %{}}
  end

  @impl true
  def handle_info(:poll, state) do
    poll_all()
    schedule_poll()
    {:noreply, state}
  end

  defp poll_all do
    tasks = Tasks.list_polling_tasks(20)

    Enum.each(tasks, fn task ->
      try do
        poll_task(task)
      rescue
        e ->
          Logger.error("[AsyncPollWorker] Error polling task #{task.id}: #{inspect(e)}")
      end
    end)
  end

  defp poll_task(task) do
    user_config = build_user_config(task.user_id)

    case AsyncPoller.poll(task.external_id, user_config) do
      {:ok, %{status: :completed} = result} ->
        handle_completed(task, result)

      {:ok, %{status: :pending}} ->
        # Touch heartbeat to prevent watchdog from killing it
        Tasks.touch_heartbeat(task.id)

      {:ok, %{status: :failed} = result} ->
        error_msg = Map.get(result, :error, "External task failed")
        Tasks.mark_failed(task.id, "external_failed", error_msg)
        Tasks.create_event!(task, "task.failed", %{error: error_msg})
        broadcast(task, "task.failed", %{error: error_msg})
        Logger.warning("[AsyncPollWorker] Task #{task.id} failed externally: #{error_msg}")

      {:error, reason} ->
        Logger.warning("[AsyncPollWorker] Poll error for task #{task.id}: #{inspect(reason)}")
    end
  end

  defp handle_completed(task, result) do
    video_url = result[:video_url] || result[:result_url]

    # Route to type-specific completion logic
    case task.type do
      "lip_sync" ->
        complete_lip_sync(task, video_url, result)

      "image_panel" ->
        complete_image(task, result)

      type when type in ["video_panel", "video"] ->
        complete_video(task, video_url, result)

      _ ->
        Tasks.mark_completed(task.id, result)
    end

    Tasks.create_event!(task, "task.completed", result)
    broadcast(task, "task.completed", result)
    Logger.info("[AsyncPollWorker] Task #{task.id} (#{task.type}) completed")
  end

  defp complete_lip_sync(task, video_url, result) do
    payload = task.payload || %{}
    panel_id = payload["panel_id"] || task.target_id

    if video_url do
      panel = AstraAutoEx.Production.get_panel!(panel_id)
      AstraAutoEx.Production.update_panel(panel, %{lip_sync_video_url: video_url})
    end

    Tasks.mark_completed(task.id, Map.put(result, :video_url, video_url))
  end

  defp complete_video(task, video_url, result) do
    panel_id = (task.payload || %{})["panel_id"] || task.target_id

    if video_url do
      panel = AstraAutoEx.Production.get_panel!(panel_id)
      AstraAutoEx.Production.update_panel(panel, %{video_url: video_url})
    end

    Tasks.mark_completed(task.id, Map.put(result, :video_url, video_url))
  end

  defp complete_image(task, result) do
    image_url = result[:image_url] || result[:result_url]
    panel_id = (task.payload || %{})["panel_id"] || task.target_id

    if image_url do
      panel = AstraAutoEx.Production.get_panel!(panel_id)
      AstraAutoEx.Production.update_panel(panel, %{image_url: image_url})
    end

    Tasks.mark_completed(task.id, Map.put(result, :image_url, image_url))
  end

  defp build_user_config(user_id) do
    case AstraAutoEx.Accounts.get_user_preference(user_id) do
      nil ->
        %{}

      pref ->
        configs = pref.provider_configs || %{}

        configs
        |> Enum.map(fn {key, val} ->
          {key, atomize_keys(val)}
        end)
        |> Map.new()
    end
  end

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {String.to_existing_atom(k), v} end)
  rescue
    _ -> Map.new(map, fn {k, v} -> {String.to_atom(k), v} end)
  end

  # Fallback for non-map values (strings, ints, etc. — leave as-is)
  defp atomize_keys(other), do: other

  defp broadcast(task, event_type, payload) do
    Phoenix.PubSub.broadcast(
      AstraAutoEx.PubSub,
      "project:#{task.project_id}",
      {:task_event,
       %{
         type: event_type,
         task_id: task.id,
         task_type: task.type,
         target_type: task.target_type,
         target_id: task.target_id,
         payload: payload
       }}
    )
  end

  defp schedule_poll, do: Process.send_after(self(), :poll, @poll_interval)
end
