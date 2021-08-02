defmodule Membrane.Core.Pipeline.CallbackContext do
  @moduledoc false

  use Membrane.Core.CallbackContext,
    playback_state: Membrane.PlaybackState.t(),
    clock: Membrane.Clock.t(),
    children: %{Membrane.Child.name_t() => Membrane.ChildEntry.t()}

  alias Membrane.Core.StateDispatcher

  require StateDispatcher

  @impl true
  def extract_default_fields(state, args) do
    quote do
      [
        playback_state: StateDispatcher.get_pipeline(unquote(state), :playback).state,
        clock: StateDispatcher.get_pipeline(unquote(state), :synchronization).clock_proxy,
        children: StateDispatcher.get_pipeline(unquote(state), :children)
      ]
    end ++ args
  end
end
