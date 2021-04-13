defmodule Membrane.Core.Parent.ChildLifeController.CrashGroupHandler do
  @moduledoc """
  A module responsible for managing crash groups inside the state of pipeline.
  """

  alias Membrane.ParentSpec
  alias Membrane.Core.Pipeline
  alias Membrane.Core.Parent.CrashGroup

  # for now only Pipeline.State has crash_groups field
  @spec add_crash_group(ParentSpec.crash_group_spec_t(), [pid()], Pipeline.State.t()) ::
          {:ok, Pipeline.State.t()}
  def add_crash_group(group_spec, children_pids, state) do
    {group_name, mode} = group_spec
    crash_group = %CrashGroup{name: group_name, mode: mode, members: children_pids}

    {:ok, %{state | crash_groups: Map.put(state.crash_groups, group_name, crash_group)}}
  end

  @spec remove_crash_group_if_empty(Pipeline.State.t(), CrashGroup.name_t()) ::
          Pipeline.State.t()
  def remove_crash_group_if_empty(state, group_name) do
    if state.crash_groups[group_name] == [] do
      crash_groups = state.crash_groups |> Map.delete(group_name)

      %{state | crash_groups: crash_groups}
    else
      state
    end
  end

  @spec remove_member_of_crash_group(Pipeline.State.t(), CrashGroup.name_t(), pid()) ::
          Pipeline.State.t()
  def remove_member_of_crash_group(state, group_name, pid) do
    if group_name in state.crash_groups,
      do: state,
      else:
        state
        |> Bunch.Struct.update_in(
          [:crash_groups, group_name, :members],
          &(&1 |> List.delete(pid))
        )
  end
end
