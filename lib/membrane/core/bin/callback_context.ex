defmodule Membrane.Core.Bin.CallbackContext do
  @moduledoc false
  use Membrane.Core.CallbackContext,
    playback_state: Membrane.PlaybackState.t(),
    clock: Membrane.Clock.t(),
    parent_clock: Membrane.Clock.t(),
    pads: %{Membrane.Pad.ref_t() => Membrane.Pad.Data.t()},
    name: Membrane.Bin.name_t(),
    children: %{Membrane.Child.name_t() => Membrane.ChildEntry.t()}

  use Membrane.Core.StateDispatcher

  alias Membrane.Core.StateDispatcher

  @impl true
  def extract_default_fields(state, args) do
    quote do
      [
        playback_state: StateDispatcher.get_bin(unquote(state), :playback).state,
        clock: StateDispatcher.get_bin(unquote(state), :synchronization).clock,
        parent_clock: StateDispatcher.get_bin(unquote(state), :synchronization).parent_clock,
        pads: StateDispatcher.get_bin(unquote(state), :pads).data,
        name: StateDispatcher.get_bin(unquote(state), :name),
        children: StateDispatcher.get_bin(unquote(state), :children)
      ]
    end ++ args
  end
end
