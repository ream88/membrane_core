defmodule Membrane.Core.Element.CallbackContext do
  @moduledoc false

  use Membrane.Core.CallbackContext,
    pads: %{Membrane.Pad.ref_t() => Membrane.Pad.Data.t()},
    playback_state: Membrane.PlaybackState.t(),
    clock: Membrane.Clock.t() | nil,
    parent_clock: Membrane.Clock.t() | nil,
    name: Membrane.Element.name_t()

  alias Membrane.Core.StateDispatcher

  use StateDispatcher

  @impl true
  def extract_default_fields(state, args) do
    quote do
      [
        playback_state: StateDispatcher.get_element(unquote(state), :playback).state,
        pads: StateDispatcher.get_element(unquote(state), :pads).data,
        clock: StateDispatcher.get_element(unquote(state), :synchronization).clock,
        parent_clock: StateDispatcher.get_element(unquote(state), :synchronization).parent_clock,
        name: StateDispatcher.get_element(unquote(state), :name)
      ]
    end ++ args
  end
end
