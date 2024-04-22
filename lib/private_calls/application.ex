defmodule PrivateCalls.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PrivateCallsWeb.Telemetry,
      PrivateCalls.Repo,
      {DNSCluster, query: Application.get_env(:private_calls, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: PrivateCalls.PubSub},
      PrivateCallsWeb.UserPresence,
      # Start the Finch HTTP client for sending emails
      {Finch, name: PrivateCalls.Finch},
      # Start a worker by calling: PrivateCalls.Worker.start_link(arg)
      # {PrivateCalls.Worker, arg},
      # Start to serve requests, typically the last entry
      PrivateCallsWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PrivateCalls.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PrivateCallsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
