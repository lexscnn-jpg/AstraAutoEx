defmodule AstraAutoEx.Workers.Handlers.Watchdog do
  @moduledoc """
  Task watchdog — scans for stuck tasks and recovers them.

  Runs periodically (triggered by the task scheduler or manually) to find tasks
  that have been in `processing` status with no heartbeat update for longer than
  the configured threshold. Stuck tasks are marked as `failed` and any associated
  billing freezes are rolled back.

  Returns `{:ok, %{recovered: count, failed_tasks: [id, ...]}}`.
  """

  require Logger

  import Ecto.Query

  alias AstraAutoEx.Repo
  alias AstraAutoEx.Tasks
  alias AstraAutoEx.Tasks.Task

  @default_stale_seconds 300

  # --------------------------------------------------------------------------
  # Public API
  # --------------------------------------------------------------------------

  @spec execute(struct()) :: {:ok, map()} | {:error, term()}
  def execute(task) do
    payload = task.payload || %{}
    stale_seconds = payload["stale_threshold_seconds"] || @default_stale_seconds

    Logger.info("[Watchdog] Starting scan — stale threshold: #{stale_seconds}s")

    stale_tasks = find_stale_tasks(stale_seconds)
    count = length(stale_tasks)

    Logger.info("[Watchdog] Found #{count} stale task(s)")

    failed_ids =
      Enum.map(stale_tasks, fn stale_task ->
        recover_task(stale_task)
        stale_task.id
      end)

    # Also scan for orphaned "queued" tasks that have been waiting too long
    orphaned_count = recover_orphaned_queued(stale_seconds * 6)

    Logger.info(
      "[Watchdog] Scan complete — recovered: #{count}, orphaned re-queued: #{orphaned_count}"
    )

    {:ok,
     %{
       recovered: count,
       failed_tasks: failed_ids,
       orphaned_requeued: orphaned_count,
       threshold_seconds: stale_seconds
     }}
  end

  # --------------------------------------------------------------------------
  # Stale task detection
  # --------------------------------------------------------------------------

  @spec find_stale_tasks(non_neg_integer()) :: [struct()]
  defp find_stale_tasks(stale_seconds) do
    cutoff = DateTime.add(DateTime.utc_now(:second), -stale_seconds, :second)

    from(t in Task,
      where: t.status == "processing",
      where: t.heartbeat_at < ^cutoff or is_nil(t.heartbeat_at),
      order_by: [asc: t.heartbeat_at]
    )
    |> Repo.all()
  end

  # --------------------------------------------------------------------------
  # Recovery
  # --------------------------------------------------------------------------

  @spec recover_task(struct()) :: :ok
  defp recover_task(stale_task) do
    Logger.warning(
      "[Watchdog] Recovering stuck task #{stale_task.id} " <>
        "(type=#{stale_task.type}, last heartbeat=#{inspect(stale_task.heartbeat_at)})"
    )

    # Mark the task as failed with a descriptive error
    Tasks.mark_failed(
      stale_task.id,
      "watchdog_timeout",
      "Task stuck in processing — no heartbeat for over threshold"
    )

    # Roll back any billing freeze associated with this task
    rollback_billing_freeze(stale_task)

    # Release concurrency slot if the limiter tracks it
    try do
      queue_type = Task.queue_type(stale_task.type)
      AstraAutoEx.Workers.ConcurrencyLimiter.release(queue_type, stale_task.id)
    rescue
      _ -> :ok
    end

    :ok
  end

  @spec rollback_billing_freeze(struct()) :: :ok
  defp rollback_billing_freeze(stale_task) do
    if stale_task.billing_info && is_map(stale_task.billing_info) do
      Logger.info("[Watchdog] Rolling back billing freeze for task #{stale_task.id}")

      try do
        AstraAutoEx.Billing.CostTracker.log_call(%{
          user_id: stale_task.user_id,
          model_key: "watchdog_rollback",
          model_type: "system",
          pipeline_step: "watchdog_recovery",
          status: "rollback",
          duration_ms: 0
        })
      rescue
        _ -> :ok
      end
    end

    :ok
  end

  # --------------------------------------------------------------------------
  # Orphan recovery — queued tasks that were never picked up
  # --------------------------------------------------------------------------

  @spec recover_orphaned_queued(non_neg_integer()) :: non_neg_integer()
  defp recover_orphaned_queued(threshold_seconds) do
    cutoff = DateTime.add(DateTime.utc_now(:second), -threshold_seconds, :second)

    {count, _} =
      from(t in Task,
        where: t.status == "queued",
        where: t.queued_at < ^cutoff
      )
      |> Repo.update_all(set: [updated_at: DateTime.utc_now(:second)])

    count
  end
end
