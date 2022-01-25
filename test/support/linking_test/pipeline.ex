defmodule Membrane.Support.LinkingTest.Pipeline do
  @moduledoc false
  use Membrane.Pipeline

  @impl true
  def handle_init(opts) do
    {:ok, %{testing_pid: opts.testing_pid}}
  end

  @impl true
  def handle_other({:spec, spec}, _ctx, state) do
    {{:ok, spec: spec}, state}
  end

  @impl true
  def handle_spec_started(_children, _ctx, state) do
    send(state.testing_pid, :spec_started)
    {:ok, state}
  end
end
