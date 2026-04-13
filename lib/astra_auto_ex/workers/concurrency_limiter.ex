defmodule AstraAutoEx.Workers.ConcurrencyLimiter do
  @moduledoc """
  ETS-based concurrency limiter per queue type.
  Tracks running task count and enforces limits.
  """
  use GenServer

  @default_limits %{image: 20, video: 5, voice: 10, text: 50}
  @table :concurrency_limiter

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def acquire(queue_type, task_id) do
    GenServer.call(__MODULE__, {:acquire, queue_type, task_id})
  end

  def release(queue_type, task_id) do
    GenServer.cast(__MODULE__, {:release, queue_type, task_id})
  end

  def running_count(queue_type) do
    :ets.match(@table, {{queue_type, :"$1"}, :_})
    |> length()
  end

  def available?(queue_type) do
    running_count(queue_type) < limit_for(queue_type)
  end

  def limit_for(queue_type) do
    Map.get(@default_limits, queue_type, 50)
  end

  # Server

  @impl true
  def init(_opts) do
    table = :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])
    {:ok, %{table: table}}
  end

  @impl true
  def handle_call({:acquire, queue_type, task_id}, _from, state) do
    current = running_count(queue_type)
    limit = limit_for(queue_type)

    if current < limit do
      :ets.insert(@table, {{queue_type, task_id}, System.monotonic_time()})
      {:reply, :ok, state}
    else
      {:reply, {:error, :at_capacity}, state}
    end
  end

  @impl true
  def handle_cast({:release, queue_type, task_id}, state) do
    :ets.delete(@table, {queue_type, task_id})
    {:noreply, state}
  end
end
