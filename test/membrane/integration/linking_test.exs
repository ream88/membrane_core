defmodule Membrane.Integration.LinkingTest do
  use ExUnit.Case

  import Membrane.Testing.Assertions
  import Membrane.ParentSpec

  alias Membrane.Support.LinkingTest
  alias Membrane.Testing

  test "test" do
    {:ok, pipeline} =
      Testing.Pipeline.start_link(%Testing.Pipeline.Options{
        module: Membrane.Support.LinkingTest.Pipeline,
        custom_args: %{testing_pid: self()}
      })

    elements = [
      source: %Testing.Source{output: ['a', 'b', 'c']},
      tee: LinkingTest.Tee,
      sink_1: Testing.Sink
    ]

    sink_2 = [
      sink_2: Testing.Sink
    ]

    elements_spec = %Membrane.ParentSpec{
      children: elements,
      crash_group: {:group_1, :temporary}
    }

    sink_2_spec = %Membrane.ParentSpec{
      children: sink_2,
      crash_group: {:group_2, :temporary}
    }

    links_spec = %Membrane.ParentSpec{
      links: [
        link(:source) |> to(:tee) |> to(:sink_1),
        link(:tee) |> to(:sink_2)
      ]
    }

    send(pipeline, {:spec, elements_spec})
    assert_receive(:spec_started)
    send(pipeline, {:spec, sink_2_spec})
    assert_receive(:spec_started)

    Process.exit(get_pid(:sink_2, pipeline), :kill)
    send(pipeline, {:spec, links_spec})
    assert_receive(:spec_started)

    Testing.Pipeline.play(pipeline)
    assert_pipeline_playback_changed(pipeline, _from, :playing)
    assert_sink_buffer(pipeline, :sink_1, %Membrane.Buffer{payload: 'a'})
    assert_sink_buffer(pipeline, :sink_1, %Membrane.Buffer{payload: 'b'})
    assert_sink_buffer(pipeline, :sink_1, %Membrane.Buffer{payload: 'c'})
    Membrane.Pipeline.stop_and_terminate(pipeline, blocking?: true)
  end

  defp get_pid(ref, parent_pid) do
    state = :sys.get_state(parent_pid)
    state.children[ref].pid
  end
end
