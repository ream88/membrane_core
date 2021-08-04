defmodule Membrane.Core.TimerController do
  @moduledoc false
  use Bunch

  alias Membrane.Clock
  alias Membrane.Core.{CallbackHandler, Component, StateDispatcher, Timer}

  require Membrane.Core.Component
  require Membrane.Element.CallbackContext.Tick
  use StateDispatcher

  @spec start_timer(Timer.id_t(), Timer.interval_t(), Clock.t(), Component.state_t()) ::
          {:ok, Component.state_t()}
          | {{:error, {:timer_already_exists, id: Timer.id_t()}}, Component.state_t()}
  def start_timer(id, interval, clock, state) do
    synchronization = get_sync(state)

    if synchronization.timers |> Map.has_key?(id) do
      {{:error, {:timer_already_exists, id: id}}, state}
    else
      clock |> Clock.subscribe()
      timer = Timer.start(id, interval, clock)
      new_sync = put_in(synchronization, [:timers, id], timer)

      StateDispatcher.update_any(state, synchronization: new_sync)
      ~> {:ok, &1}
    end
  end

  @spec timer_interval(Timer.id_t(), Timer.interval_t(), Component.state_t()) ::
          {:ok, Component.state_t()}
          | {{:error, {:unknown_timer, id: Timer.id_t()}}, Component.state_t()}
  def timer_interval(id, interval, state) do
    synchronization = get_sync(state)

    with {:ok, timer} <- synchronization.timers |> Map.fetch(id) do
      timer = Timer.set_interval(timer, interval)
      new_sync = put_in(synchronization, [:timers, id], timer)

      StateDispatcher.update_any(state, synchronization: new_sync)
      ~> {:ok, &1}
    else
      :error -> {{:error, {:unknown_timer, id}}, state}
    end
  end

  @spec stop_timer(Timer.id_t(), Component.state_t()) ::
          {:ok, Component.state_t()}
          | {{:error, {:unknown_timer, id: Timer.id_t()}}, Component.state_t()}
  def stop_timer(id, state) do
    {timer, new_sync} = pop_in(get_sync(state), [:timers, id])
    state = StateDispatcher.update_any(state, synchronization: new_sync)

    if timer |> is_nil do
      {{:error, {:unknown_timer, id}}, state}
    else
      :ok = timer |> Timer.stop()
      timer.clock |> Clock.unsubscribe()
      {:ok, state}
    end
  end

  @spec handle_tick(Timer.id_t(), Component.state_t()) ::
          {:ok, Component.state_t()} | {{:error, any}, Component.state_t()}
  def handle_tick(timer_id, state) do
    context = Component.callback_context_generator(:any, Tick, state)
    synchronization = get_sync(state)

    # the first clause checks if the timer wasn't removed before receiving this tick
    withl present?: true <- Map.has_key?(synchronization.timers, timer_id),
          callback:
            {:ok, state} <-
              CallbackHandler.exec_and_handle_callback(
                :handle_tick,
                Component.action_handler(state),
                %{context: context},
                [timer_id],
                state
              ),
          # in case the timer was removed in handle_tick
          present?: true <- Map.has_key?(synchronization.timers, timer_id) do
      new_sync = update_in(synchronization, [:timers, timer_id], &Timer.tick/1)

      StateDispatcher.update_any(state, synchronization: new_sync)
      ~> {:ok, &1}
    else
      present?: false -> {:ok, state}
      callback: {{:error, _reason}, _state} = err -> err
    end
  end

  @spec handle_clock_update(Timer.id_t(), Clock.ratio_t(), Component.state_t()) ::
          {:ok, Component.state_t()}
  def handle_clock_update(clock, ratio, state) do
    new_sync =
      Map.update!(
        get_sync(state),
        :timers,
        &Bunch.Map.map_values(&1, fn
          %Timer{clock: ^clock} = timer -> timer |> Timer.update_ratio(ratio)
          timer -> timer
        end)
      )

    StateDispatcher.update_any(state, synchronization: new_sync)
    ~> {:ok, &1}
  end

  defp get_sync(state), do: StateDispatcher.get_any(state, :synchronization)
end
