defmodule Membrane.Integration.LinkingTest do
  use ExUnit.Case

  import Membrane.Testing.Assertions
  import Membrane.ParentSpec

  alias Membrane.{Tee, Testing}

  defmodule ImmediatelyCrashingFilter do
    use Membrane.Sink

    def_input_pad :input, demand_unit: :buffers, caps: :any, availability: :on_request

    @impl true
    def handle_init(_opts) do
      {:ok, %{pads: []}}
    end

    @impl true
    def handle_pad_added(pad, _ctx, state) do
      IO.inspect(pad, label: "$$$")

      {:ok, Map.update!(state, :pads, &([pad | &1]))}
    end

    @impl true
    def handle_prepared_to_playing(_ctx, state) do
      actions = Enum.map(state.pads, &({:demand, {&1, 1}}))
      {{:ok, actions}, state}
    end

    @impl true
    def handle_write(pad, buffer, _ctx, state) do
      IO.inspect(buffer)

      {{:ok, demand: {pad, 1}}, state}
    end
  end

  test "test" do
    {:ok, pipeline} = Testing.Pipeline.start_link(%Testing.Pipeline.Options{
      elements: [
        source: %Testing.Source{output: ['a', 'b', 'c']},
        tee: Tee.Master,
        sink: Testing.Sink
      ],
      links: [link(:source) |> to(:tee) |> to(:sink)]
    })
    # Testing.Pipeline.execute_actions(pipeline)
    Testing.Pipeline.play(pipeline)
    assert_pipeline_playback_changed(pipeline, _from, :playing)
    assert_sink_buffer(pipeline, :sink, %Membrane.Buffer{payload: 'a'})
    assert_sink_buffer(pipeline, :sink, %Membrane.Buffer{payload: 'b'})
    assert_sink_buffer(pipeline, :sink, %Membrane.Buffer{payload: 'c'})
    Membrane.Pipeline.stop_and_terminate(pipeline, blocking?: true)
  end
end
