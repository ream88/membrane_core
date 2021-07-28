defmodule Membrane.Core.StateDispatcher do
  @type state_t :: Bin.State.t() | Element.State.t() | Pipeline.State.t()

  @groups [
    all: [:bin, :element, :pipeline],
    parent: [:bin, :pipeline],
    child: [:bin, :element]
  ]

  defmacro __using__([]) do
    required_modules =
      @groups
      |> Keyword.get(:all)
      |> Enum.map(fn kind ->
        quote do
          require unquote(kind_to_module(kind))
        end
      end)

    quote do
      require unquote(__MODULE__)
      unquote_splicing(required_modules)
    end
  end

  @spec kind_of(state_t()) :: :bin | :element | :pipeline
  def kind_of(state), do: elem(state, 0)

  defguard bin?(state) when elem(state, 0) == :bin
  defguard element?(state) when elem(state, 0) == :element
  defguard pipeline?(state) when elem(state, 0) == :pipeline

  defmacro get(state, key), do: group_op(:all, :get, [state, key])
  defmacro update(state, kw), do: group_op(:all, :update, [state | kw])

  defmacro get_child(state, key), do: group_op(:child, :get, [state, key])
  defmacro update_child(state, kw), do: group_op(:child, :update, [state | kw])

  defmacro get_parent(state, key), do: group_op(:parent, :get, [state, key])
  defmacro update_parent(state, kw), do: group_op(:parent, :update, [state | kw])

  defmacro get_bin(state, key), do: kind_op([state, key])
  defmacro update_bin(state, kw), do: kind_op([state | kw])

  defmacro get_element(state, key), do: kind_op([state, key])
  defmacro update_element(state, kw), do: kind_op([state | kw])

  defmacro get_pipeline(state, key), do: kind_op([state, key])
  defmacro update_pipeline(state, kw), do: kind_op([state | kw])

  defp group_op(group_spec, action, [state | _] = args) do
    clauses =
      @groups[group_spec]
      |> Enum.flat_map(fn component ->
        action_component = merge_atoms([action, component], "_")

        quote do
          unquote(component) ->
            apply(unquote(__MODULE__), unquote(action_component), unquote(args))
        end
      end)

    quote do
      case unquote(__MODULE__).kind_of(unquote(state)) do
        unquote(clauses)
      end
    end
  end

  defp kind_op([state | _] = args) do
    kind = kind_of(state)
    module = kind_to_module(kind)

    quote do
      apply(unquote(module), unquote(kind), unquote(args))
    end
  end

  defp kind_to_module(kind) do
    kind
    |> Atom.to_string()
    |> String.capitalize()
    |> String.to_atom()
    |> then(&Module.concat([Membrane, Core, &1, State]))
  end

  defp merge_atoms(atoms, sep) do
    atoms
    |> List.update_at(0, &Atom.to_string/1)
    |> Enum.reduce(fn atom, acc -> acc <> sep <> Atom.to_string(atom) end)
    |> String.to_atom()
  end
end
