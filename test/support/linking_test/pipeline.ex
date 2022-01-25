defmodule Membrane.Support.LinkingTest.Pipeline do
  @moduledoc false
  use Membrane.Pipeline

  @impl true
  def handle_init(opts) do
    {:ok, %{testing_pid: opts.testing_pid}}
  end

  @impl true
  def handle_other({:start_spec, spec}, _ctx, state) do
    {{:ok, spec: spec}, state}
  end

  @impl true
  def handle_other({:start_spec_and_kill, spec, element_name}, ctx, state) do
    pid = ctx.children[element_name].pid
    IO.inspect(pid)
    Process.exit(pid, :kill)
    {{:ok, spec: spec}, state}
  end

  @impl true
  def handle_spec_started(_children, _ctx, state) do
    send(state.testing_pid, :spec_started)
    {:ok, state}
  end
end
