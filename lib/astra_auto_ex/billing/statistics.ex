defmodule AstraAutoEx.Billing.Statistics do
  @moduledoc """
  Query billing statistics by model/project/date.
  """

  import Ecto.Query
  alias AstraAutoEx.Repo
  alias AstraAutoEx.Billing.ApiCallLog

  def by_model(user_id) do
    ApiCallLog
    |> where(user_id: ^user_id)
    |> group_by([l], [l.model_key, l.model_type])
    |> select([l], %{
      model_key: l.model_key,
      model_type: l.model_type,
      total_calls: count(l.id),
      success_count: count(fragment("CASE WHEN ? = 'success' THEN 1 END", l.status)),
      failed_count: count(fragment("CASE WHEN ? = 'failed' THEN 1 END", l.status)),
      total_cost: sum(l.cost_estimate),
      avg_duration_ms: avg(l.duration_ms)
    })
    |> Repo.all()
  end

  def by_project(user_id) do
    ApiCallLog
    |> where(user_id: ^user_id)
    |> where([l], not is_nil(l.project_id))
    |> group_by([l], [l.project_id, l.project_name])
    |> select([l], %{
      project_id: l.project_id,
      project_name: l.project_name,
      total_calls: count(l.id),
      total_cost: sum(l.cost_estimate),
      steps: fragment("array_agg(DISTINCT ?)", l.pipeline_step)
    })
    |> Repo.all()
  end

  def by_date(user_id, days \\ 30) do
    since = DateTime.utc_now() |> DateTime.add(-days * 86400, :second)

    ApiCallLog
    |> where(user_id: ^user_id)
    |> where([l], l.inserted_at >= ^since)
    |> group_by([l], fragment("DATE(?)", l.inserted_at))
    |> select([l], %{
      date: fragment("DATE(?)", l.inserted_at),
      total_calls: count(l.id),
      total_cost: sum(l.cost_estimate),
      success_count: count(fragment("CASE WHEN ? = 'success' THEN 1 END", l.status))
    })
    |> order_by([l], fragment("DATE(?)", l.inserted_at))
    |> Repo.all()
  end

  @doc "Get summary totals for a user: total calls and total cost."
  def summary(user_id) do
    result =
      ApiCallLog
      |> where(user_id: ^user_id)
      |> select([l], %{
        total_calls: count(l.id),
        total_cost: sum(l.cost_estimate)
      })
      |> Repo.one()

    %{
      total_calls: result.total_calls || 0,
      total_cost: result.total_cost || Decimal.new(0)
    }
  end

  def recent_calls(user_id, limit \\ 50) do
    ApiCallLog
    |> where(user_id: ^user_id)
    |> order_by([l], desc: l.inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end
end
