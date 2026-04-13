defmodule AstraAutoEx.Workers.TaskScheduler do
  @moduledoc """
  GenServer that polls the database for queued tasks and dispatches them
  to TaskRunner processes via DynamicSupervisor.
  Also runs a watchdog to detect stale processing tasks.
  """
  use GenServer

  require Logger

  alias AstraAutoEx.Tasks
  alias AstraAutoEx.Tasks.Task
  alias AstraAutoEx.Workers.{ConcurrencyLimiter, TaskRunner}

  @poll_interval :timer.seconds(1)
  @watchdog_interval :timer.seconds(30)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    unless Application.get_env(:astra_auto_ex, :disable_scheduler) do
      schedule_poll()
      schedule_watchdog()
    end

    {:ok, %{}}
  end

  @impl true
  def handle_info(:poll, state) do
    poll_and_dispatch()
    schedule_poll()
    {:noreply, state}
  end

  @impl true
  def handle_info(:watchdog, state) do
    run_watchdog()
    schedule_watchdog()
    {:noreply, state}
  end

  defp poll_and_dispatch do
    tasks = Tasks.list_queued_tasks(20)

    Enum.each(tasks, fn task ->
      queue_type = Task.queue_type(task.type)

      case ConcurrencyLimiter.acquire(queue_type, task.id) do
        :ok ->
          case DynamicSupervisor.start_child(
                 AstraAutoEx.Workers.TaskRunnerSupervisor,
                 {TaskRunner, task}
               ) do
            {:ok, _pid} ->
              :ok

            {:error, reason} ->
              Logger.error("Failed to start TaskRunner for #{task.id}: #{inspect(reason)}")
              ConcurrencyLimiter.release(queue_type, task.id)
          end

        {:error, :at_capacity} ->
          :ok
      end
    end)
  end

  defp run_watchdog do
    stale_tasks = Tasks.list_stale_processing(300)

    Enum.each(stale_tasks, fn task ->
      Logger.warning(
        "Watchdog: marking stale task #{task.id} as failed (no heartbeat for 5+ min)"
      )

      Tasks.mark_failed(task.id, "watchdog_timeout", "No heartbeat received for 5+ minutes")
      Tasks.create_event!(task, "task.failed", %{reason: "watchdog_timeout"})

      queue_type = Task.queue_type(task.type)
      ConcurrencyLimiter.release(queue_type, task.id)

      Phoenix.PubSub.broadcast(
        AstraAutoEx.PubSub,
        "project:#{task.project_id}",
        {:task_event,
         %{
           type: "task.failed",
           task_id: task.id,
           task_type: task.type,
           target_type: task.target_type,
           target_id: task.target_id,
           payload: %{reason: "watchdog_timeout"}
         }}
      )
    end)
  end

  defp schedule_poll, do: Process.send_after(self(), :poll, @poll_interval)
  defp schedule_watchdog, do: Process.send_after(self(), :watchdog, @watchdog_interval)
end
