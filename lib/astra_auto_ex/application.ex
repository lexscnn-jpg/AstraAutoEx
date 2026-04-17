defmodule AstraAutoEx.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      AstraAutoExWeb.Telemetry,
      AstraAutoEx.Repo,
      {DNSCluster, query: Application.get_env(:astra_auto_ex, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: AstraAutoEx.PubSub},
      AstraAutoEx.Storage.Server,
      AstraAutoEx.AI.CircuitBreaker,
      AstraAutoEx.AI.LLMStreamer.task_supervisor_child_spec(),
      AstraAutoEx.Workers.Supervisor,
      # Start to serve requests, typically the last entry
      AstraAutoExWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: AstraAutoEx.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    AstraAutoExWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
