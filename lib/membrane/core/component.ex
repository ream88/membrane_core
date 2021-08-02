defmodule Membrane.Core.Component do
  @moduledoc false
  require Membrane.Core.{Bin.State, Element.State, Pipeline.State, StateDispatcher}

  @type state_t ::
          Membrane.Core.Pipeline.State.t()
          | Membrane.Core.Bin.State.t()
          | Membrane.Core.Element.State.t()

  @spec action_handler(state_t) :: module
  [Pipeline, Bin, Element]
  |> Enum.map(fn component ->
    def action_handler(unquote(Module.concat([Membrane.Core, component, State])).state()),
      do: unquote(Module.concat([Membrane.Core, component, ActionHandler]))
  end)

  defmacro callback_context_generator(restrict, module, state, args \\ []) do
    module = Macro.expand(module, __ENV__)

    restrict =
      case restrict do
        :parent -> [Pipeline, Bin]
        :child -> [Bin, Element]
        :any -> [Pipeline, Bin, Element]
        restrict -> restrict
      end

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
          unquote(Membrane.Core.StateDispatcher.kind_of(component)) ->
            &unquote(context(component, module)).from_state(&1, unquote(args))
        end
      end)

    quote do
      unquote_splicing(requires)

      case Membrane.Core.StateDispatcher.kind_of(unquote(state)) do
        unquote(clauses)
      end
    end
  end

  defp context(component, module),
    do: Module.concat([Membrane, component, CallbackContext, module])
end
