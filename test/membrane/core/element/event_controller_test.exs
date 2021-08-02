defmodule Membrane.Core.Element.EventControllerTest do
  use ExUnit.Case

  alias Membrane.Core.Element.EventController
  alias Membrane.Core.{Events, InputBuffer, Message, StateDispatcher}
  alias Membrane.Event
  alias Membrane.Pad.Data

  require Membrane.Core.Message
  require StateDispatcher

  defmodule MockEventHandlingElement do
    use Membrane.Filter

    def_output_pad :output, caps: :any

    @impl true
    def handle_event(_pad, %Membrane.Event.Discontinuity{}, _ctx, state) do
      {{:error, :cause}, state}
    end

    def handle_event(_pad, %Membrane.Event.Underrun{}, _ctx, state) do
      {:ok, state}
    end
  end

  setup do
    input_buf = InputBuffer.init(:buffers, self(), :some_pad, "test", preferred_size: 10)

    state =
      %{
        module: MockEventHandlingElement,
        name: :test_name,
        parent_clock: nil,
        sync: nil
      }
      |> StateDispatcher.element()
      |> StateDispatcher.update_element(
        watcher: self(),
        type: :filter,
        pads: %{
          data: %{
            input: %Data{
              ref: :input,
              accepted_caps: :any,
              direction: :input,
              pid: self(),
              mode: :pull,
              start_of_stream?: false,
              end_of_stream?: false,
              input_buf: input_buf,
              demand: 0
            }
          }
        }
      )

    state =
      state
      |> StateDispatcher.get_element(:playback)
      |> Map.put(:state, :playing)
      |> then(&StateDispatcher.update_element(state, playback: &1))

    assert_received Message.new(:demand, 10, for_pad: :some_pad)
    [state: state]
  end

  describe "Event controller handles special event" do
    setup %{state: state} do
      {:ok, sync} = start_supervised({Membrane.Sync, []})

      state =
        state
        |> StateDispatcher.get_element(:synchronization)
        |> Map.put(:stream_sync, sync)
        |> then(&StateDispatcher.update_element(state, synchronization: &1))

      [state: state]
    end

    test "start of stream successfully", %{state: state} do
      assert {:ok, state} = EventController.handle_event(:input, %Events.StartOfStream{}, state)

      assert state
             |> StateDispatcher.get_element(:pads)
             |> get_in([:data, :input, :start_of_stream?])
    end

    test "ignoring end of stream when there was no start of stream prior", %{state: state} do
      assert {:ok, state} = EventController.handle_event(:input, %Events.EndOfStream{}, state)

      refute state
             |> StateDispatcher.get_element(:pads)
             |> get_in([:data, :input, :end_of_stream?])

      refute state
             |> StateDispatcher.get_element(:pads)
             |> get_in([:data, :input, :start_of_stream?])
    end

    test "end of stream successfully", %{state: state} do
      state = put_start_of_stream(state, :input)

      assert {:ok, state} = EventController.handle_event(:input, %Events.EndOfStream{}, state)
      assert state |> StateDispatcher.get_element(state, :pads).data.input.end_of_stream?
    end
  end

  describe "Event controller handles normal events" do
    test "succesfully when callback module returns {:ok, state}", %{state: state} do
      assert {:ok, ^state} = EventController.handle_event(:input, %Event.Underrun{}, state)
    end

    test "processing error returned by callback module", %{state: state} do
      assert {{:error, {:handle_event, :cause}}, ^state} =
               EventController.handle_event(:input, %Event.Discontinuity{}, state)
    end
  end

  defp put_start_of_stream(state, pad_ref) do
    state
    |> StateDispatcher.get_element(:pads)
    |> Bunch.Access.update_in([:data, pad_ref], fn data ->
      %{data | start_of_stream?: true}
    end)
    |> then(&StateDispatcher.update_element(state, pads: &1))
  end
end
