defmodule Membrane.Core.Component do
  @moduledoc false
  require Membrane.Core.{Bin.State, Element.State, Pipeline.State, StateDispatcher}

  alias Membrane.Core.StateDispatcher

  @type state_t ::
          Membrane.Core.Pipeline.State.t()
          | Membrane.Core.Bin.State.t()
          | Membrane.Core.Element.State.t()

  @spec action_handler(state_t) :: module
  [:pipeline, :bin, :element]
  |> Enum.map(fn component ->
    def action_handler(unquote(StateDispatcher.module_of(component)).state()),
      do: handler(unquote(component))
  end)

  defmacro callback_context_generator(restrict, module, state, args \\ []) do
    module = Macro.expand(module, __ENV__)

    restrict = StateDispatcher.restrict(restrict)

    requires =
      restrict
      |> Enum.map(fn component ->
        quote do
          require unquote(context(component, module))
        end
      end)

    clauses =
      restrict
      |> Enum.flat_map(fn component ->
        quote do
          unquote(StateDispatcher.module_of(component)) ->
            &unquote(context(component, module)).from_state(&1, unquote(args))
        end
      end)

    quote do
      unquote_splicing(requires)

      case Membrane.Core.StateDispatcher.module_of(unquote(state)) do
        unquote(clauses)
      end
    end
  end

  defp handler(component),
    do:
      Module.concat([
        Membrane.Core,
        component |> Atom.to_string() |> String.capitalize(),
        ActionHandler
      ])

  defp context(component, module),
    do:
      Module.concat([
        Membrane,
        component |> Atom.to_string() |> String.capitalize(),
        CallbackContext,
        module
      ])
end
