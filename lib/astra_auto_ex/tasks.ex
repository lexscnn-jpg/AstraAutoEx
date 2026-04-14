defmodule AstraAutoEx.Tasks do
  @moduledoc "Context for task lifecycle management."

  import Ecto.Query
  alias AstraAutoEx.Repo
  alias AstraAutoEx.Tasks.{Task, TaskEvent}

  # ── Creation ──

  def create_task(attrs) do
    now = DateTime.utc_now(:second)

    attrs =
      attrs
      |> Map.put_new(:status, "queued")
      |> Map.put_new(:queued_at, now)

    %Task{}
    |> Task.changeset(attrs)
    |> Repo.insert()
  end

  # ── State Transitions ──

  def mark_processing(task_id) do
    now = DateTime.utc_now(:second)

    {count, _} =
      from(t in Task,
        where: t.id == ^task_id and t.status in ^Task.active_statuses()
      )
      |> Repo.update_all(
        set: [status: "processing", started_at: now, heartbeat_at: now, updated_at: now],
        inc: [attempt: 1]
      )

    count > 0
  end

  def mark_completed(task_id, result \\ nil) do
    now = DateTime.utc_now(:second)

    {count, _} =
      from(t in Task,
        where: t.id == ^task_id and t.status in ^Task.active_statuses()
      )
      |> Repo.update_all(
        set: [
          status: "completed",
          progress: 100,
          result: result,
          finished_at: now,
          updated_at: now
        ]
      )

    count > 0
  end

  def mark_failed(task_id, error_code, error_message) do
    now = DateTime.utc_now(:second)
    code = String.slice(error_code || "", 0..79)
    msg = String.slice(error_message || "", 0..1999)

    {count, _} =
      from(t in Task,
        where: t.id == ^task_id and t.status in ^Task.active_statuses()
      )
      |> Repo.update_all(
        set: [
          status: "failed",
          error_code: code,
          error_message: msg,
          finished_at: now,
          updated_at: now
        ]
      )

    count > 0
  end

  def mark_canceled(task_id, reason \\ nil) do
    now = DateTime.utc_now(:second)

    {count, _} =
      from(t in Task,
        where: t.id == ^task_id and t.status in ^Task.active_statuses()
      )
      |> Repo.update_all(
        set: [status: "canceled", error_message: reason, finished_at: now, updated_at: now]
      )

    count > 0
  end

  # ── Progress ──

  def update_progress(task_id, progress, payload \\ nil) when progress in 0..99 do
    sets = [progress: progress, updated_at: DateTime.utc_now(:second)]
    sets = if payload, do: Keyword.put(sets, :payload, payload), else: sets

    {count, _} =
      from(t in Task, where: t.id == ^task_id and t.status in ^Task.active_statuses())
      |> Repo.update_all(set: sets)

    count > 0
  end

  def touch_heartbeat(task_id) do
    now = DateTime.utc_now(:second)

    from(t in Task, where: t.id == ^task_id and t.status == "processing")
    |> Repo.update_all(set: [heartbeat_at: now])
  end

  def set_external_id(task_id, external_id) do
    from(t in Task, where: t.id == ^task_id)
    |> Repo.update_all(set: [external_id: external_id, updated_at: DateTime.utc_now(:second)])
  end

  def update_task(task, attrs) when is_struct(task) do
    task |> Task.changeset(attrs) |> Repo.update()
  end

  def update_task(%{id: id}, attrs), do: update_task(get_task!(id), attrs)

  # ── Queries ──

  def get_task(id), do: Repo.get(Task, id)

  def get_task!(id), do: Repo.get!(Task, id)

  def list_queued_tasks(limit \\ 50) do
    from(t in Task,
      where: t.status == "queued",
      order_by: [desc: t.priority, asc: t.queued_at],
      limit: ^limit
    )
    |> Repo.all()
  end

  def list_failed_tasks(project_id, task_type) do
    from(t in Task,
      where: t.project_id == ^project_id and t.type == ^task_type and t.status == "failed",
      order_by: [desc: t.inserted_at]
    )
    |> Repo.all()
  end

  def list_active_tasks_for_target(target_type, target_id) do
    from(t in Task,
      where:
        t.target_type == ^target_type and t.target_id == ^target_id and
          t.status in ^Task.active_statuses()
    )
    |> Repo.all()
  end

  def list_project_tasks(project_id, opts \\ []) do
    status = Keyword.get(opts, :status)
    limit = Keyword.get(opts, :limit, 100)

    query =
      from(t in Task,
        where: t.project_id == ^project_id,
        order_by: [desc: t.inserted_at],
        limit: ^limit
      )

    query = if status, do: where(query, [t], t.status == ^status), else: query
    Repo.all(query)
  end

  def list_polling_tasks(limit \\ 50) do
    from(t in Task,
      where: t.status == "processing" and not is_nil(t.external_id),
      order_by: [asc: t.updated_at],
      limit: ^limit
    )
    |> Repo.all()
  end

  def list_stale_processing(stale_threshold_seconds \\ 300) do
    cutoff = DateTime.add(DateTime.utc_now(:second), -stale_threshold_seconds, :second)

    from(t in Task,
      where: t.status == "processing" and t.heartbeat_at < ^cutoff
    )
    |> Repo.all()
  end

  # ── Events ──

  def create_event(attrs) do
    %TaskEvent{}
    |> TaskEvent.changeset(attrs)
    |> Repo.insert()
  end

  def create_event!(task, event_type, payload \\ nil) do
    %TaskEvent{}
    |> TaskEvent.changeset(%{
      task_id: task.id,
      project_id: task.project_id,
      user_id: task.user_id,
      event_type: event_type,
      payload: payload
    })
    |> Repo.insert!()
  end

  def list_events(task_id) do
    from(e in TaskEvent, where: e.task_id == ^task_id, order_by: [asc: e.id])
    |> Repo.all()
  end

  def list_project_events(project_id, after_id \\ 0, limit \\ 200) do
    from(e in TaskEvent,
      where: e.project_id == ^project_id and e.id > ^after_id,
      order_by: [asc: e.id],
      limit: ^limit
    )
    |> Repo.all()
  end
end
