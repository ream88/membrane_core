defmodule Membrane.Core.Parent.ClockHandler do
  @moduledoc false

  alias Membrane.{Clock, Core, ParentError}

  @spec choose_clock(Membrane.Child.name() | Membrane.Parent, Core.Parent.state()) ::
          Core.Parent.state() | no_return
  def choose_clock(provider, state) do
    %{synchronization: synchronization} = state

    components =
      case state do
        %Core.Bin.State{} -> %{Membrane.Parent => %{clock: synchronization.parent_clock}}
        %Core.Pipeline.State{} -> %{}
      end

    components = Map.merge(state.children, components)
    clock = get_clock_from_provider(components, provider)
    set_clock_provider(clock, state)
  end

  @spec reset_clock(Core.Parent.state()) :: Core.Parent.state()
  def reset_clock(state),
    do: set_clock_provider(%{clock: nil, provider: nil}, state)

  defp set_clock_provider(clock_provider, state) do
    Clock.proxy_for(state.synchronization.clock_proxy, clock_provider.clock)
    put_in(state, [:synchronization, :clock_provider], clock_provider)
  end

  defp get_clock_from_provider(components, provider) do
    case Map.get(components, provider) do
      nil ->
        raise ParentError, "Unknown clock provider: #{inspect(provider)}"

      %{clock: nil} ->
        raise ParentError, "#{inspect(provider)} is not a clock provider"

      %{clock: clock} ->
        %{clock: clock, provider: provider}
    end
  end
end
