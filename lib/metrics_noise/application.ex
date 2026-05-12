defmodule MetricsNoise.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      MetricsNoiseWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:metrics_noise, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: MetricsNoise.PubSub},
      MetricsNoise.MetricsStore,
      MetricsNoiseWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MetricsNoise.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MetricsNoiseWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
