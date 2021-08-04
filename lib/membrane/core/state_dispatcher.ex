defmodule Membrane.Core.StateDispatcher do
  @moduledoc false

  @type group_t :: :parent | :child | :any

  @type component_t :: :bin | :element | :pipeline

  @type module_t ::
          Membrane.Core.Bin.State
          | Membrane.Core.Element.State
          | Membrane.Core.Pipeline.State

  @type state_t ::
          Membrane.Core.Bin.State.t()
          | Membrane.Core.Element.State.t()
          | Membrane.Core.Pipeline.State.t()

  @components [:bin, :element, :pipeline]
  @groups [:parent, :child, :any]

  @membership %{
    parent: [:bin, :pipeline],
    child: [:bin, :element],
    any: @components
  }

  require Record

  defmacro __using__(_) do
    requires =
      @components
      |> Enum.map(fn component ->
        quote do
          require unquote(module_of(component))
        end
      end)

    quote do
      (unquote_splicing(requires))
    end
  end

  @spec restrict(group_t() | component_t()) :: [component_t()]
  def restrict(spec) when spec in @groups, do: @membership[spec]
  def restrict(spec) when spec in @components, do: [spec]

  @spec module_of(state_t() | component_t()) :: module_t()
  def module_of(state) when Record.is_record(state), do: elem(state, 0)

  def module_of(component) when is_atom(component),
    do:
      Module.concat([
        Membrane.Core,
        component |> Atom.to_string() |> String.capitalize() |> String.to_atom(),
        State
      ])

  defguard bin?(state) when Record.is_record(state, Membrane.Core.Bin.State)
  defguard element?(state) when Record.is_record(state, Membrane.Core.Element.State)
  defguard pipeline?(state) when Record.is_record(state, Membrane.Core.Pipeline.State)

  # FIXME: inconsistent State initialisation
  defmacro element(kw) do
    module = module_of(:element)

    quote do
      if is_map(unquote(kw)) do
        unquote(module).new(unquote(kw))
      else
        unquote(module).state(unquote(kw))
      end
    end
  end

  defmacro element(state, kw) do
    module = module_of(:element)

    quote do
      unquote(module).state(unquote(state), unquote(kw))
    end
  end

  (@components -- [:element])
  |> Enum.map(fn component ->
    defmacro unquote(component)(kw) do
      module = module_of(unquote(component))

      quote do
        unquote(module).state(unquote(kw))
      end
    end

    defmacro unquote(component)(state, kw) do
      module = module_of(unquote(component))

      quote do
        unquote(module).state(unquote(state), unquote(kw))
      end
    end
  end)

  (@components ++ @groups)
  |> Enum.map(fn spec ->
    defmacro unquote(:"get_#{spec}")(state, args), do: spec_op(unquote(spec), state, args)
    defmacro unquote(:"update_#{spec}")(state, args), do: spec_op(unquote(spec), state, args)
  end)

  defp spec_op(component, state, args) when component in @components do
    module = module_of(component)

    quote do
      unquote(module).state(unquote(state), unquote(args))
    end
  end

  defp spec_op(group, state, args) when group in @groups do
    clauses =
      group
      |> restrict()
      |> Enum.flat_map(fn component ->
        module = module_of(component)

        quote do
          unquote(module) -> unquote(module).state(unquote(state), unquote(args))
        end
      end)

    quote do
      case unquote(__MODULE__).module_of(unquote(state)) do
        unquote(clauses)
      end
    end
  end
end
