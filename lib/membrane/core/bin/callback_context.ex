defmodule Membrane.Core.Bin.CallbackContext do
  @moduledoc false

  use Membrane.Core.CallbackContext,
    clock: Membrane.Clock.t(),
    parent_clock: Membrane.Clock.t(),
    pads: %{Membrane.Pad.ref_t() => Membrane.Bin.PadData.t()},
    name: Membrane.Bin.name_t(),
    children: %{Membrane.Child.name_t() => Membrane.ChildEntry.t()},
    playback: Membrane.Playback.t()

  @impl true
  def extract_default_fields(state, args) do
    quote do
      [
        clock: unquote(state).synchronization.clock,
        parent_clock: unquote(state).synchronization.parent_clock,
        pads: unquote(state).pads_data,
        name: unquote(state).name,
        children: unquote(state).children,
        playback: unquote(state).playback
      ]
    end ++ args
  end
end
