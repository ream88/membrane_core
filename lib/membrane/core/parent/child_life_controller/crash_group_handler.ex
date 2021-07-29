defmodule Membrane.Core.Parent.ChildLifeController.CrashGroupHandler do
  @moduledoc false
  # A module responsible for managing crash groups inside the state of pipeline.
  use Membrane.Core.StateDispatcher, restrict: :pipeline

  alias Membrane.ParentSpec
  alias Membrane.Core.{Parent, Pipeline, StateDispatcher}
  alias Membrane.Core.Parent.CrashGroup

  @spec add_crash_group(
          ParentSpec.crash_group_spec_t(),
          [Membrane.Child.name_t()],
          [pid()],
          Pipeline.State.t()
        ) ::
          {:ok, Pipeline.State.t()}
  def add_crash_group(group_spec, children_names, children_pids, state) do
    {group_name, mode} = group_spec

    state =
      state
      |> StateDispatcher.get_pipeline(:crash_groups)
      |> Map.update!(group_name, fn
        %CrashGroup{
          members: current_children_names,
          alive_members_pids: current_alive_members
        } = group ->
          %CrashGroup{
            group
            | members: current_children_names ++ children_names,
              alive_members_pids: current_alive_members ++ children_pids
          }

        nil ->
          %CrashGroup{
            name: group_name,
            mode: mode,
            members: children_names,
            alive_members_pids: children_pids
          }
      end)
      |> then(&StateDispatcher.update_pipeline(state, crash_groups: &1))

    {:ok, state}
  end

  @spec remove_crash_group_if_empty(Pipeline.State.t(), CrashGroup.name_t()) ::
          {:removed | :not_removed, Pipeline.State.t()}
  def remove_crash_group_if_empty(state, group_name) do
    %CrashGroup{alive_members_pids: alive_members_pids} =
      StateDispatcher.get_pipeline(state, :crash_groups)[group_name]

    if alive_members_pids == [] do
      state =
        state
        |> StateDispatcher.get_pipeline(:crash_groups)
        |> Map.delete(group_name)
        |> then(&StateDispatcher.update_pipeline(state, crash_groups: &1))

      {:removed, state}
    else
      {:not_removed, state}
    end
  end

  @spec remove_member_of_crash_group(Pipeline.State.t(), CrashGroup.name_t(), pid()) ::
          Pipeline.State.t()
  def remove_member_of_crash_group(state, group_name, pid) do
    state
    |> StateDispatcher.get_pipeline(:crash_groups)
    |> update_in([group_name, :alive_members_pids], &List.delete(&1, pid))
    |> then(&StateDispatcher.update_pipeline(state, crash_groups: &1))
  end

  @spec get_group_by_member_pid(pid(), Parent.state_t()) ::
          {:ok, CrashGroup.t()} | {:error, :not_member}
  def get_group_by_member_pid(member_pid, state) do
    crash_group =
      state
      |> StateDispatcher.get_pipeline(:crash_groups)
      |> Map.values()
      |> Enum.find(fn %CrashGroup{alive_members_pids: alive_members_pids} ->
        member_pid in alive_members_pids
      end)

    case crash_group do
      %CrashGroup{} -> {:ok, crash_group}
      nil -> {:error, :not_member}
    end
  end

  @spec set_triggered(Pipeline.State.t(), CrashGroup.name_t(), boolean()) :: Pipeline.State.t()
  def set_triggered(state, group_name, value \\ true) do
    state
    |> StateDispatcher.get_pipeline(:crash_groups)
    |> put_in([group_name, :triggered?], value)
    |> then(&StateDispatcher.update_pipeline(state, crash_groups: &1))
  end
end
