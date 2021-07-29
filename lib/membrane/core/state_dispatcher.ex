defmodule Membrane.Core.StateDispatcher do
  @moduledoc false

  @type group_t :: :parent | :child | :any

  @type state_t ::
          Membrane.Core.Bin.State.t()
          | Membrane.Core.Element.State.t()
          | Membrane.Core.Pipeline.State.t()

  @type kind_t ::
          Membrane.Core.Bin.State
          | Membrane.Core.Element.State
          | Membrane.Core.Pipeline.State

  @type component_t :: Bin | State | Element

  require Record

  defmacro __using__(opts) do
    requires =
      opts
      |> Keyword.get(:restrict, :any)
      |> restrict()
      |> Enum.map(fn component ->
        quote do
          require unquote(kind_of(component))
        end
      end)

    quote do
      (unquote_splicing(requires))
    end
  end

  @spec restrict(group_t() | [component_t()]) :: [component_t()]
  def restrict(group) do
    case group do
      :bin -> [Bin]
      :element -> [Element]
      :pipeline -> [Pipeline]
      :parent -> [Bin, Pipeline]
      :child -> [Bin, Element]
      :any -> [Bin, Element, Pipeline]
    end
  end

  @spec kind_of(state_t() | component_t()) :: kind_t()
  def kind_of(state) when Record.is_record(state), do: elem(state, 0)

  def kind_of(component) when is_atom(component),
    do: Module.concat([Membrane.Core, component, State])

  defguard bin?(state) when Record.is_record(state, Membrane.Core.Bin.State)
  defguard element?(state) when Record.is_record(state, Membrane.Core.Element.State)
  defguard pipeline?(state) when Record.is_record(state, Membrane.Core.Pipeline.State)

  # TODO: automagically generate getters/setters

  defmacro get(state, key), do: group_op(:any, [state, key])
  defmacro update(state, kw), do: group_op(:any, [state | kw])

  defmacro get_child(state, key), do: group_op(:child, [state, key])
  defmacro update_child(state, kw), do: group_op(:child, [state | kw])

  defmacro get_parent(state, key), do: group_op(:parent, [state, key])
  defmacro update_parent(state, kw), do: group_op(:parent, [state | kw])

  defmacro get_bin(state, key), do: kind_op([state, key])
  defmacro update_bin(state, kw), do: kind_op([state | kw])

  defmacro get_element(state, key), do: kind_op([state, key])
  defmacro update_element(state, kw), do: kind_op([state | kw])

  defmacro get_pipeline(state, key), do: kind_op([state, key])
  defmacro update_pipeline(state, kw), do: kind_op([state | kw])

  defp group_op(group, [state | _] = args) do
    clauses =
      group
      |> restrict()
      |> Enum.map(&kind_of/1)
      |> Enum.flat_map(fn kind ->
        quote do
          unquote(kind) -> apply(unquote(kind), :state, unquote(args))
        end
      end)

    quote do
      case unquote(__MODULE__).kind_of(unquote(state)) do
        unquote(clauses)
      end
    end
  end

  defp kind_op([state | _] = args) do
    quote do
      apply(unquote(kind_of(state)), :state, unquote(args))
    end
  end
end
