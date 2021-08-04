defmodule Membrane.Core.Parent.ChildrenModel do
  @moduledoc false
  use Membrane.Core.StateDispatcher

  alias Membrane.{Child, ChildEntry}
  alias Membrane.Core.Parent
  alias Membrane.Core.StateDispatcher

  @type children_t :: %{Child.name_t() => ChildEntry.t()}

  @spec add_child(Parent.state_t(), Child.name_t(), ChildEntry.t()) ::
          {:ok | {:error, {:duplicate_child, Child.name_t()}}, Parent.state_t()}
  def add_child(state, child, data) do
    children = StateDispatcher.get_parent(state, :children)

    if Map.has_key?(children, child) do
      {{:error, {:duplicate_child, child}}, state}
    else
      {:ok, StateDispatcher.update_parent(state, children: children |> Map.put(child, data))}
    end
  end

  @spec get_child_data(Parent.state_t(), Child.name_t()) ::
          {:ok, child_data :: ChildEntry.t()}
          | {:error, {:unknown_child, Child.name_t()}}
  def get_child_data(state, child) do
    state
    |> StateDispatcher.get_parent(:children)
    |> Map.get(child)
    |> Bunch.error_if_nil({:unknown_child, child})
  end

  @spec pop_child(Parent.state_t(), Child.name_t()) ::
          {{:ok, child_data :: ChildEntry.t()}
           | {:error, {:unknown_child, Child.name_t()}}, Parent.state_t()}
  def pop_child(state, child) do
    children = StateDispatcher.get_parent(state, :children)
    {pid, children} = children |> Map.pop(child)

    with {:ok, pid} <- pid |> Bunch.error_if_nil({:unknown_child, child}) do
      state = StateDispatcher.update_parent(state, children: children)
      {{:ok, pid}, state}
    end
  end

  @spec update_children(Parent.state_t(), [Child.name_t()], (ChildEntry.t() -> ChildEntry.t())) ::
          {:ok, Parent.state_t()} | {:error, {:unknown_child, Child.name_t()}}
  def update_children(state, children_names, mapper) do
    children = StateDispatcher.get_parent(state, :children)

    result =
      Bunch.Enum.try_reduce(children_names, children, fn name, children ->
        if Map.has_key?(children, name) do
          {:ok, Map.update!(children, name, mapper)}
        else
          {:error, {:unknown_child, name}}
        end
      end)

    with {:ok, children} <- result do
      {:ok, StateDispatcher.update_parent(state, children: children)}
    end
  end

  @spec update_children(Parent.state_t(), (ChildEntry.t() -> ChildEntry.t())) ::
          {:ok, Parent.state_t()}
  def update_children(state, mapper) do
    children =
      state
      |> StateDispatcher.get_parent(:children)
      |> Map.new(fn {name, entry} -> {name, mapper.(entry)} end)

    {:ok, StateDispatcher.update_parent(state, children: children)}
  end

  @spec all?(Parent.state_t(), (ChildEntry.t() -> as_boolean(term))) :: boolean()
  def all?(state, predicate) do
    state
    |> StateDispatcher.get_parent(:children)
    |> Enum.all?(fn {_k, v} -> predicate.(v) end)
  end
end
