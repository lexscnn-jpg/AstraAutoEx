defmodule AstraAutoEx.Workers.TaskRunner do
  @moduledoc """
  Executes a single task in its own process.
  Manages heartbeat, lifecycle transitions, and error handling.
  """
  use GenServer, restart: :temporary

  require Logger

  alias AstraAutoEx.Tasks
  alias AstraAutoEx.Tasks.Task
  alias AstraAutoEx.Workers.{AutoChain, ConcurrencyLimiter, HandlerRegistry}

  @heartbeat_interval :timer.seconds(10)

  def start_link(task) do
    GenServer.start_link(__MODULE__, task)
  end

  @impl true
  def init(task) do
    queue_type = Task.queue_type(task.type)
    send(self(), :execute)
    {:ok, %{task: task, queue_type: queue_type, heartbeat_ref: nil}}
  end

  @impl true
  def handle_info(:execute, state) do
    %{task: task, queue_type: queue_type} = state

    case Tasks.mark_processing(task.id) do
      true ->
        Tasks.create_event!(task, "task.processing")
        broadcast_event(task, "task.processing")
        heartbeat_ref = Process.send_after(self(), :heartbeat, @heartbeat_interval)
        state = %{state | heartbeat_ref: heartbeat_ref}

        case execute_handler(task) do
          {:ok, result} ->
            Tasks.mark_completed(task.id, result)
            Tasks.create_event!(task, "task.completed", result)
            broadcast_event(task, "task.completed", result)
            ConcurrencyLimiter.release(queue_type, task.id)
            # AutoChain: trigger next pipeline step
            maybe_auto_chain(task)
            {:stop, :normal, state}

          {:error, reason} ->
            handle_failure(task, reason, state)
        end

      false ->
        Logger.warning("Task #{task.id} could not be marked processing (already terminal?)")
        ConcurrencyLimiter.release(queue_type, task.id)
        {:stop, :normal, state}
    end
  end

  @impl true
  def handle_info(:heartbeat, state) do
    Tasks.touch_heartbeat(state.task.id)
    ref = Process.send_after(self(), :heartbeat, @heartbeat_interval)
    {:noreply, %{state | heartbeat_ref: ref}}
  end

  defp execute_handler(task) do
    case HandlerRegistry.get_handler(task.type) do
      nil ->
        {:error, "no_handler_registered"}

      handler_module ->
        if Code.ensure_loaded?(handler_module) and function_exported?(handler_module, :execute, 1) do
          try do
            handler_module.execute(task)
          rescue
            e ->
              Logger.error("Task #{task.id} handler crashed: #{inspect(e)}")
              {:error, Exception.message(e)}
          end
        else
          {:error, "handler_not_implemented"}
        end
    end
  end

  defp handle_failure(task, reason, state) do
    %{queue_type: queue_type} = state
    error_msg = if is_binary(reason), do: reason, else: inspect(reason)

    # Reload to get current attempt count
    current_task = Tasks.get_task!(task.id)

    if current_task.attempt < current_task.max_attempts do
      # Retryable: mark back to queued with delay
      Tasks.mark_failed(task.id, "retryable", error_msg)
      Tasks.create_event!(task, "task.failed", %{retryable: true, error: error_msg})
      broadcast_event(task, "task.failed", %{retryable: true})

      # Re-queue with backoff
      delay = (:timer.seconds(2) * :math.pow(2, current_task.attempt - 1)) |> round()

      spawn(fn ->
        Process.sleep(delay)
        # Reset to queued for re-processing
        now = DateTime.utc_now(:second)
        import Ecto.Query

        AstraAutoEx.Repo.update_all(
          from(t in AstraAutoEx.Tasks.Task, where: t.id == ^task.id and t.status == "failed"),
          set: [status: "queued", updated_at: now]
        )
      end)
    else
      # Non-retryable: final failure
      Tasks.mark_failed(task.id, "max_attempts_exceeded", error_msg)
      Tasks.create_event!(task, "task.failed", %{retryable: false, error: error_msg})
      broadcast_event(task, "task.failed", %{retryable: false})
    end

    ConcurrencyLimiter.release(queue_type, task.id)
    {:stop, :normal, state}
  end

  defp maybe_auto_chain(task) do
    case task.type do
      "story_to_script_run" -> AutoChain.after_story_to_script(task)
      "script_to_storyboard_run" -> AutoChain.after_script_to_storyboard(task)
      t when t in ["image_panel", "image_character", "image_location"] -> AutoChain.after_image_complete(task)
      t when t in ["video_panel", "voice_line", "lip_sync"] -> AutoChain.after_video_voice_complete(task)
      _ -> :ok
    end
  rescue
    e -> Logger.warning("AutoChain trigger failed for task #{task.id}: #{Exception.message(e)}")
  end

  defp broadcast_event(task, event_type, payload \\ nil) do
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
end
