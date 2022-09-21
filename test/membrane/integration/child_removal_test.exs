defmodule Membrane.Integration.ChildRemovalTest do
  use Bunch
  use ExUnit.Case, async: false

  import Membrane.Testing.Assertions

  alias Membrane.Core.Message
  alias Membrane.Support.ChildRemovalTest
  alias Membrane.Testing

  require Message

  test "Element can be removed when pipeline is in stopped state" do
    pipeline_pid =
      Testing.Pipeline.start_link_supervised!(
        module: ChildRemovalTest.Pipeline,
        custom_args: %{
          source: Testing.Source,
          filter1: ChildRemovalTest.Filter,
          filter2: ChildRemovalTest.Filter,
          filter3: ChildRemovalTest.Filter,
          sink: Testing.Sink
        }
      )

    Process.monitor(pipeline_pid)

    [filter_pid1, filter_pid2, filter_pid3] =
      [:filter1, :filter2, :filter3]
      |> Enum.map(&get_filter_pid(&1, pipeline_pid))

    ChildRemovalTest.Pipeline.remove_child(pipeline_pid, :filter2)

    assert_pid_dead(filter_pid2)
    assert_pid_alive(pipeline_pid)
    assert_pid_alive(filter_pid1)
    assert_pid_alive(filter_pid3)
  end

  test "Element can be removed when pipeline is in playing state" do
    pipeline_pid =
      Testing.Pipeline.start_link_supervised!(
        module: ChildRemovalTest.Pipeline,
        custom_args: %{
          source: Testing.Source,
          filter1: ChildRemovalTest.Filter,
          filter2: ChildRemovalTest.Filter,
          filter3: ChildRemovalTest.Filter,
          sink: Testing.Sink
        }
      )

    Process.monitor(pipeline_pid)

    [filter_pid1, filter_pid2, filter_pid3] =
      [:filter1, :filter2, :filter3]
      |> Enum.map(&get_filter_pid(&1, pipeline_pid))

    assert_pipeline_play(pipeline_pid)
    assert_pipeline_notified(pipeline_pid, :filter1, :playing)
    assert_pipeline_notified(pipeline_pid, :filter2, :playing)
    assert_pipeline_notified(pipeline_pid, :filter3, :playing)

    ChildRemovalTest.Pipeline.remove_child(pipeline_pid, :filter2)

    assert_pid_dead(filter_pid2)
    assert_pid_alive(filter_pid1)
    assert_pid_alive(filter_pid3)
  end

  @doc """
  In this scenario we make `filter3` switch between prepare and playing state slowly
  so that it has to store incoming buffers in PlaybackBuffer. When the `filter1` dies,
  and `filter2` tries to actually enter playing it SHOULD NOT have any buffers there yet.

  source -- filter1 -- [input1] filter2 -- [input1] filter3 -- sink

  """
  test "When PlaybackBuffer is evaluated there is no buffers from removed element" do
    pipeline_pid =
      Testing.Pipeline.start_link_supervised!(
        module: ChildRemovalTest.Pipeline,
        custom_args: %{
          source: Testing.Source,
          filter1: ChildRemovalTest.Filter,
          filter2: ChildRemovalTest.Filter,
          filter3: %ChildRemovalTest.Filter{playing_delay: prepared_to_playing_delay()},
          sink: Testing.Sink
        }
      )

    Process.monitor(pipeline_pid)

    [filter_pid1, filter_pid2, filter_pid3] =
      [:filter1, :filter2, :filter3]
      |> Enum.map(&get_filter_pid(&1, pipeline_pid))

    assert_pipeline_play(pipeline_pid)
    assert_pipeline_notified(pipeline_pid, :filter1, :playing)
    assert_pipeline_notified(pipeline_pid, :filter2, :playing)
    assert_pipeline_notified(pipeline_pid, :filter3, :playing)

    ChildRemovalTest.Pipeline.remove_child(pipeline_pid, :filter2)

    assert_pid_dead(filter_pid2)
    assert_pid_alive(filter_pid1)
    assert_pid_alive(filter_pid3)
  end

  defmodule FilterToBeRemoved do
    use Membrane.Filter

    def_input_pad :input, caps: :any, demand_mode: :auto
    def_output_pad :output, caps: :any, demand_mode: :auto

    @impl true
    def handle_init(_opts) do
      {:ok, %{}}
    end

    @impl true
    def handle_process(:input, buffers, _context, state) do
      {{:ok, buffer: {:output, buffers}}, state}
    end
  end

  defmodule SourceNotyfingWhenPadRemoved do
    use Membrane.Source

    def_output_pad :first, caps: :any, demand_mode: :auto, availability: :on_request
    def_output_pad :second, caps: :any, demand_mode: :auto, availability: :on_request
    def_output_pad :third, caps: :any, demand_mode: :auto, availability: :on_request
    def_output_pad :fourth, caps: :any, demand_mode: :auto, availability: :on_request
    def_output_pad :fifth, caps: :any, demand_mode: :auto, availability: :on_request

    @impl true
    def handle_init(_opts) do
      {:ok, %{}}
    end

    @impl true
    def handle_pad_removed(pad, _ctx, state) do
      {{:ok, notify_parent: {:pad_removed, pad}}, state}
    end
  end

  defmodule ChildRemovingPipeline do
    use Membrane.Pipeline
    import ParentSpec

    @impl true
    def handle_init(_opts) do
      structure1 = [spawn_child(:source, SourceNotyfingWhenPadRemoved)]
      spec1 = %ParentSpec{structure: structure1}

      structure2 = [
        link(:source) |> via_out(:first) |> to_new(:filter1, FilterToBeRemoved),
        link(:source) |> via_out(:second) |> to_new(:filter2, FilterToBeRemoved)
      ]

      spec2 = %ParentSpec{structure: structure2, children_group_id: :first_crash_group}

      structure3 = [link(:source) |> via_out(:third) |> to_new(:filter3, FilterToBeRemoved)]
      spec3 = %ParentSpec{structure: structure3, children_group_id: :first_crash_group}

      structure4 = [
        link(:source) |> via_out(:fourth) |> to_new(:filter4, FilterToBeRemoved),
        link(:source) |> via_out(:fifth) |> to_new(:filter5, FilterToBeRemoved)
      ]

      spec4 = %ParentSpec{structure: structure4, children_group_id: :second_crash_group}

      {{:ok, spec: spec1, spec: spec2, spec: spec3, spec: spec4}, %{}}
    end
  end

  test "if all the children from the children group are removed" do
    pipeline_pid = Testing.Pipeline.start_link_supervised!(module: ChildRemovingPipeline)

    Testing.Pipeline.execute_actions(pipeline_pid, [
      {:remove_child, {:children_group_id, :first_crash_group}}
    ])

    assert_pipeline_notified(pipeline_pid, :source, {:pad_removed, {Membrane.Pad, :first, _ref}})
    assert_pipeline_notified(pipeline_pid, :source, {:pad_removed, {Membrane.Pad, :second, _ref}})
    assert_pipeline_notified(pipeline_pid, :source, {:pad_removed, {Membrane.Pad, :third, _ref}})

    refute_pipeline_notified(pipeline_pid, :source, {:pad_removed, {Membrane.Pad, :fourth, _ref}})
    refute_pipeline_notified(pipeline_pid, :source, {:pad_removed, {Membrane.Pad, :fifth, _ref}})
  end

  #############
  ## HELPERS ##
  #############

  defp assert_pid_dead(pid) do
    assert_receive {:DOWN, _, :process, ^pid, :normal}
  end

  defp assert_pid_alive(pid) do
    refute_receive {:DOWN, _, :process, ^pid, _}
  end

  defp get_filter_pid(ref, pipeline_pid) do
    state = :sys.get_state(pipeline_pid)
    pid = state.children[ref].pid
    Process.monitor(pid)
    pid
  end

  defp prepared_to_playing_delay, do: 300
end
