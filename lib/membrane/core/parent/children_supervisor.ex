defmodule Membrane.Core.Parent.ChildrenSupervisor do
  use GenServer

  require Membrane.Core.Message, as: Message
  require Membrane.Logger

  def start_link() do
    {:ok, pid} = GenServer.start(__MODULE__, self())
    # Not doing start_link here is a nasty hack to avoid `terminate` being called
    # once parent sends an `exit` signal. This way we receive it in `handle_info`
    # and can wait till the children exit without calling `receive`.
    Process.link(pid)
    {:ok, pid}
  end

  def start_child(supervisor, name, start_fun) do
    Message.call!(supervisor, :start_child, [name, start_fun])
  end

  @impl true
  def init(parent_supervisor) do
    Process.flag(:trap_exit, true)
    {:ok, %{parent_supervisor: {:alive, parent_supervisor}, children: %{}}}
  end

  @impl true
  def handle_call(Message.new(:start_child, [name, start_fun]), _from, state) do
    case start_fun.() do
      {:ok, child_pid} ->
        {:reply, {:ok, child_pid}, put_in(state, [:children, child_pid], name)}

      {:ok, supervisor_pid, child_pid} ->
        {:reply, {:ok, child_pid}, put_in(state, [:children, supervisor_pid], name)}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_info(Message.new(:setup_logger, setup_logger), state) do
    setup_logger.()
    {:noreply, state}
  end

  @impl true
  def handle_info(
        {:EXIT, pid, _reason},
        %{parent_supervisor: {:alive, pid}, children: children} = state
      )
      when children == %{} do
    Membrane.Logger.debug("Children supervisor: exiting")
    {:stop, :normal, state}
  end

  @impl true
  def handle_info({:EXIT, pid, reason}, %{parent_supervisor: {:alive, pid}} = state) do
    Membrane.Logger.debug(
      "Children supervisor: got exit request from parent, reason: #{inspect(reason)}, shutting down children"
    )

    state.children |> Map.keys() |> Enum.each(&Process.exit(&1, {:shutdown, :parent_crash}))
    {:noreply, %{state | parent_supervisor: :exit_requested}}
  end

  @impl true
  def handle_info(
        {:EXIT, pid, _reason},
        %{parent_supervisor: :exit_requested} = state
      ) do
    {_name, state} = pop_in(state, [:children, pid])

    if state.children == %{} do
      Membrane.Logger.debug("Children supervisor: exiting")
      {:stop, :normal, state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:EXIT, pid, reason}, state) do
    {name, state} = pop_in(state, [:children, pid])

    case state.parent_supervisor do
      {:alive, pid} -> Message.send(pid, :child_death, [name, reason])
      _other -> :ok
    end

    {:noreply, state}
  end
end
