defmodule AstraAutoEx.Workflows do
  @moduledoc "Context for workflow/graph execution engine."
  import Ecto.Query
  alias AstraAutoEx.Repo
  alias AstraAutoEx.Workflows.{GraphRun, GraphStep, GraphEvent}

  # Aliases for engine compatibility
  def create_graph_run(attrs), do: create_run(attrs)
  def get_graph_run!(id), do: get_run!(id)
  def update_graph_run(run, attrs), do: update_run(run, attrs)

  def create_run(attrs), do: %GraphRun{} |> GraphRun.changeset(attrs) |> Repo.insert()
  def get_run!(id), do: Repo.get!(GraphRun, id)
  def update_run(run, attrs), do: run |> GraphRun.changeset(attrs) |> Repo.update()

  def list_runs(project_id, opts \\ []) do
    status = Keyword.get(opts, :status)

    query =
      from(r in GraphRun, where: r.project_id == ^project_id, order_by: [desc: r.inserted_at])

    query = if status, do: where(query, [r], r.status == ^status), else: query
    Repo.all(query)
  end

  def create_graph_step(attrs), do: create_step(attrs)
  def create_step(attrs), do: %GraphStep{} |> GraphStep.changeset(attrs) |> Repo.insert()
  def update_step(step, attrs), do: step |> GraphStep.changeset(attrs) |> Repo.update()

  def list_graph_steps(run_id), do: list_steps(run_id)

  def list_steps(run_id) do
    from(s in GraphStep, where: s.run_id == ^run_id, order_by: [asc: s.step_index]) |> Repo.all()
  end

  def update_graph_step_by_step_id(run_id, step_id, attrs) do
    case Repo.get_by(GraphStep, run_id: run_id, step_id: step_id) do
      nil -> {:error, :not_found}
      step -> update_step(step, attrs)
    end
  end

  def create_event(attrs), do: %GraphEvent{} |> GraphEvent.changeset(attrs) |> Repo.insert()

  def list_events(run_id, after_seq \\ 0) do
    from(e in GraphEvent,
      where: e.run_id == ^run_id and e.seq > ^after_seq,
      order_by: [asc: e.seq]
    )
    |> Repo.all()
  end
end
