defmodule Membrane.Support.AcceptedFormatTest.RestrictiveSink do
  @moduledoc """
  Sink used in accepted format tests.
  Sends a message with its own pid to the process specified in the options.
  Notifies parent on stream format arrival.
  """

  use Membrane.Endpoint

  alias Membrane.Support.AcceptedFormatTest.StreamFormat

  def_input_pad :input,
    accepted_format: %StreamFormat{format: StreamFormat.AcceptedByAll},
    availability: :always,
    mode: :push

  def_options test_pid: [type: :pid]

  @impl true
  def handle_init(_ctx, %__MODULE__{test_pid: test_pid}) do
    send(test_pid, {:my_pid, __MODULE__, self()})
    {[], %{test_pid: test_pid}}
  end

  @impl true
  def handle_stream_format(:input, stream_format, _ctx, state) do
    {[notify_parent: {:stream_format_received, stream_format}], state}
  end
end
