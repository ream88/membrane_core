defmodule Membrane.Core.Application do
  use Application

  def start(_type, _args) do
    Membrane.Core.Metrics.init()

    children = [
      {Registry, keys: :duplicate, name: Membrane.Core.Registry.get_registry_name()}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: __MODULE__)
  end
end
