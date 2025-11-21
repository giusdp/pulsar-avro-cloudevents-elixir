defmodule Cloudevents.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @app_supervisor Cloudevents.Supervisor

  def start(config) do
    start(:normal, config)
  end

  def start_link(config), do: start(config)

  @impl true
  def start(_type, opts) do
    avrora_opts = Keyword.get(opts, :avrora, Application.get_env(:pulsar_avro_cloudevents, :avrora, []))
    Application.put_env(:avrora, :avrora, avrora_opts)

    children = [
      Avrora
    ]

    sup_opts = [strategy: :one_for_one, name: @app_supervisor]
    Supervisor.start_link(children, sup_opts)
  end
end
