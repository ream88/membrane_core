defmodule Membrane.Core.Child.LifecycleController do
  @moduledoc false
  use Bunch

  alias Membrane.Clock
  alias Membrane.Core.{Child, Message}
  alias Membrane.Core.Child.PadModel
  alias Membrane.Core.StateDispatcher

  require Membrane.Core.Bin.State
  require Membrane.Core.Element.State
  require Membrane.Core.StateDispatcher
  require Message
  require PadModel

  @spec handle_controlling_pid(pid, Child.state_t()) :: {:ok, Child.state_t()}
  def handle_controlling_pid(pid, state),
    do: {:ok, StateDispatcher.update_child(state, controlling_pid: pid)}

  @spec handle_watcher(pid, Child.state_t()) :: {{:ok, %{clock: Clock.t()}}, Child.state_t()}
  def handle_watcher(watcher, state),
    do:
      {{:ok, %{clock: state.synchronization.clock}},
       StateDispatcher.update_child(state, watcher: watcher)}

  @spec unlink(Child.state_t()) :: :ok
  def unlink(state) do
    state.pads.data
    |> Map.values()
    |> Enum.each(&Message.send(&1.pid, :handle_unlink, &1.other_ref))
  end
end
