defmodule Membrane.Core.Pipeline do
  @moduledoc false
  use GenServer
  use Membrane.Core.StateDispatcher

  alias __MODULE__.ActionHandler
  alias Membrane.Clock
  alias Membrane.Core.{CallbackHandler, StateDispatcher}
  alias Membrane.Core.Parent.MessageDispatcher
  alias Membrane.Core.Pipeline.State

  require Membrane.Logger

  @impl GenServer
  def init({module, pipeline_options}) do
    pipeline_name = "pipeline@#{:erlang.pid_to_list(self())}"
    :ok = Membrane.ComponentPath.set([pipeline_name])
    :ok = Membrane.Logger.set_prefix(pipeline_name)
    {:ok, clock} = Clock.start_link(proxy: true)

    state =
      StateDispatcher.pipeline(
        module: module,
        synchronization: %{
          clock_proxy: clock,
          clock_provider: %{clock: nil, provider: nil, choice: :auto},
          timers: %{}
        }
      )

    with {:ok, state} <-
           CallbackHandler.exec_and_handle_callback(
             :handle_init,
             ActionHandler,
             %{state: false},
             [pipeline_options],
             state
           ) do
      {:ok, state}
    end
  end

  @impl GenServer
  def handle_info(message, state) do
    MessageDispatcher.handle_message(message, state)
  end

  @impl GenServer
  def terminate(reason, state) do
    State.state(module: module, internal_state: internal_state) = state

    :ok = module.handle_shutdown(reason, internal_state)
  end
end
