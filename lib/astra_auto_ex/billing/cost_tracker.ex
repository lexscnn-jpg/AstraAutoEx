defmodule AstraAutoEx.Billing.CostTracker do
  @moduledoc """
  Tracks API call costs. Insert a log entry before/after every AI API call.
  """

  alias AstraAutoEx.Repo
  alias AstraAutoEx.Billing.ApiCallLog

  def log_call(attrs) do
    %ApiCallLog{}
    |> ApiCallLog.changeset(attrs)
    |> Repo.insert()
  end

  def log_call!(attrs) do
    %ApiCallLog{}
    |> ApiCallLog.changeset(attrs)
    |> Repo.insert!()
  end

  @doc "Wrap an API call with automatic cost logging"
  def track(user_id, project_id, model_key, model_type, pipeline_step, fun) do
    start = System.monotonic_time(:millisecond)

    try do
      result = fun.()
      duration = System.monotonic_time(:millisecond) - start

      log_call(%{
        user_id: user_id,
        project_id: project_id,
        model_key: model_key,
        model_type: model_type,
        pipeline_step: pipeline_step,
        status: "success",
        duration_ms: duration
      })

      result
    rescue
      e ->
        duration = System.monotonic_time(:millisecond) - start

        log_call(%{
          user_id: user_id,
          project_id: project_id,
          model_key: model_key,
          model_type: model_type,
          pipeline_step: pipeline_step,
          status: "failed",
          duration_ms: duration,
          metadata: %{"error" => Exception.message(e)}
        })

        reraise e, __STACKTRACE__
    end
  end
end
