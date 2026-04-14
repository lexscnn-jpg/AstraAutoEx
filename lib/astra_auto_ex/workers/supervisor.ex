defmodule AstraAutoEx.Workers.Supervisor do
  @moduledoc """
  Supervision tree for the task worker system.
  Uses rest_for_one strategy: if ConcurrencyLimiter crashes,
  TaskScheduler and runners restart too.
  """
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      AstraAutoEx.Workers.ConcurrencyLimiter,
      {DynamicSupervisor, name: AstraAutoEx.Workers.TaskRunnerSupervisor, strategy: :one_for_one},
      AstraAutoEx.Workers.TaskScheduler,
      AstraAutoEx.Workers.AsyncPollWorker
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
