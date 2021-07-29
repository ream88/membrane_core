defmodule Membrane.Core.Child.LifecycleController do
  @moduledoc false
  use Bunch
  use Membrane.Core.StateDispatcher, restrict: :child

  alias Membrane.Clock
  alias Membrane.Core.{Child, Message, StateDispatcher}
  alias Membrane.Core.Child.PadModel

  require Message
  require PadModel

  @spec handle_controlling_pid(pid, Child.state_t()) :: {:ok, Child.state_t()}
  def handle_controlling_pid(pid, state),
    do: {:ok, StateDispatcher.update_child(state, controlling_pid: pid)}

  @spec handle_watcher(pid, Child.state_t()) :: {{:ok, %{clock: Clock.t()}}, Child.state_t()}
  def handle_watcher(watcher, state) do
    synchronization = StateDispatcher.get_child(state, :synchronization)

    {{:ok, %{clock: synchronization.clock}},
     StateDispatcher.update_child(state, watcher: watcher)}
  end

  @spec unlink(Child.state_t()) :: :ok
  def unlink(state),
    do:
      state
      |> StateDispatcher.get_child(:pads)
      |> Map.get(:data)
      |> Map.values()
      |> Enum.each(&Message.send(&1.pid, :handle_unlink, &1.other_ref))
end
