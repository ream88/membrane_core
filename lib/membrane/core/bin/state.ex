defmodule Membrane.Core.Bin.State do
  @moduledoc false

  # Record representing state of a bin. It is a part of the private API.
  # It does not represent state of bins you construct, it's a state used
  # internally in Membrane.

  alias Membrane.Core.{Playback, Timer}
  alias Membrane.Core.Bin.LinkingBuffer
  alias Membrane.Core.Child.PadModel
  alias Membrane.Core.Parent.Link
  alias Membrane.Core.Parent.ChildrenModel
  alias Membrane.{Child, Clock, Sync}
  alias Membrane.Core.Parent.CrashGroup

  require Record

  @type bin ::
          record(
            :bin,
            internal_state: Membrane.Bin.state_t() | nil,
            playback: Playback.t(),
            module: module,
            children: ChildrenModel.children_t(),
            name: Membrane.Bin.name_t() | nil,
            pads: PadModel.pads_t() | nil,
            watcher: pid | nil,
            controlling_pid: pid | nil,
            linking_buffer: LinkingBuffer.t(),
            links: [Link.t()],
            crash_groups: %{CrashGroup.name_t() => CrashGroup.t()},
            synchronization: %{
              timers: %{Timer.id_t() => Timer.t()},
              parent_clock: Clock.t(),
              latency: non_neg_integer(),
              stream_sync: Sync.t(),
              clock: Clock.t() | nil,
              clock_proxy: Clock.t(),
              clock_provider: %{
                clock: Clock.t() | nil,
                provider: Child.name_t() | nil,
                choice: :auto | :manual
              }
            },
            children_log_metadata: Keyword.t()
          )

  @type t :: bin()

  Record.defrecord(:bin, [
    :module,
    :synchronization,
    internal_state: nil,
    playback: %Playback{},
    children: %{},
    name: nil,
    pads: nil,
    watcher: nil,
    controlling_pid: nil,
    crash_groups: %{},
    # FIXME: LinkingBuffer.new() results in ElixirLS deadlock
    linking_buffer: Map.new(),
    children_log_metadata: [],
    links: []
  ])
end
