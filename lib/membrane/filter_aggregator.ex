defmodule Membrane.FilterAggregator do
  @moduledoc """
  An element allowing to aggregate many filters within one Elixir process.

  This element supports only filters with one input and one output
  with following restrictions:
  * not using timers
  * (To be fixed) not relying on callback contexts
  * not relying on received messages
  * their pads have to be named `:input` and `:output`
  * The first filter must make demands in buffers
  """
  use Membrane.Filter

  alias __MODULE__.Context
  alias Membrane.Element.CallbackContext

  def_options filters: [
                spec: [{String.t(), module() | struct()}],
                description: "A list of filters applied to incoming stream"
              ]

  def_input_pad :input,
    caps: :any,
    demand_unit: :buffers

  def_output_pad :output,
    caps: :any

  @impl true
  def handle_init(%__MODULE__{filters: filter_specs}) do
    states =
      filter_specs
      |> Enum.map(fn
        {name, %module{} = sub_opts} ->
          struct = struct!(module, sub_opts |> Map.from_struct())
          {:ok, state} = module.handle_init(struct)
          context = Context.build_context!(name, module)
          {name, module, context, state}

        {name, module} ->
          options =
            module
            |> Code.ensure_loaded!()
            |> function_exported?(:__struct__, 1)
            |> case do
              true -> struct!(module, [])
              false -> %{}
            end

          {:ok, state} = module.handle_init(options)
          context = Context.build_context!(name, module)
          {name, module, context, state}
      end)

    {:ok, %{states: states}}
  end

  @impl true
  def handle_stopped_to_prepared(agg_ctx, %{states: states}) do
    contexts = states |> Enum.map(&elem(&1, 2))
    prev_contexts = contexts |> List.insert_at(-1, agg_ctx)
    next_contexts = [agg_ctx | contexts]

    states =
      [prev_contexts, states, next_contexts]
      |> Enum.zip_with(fn [prev_context, {name, module, context, state}, next_context] ->
        context = Context.link_contexts(context, prev_context, next_context)
        {name, module, context, state}
      end)

    {actions, states} = pipe_downstream([:stopped_to_prepared], states)
    actions = List.delete(actions, :stopped_to_prepared)
    {{:ok, actions}, %{states: states}}
  end

  @impl true
  def handle_prepared_to_playing(_ctx, %{states: states}) do
    {actions, states} = pipe_downstream([:prepared_to_playing], states)
    actions = List.delete(actions, :prepared_to_playing)
    {{:ok, actions}, %{states: states}}
  end

  @impl true
  def handle_playing_to_prepared(_ctx, %{states: states}) do
    {actions, states} = pipe_downstream([:playing_to_prepared], states)
    actions = List.delete(actions, :playing_to_prepared)
    {{:ok, actions}, %{states: states}}
  end

  @impl true
  def handle_prepared_to_stopped(_ctx, %{states: states}) do
    {actions, states} = pipe_downstream([:prepared_to_stopped], states)
    actions = List.delete(actions, :prepared_to_stopped)
    {{:ok, actions}, %{states: states}}
  end

  @impl true
  def handle_start_of_stream(:input, _ctx, %{states: states}) do
    {actions, states} = pipe_downstream([start_of_stream: :output], states)
    actions = Keyword.delete(actions, :start_of_stream)

    {{:ok, actions}, %{states: states}}
  end

  @impl true
  def handle_end_of_stream(:input, _ctx, %{states: states}) do
    {actions, states} = pipe_downstream([end_of_stream: :output], states)

    {{:ok, actions}, %{states: states}}
  end

  @impl true
  def handle_caps(:input, caps, _ctx, %{states: states}) do
    {actions, states} = pipe_downstream([caps: {:output, caps}], states)
    {{:ok, actions}, %{states: states}}
  end

  @impl true
  def handle_demand(:output, size, :buffers, _ctx, %{states: states}) do
    {actions, states} = pipe_upstream([demand: {:input, size}], states)
    {{:ok, actions}, %{states: states}}
  end

  @impl true
  def handle_process_list(:input, buffers, _ctx, %{states: states}) do
    {actions, states} = pipe_downstream([buffer: {:output, buffers}], states)

    {{:ok, actions}, %{states: states}}
  end

  defp pipe_upstream(downstream_actions, states) do
    {states, actions} =
      states
      |> Enum.reverse()
      |> Enum.map_reduce(downstream_actions, fn {name, module, context, state}, actions ->
        {actions, next_context, next_state} = perform_actions(actions, module, context, state, [])

        {{name, module, next_context, next_state}, actions}
      end)

    {actions, Enum.reverse(states)}
  end

  defp pipe_downstream(initial_actions, states) do
    {states, actions} =
      states
      |> Enum.map_reduce(initial_actions, fn {name, module, context, state}, actions ->
        {actions, next_context, next_state} = perform_actions(actions, module, context, state, [])

        {{name, module, next_context, next_state}, actions}
      end)

    {actions, states}
  end

  defp perform_actions([], _module, context, state, next_actions_acc) do
    {next_actions_acc |> Enum.reverse() |> List.flatten(), context, state}
  end

  defp perform_actions([{:forward, data} | actions], module, context, state, next_actions_acc) do
    action =
      case data do
        %Membrane.Buffer{} ->
          {:buffer, {:output, data}}

        [%Membrane.Buffer{} | _tail] ->
          {:buffer, {:output, data}}

        :end_of_stream ->
          {:end_of_stream, :output}

        %_struct{} ->
          cond do
            Membrane.Event.event?(data) -> {:event, {:output, data}}
            true -> {:caps, {:output, data}}
          end
      end

    perform_actions([action | actions], module, context, state, next_actions_acc)
  end

  defp perform_actions([action | actions], module, context, state, next_actions_acc) do
    context = Context.before_incoming_action(context, action)
    result = perform_action(action, module, context, state)
    context = Context.after_incoming_action(context, action)

    case result do
      # Perform splitted actions within the same element
      {{:ok, [{:split, _action} | _tail] = next_actions}, next_state} ->
        perform_actions(
          next_actions ++ actions,
          module,
          context,
          next_state,
          next_actions_acc
        )

      {{:ok, next_actions}, next_state} when is_list(next_actions) ->
        next_context = Context.after_out_actions(context, next_actions)

        perform_actions(actions, module, next_context, next_state, [
          next_actions | next_actions_acc
        ])

      {:ok, next_state} ->
        perform_actions(actions, module, context, next_state, next_actions_acc)

      term ->
        raise "Invalid return from callback: #{inspect(term)}"
    end
  end

  defp perform_action({:buffer, {:output, buffer}}, module, context, state) do
    cb_context = struct!(CallbackContext.Process, context)

    if is_list(buffer) do
      module.handle_process_list(:input, buffer, cb_context, state)
    else
      module.handle_process(:input, buffer, cb_context, state)
    end
  end

  defp perform_action({:caps, {:output, caps}}, module, context, state) do
    cb_context =
      context
      |> Map.put(:old_caps, context.pads.input.caps)
      |> then(&struct!(CallbackContext.Caps, &1))

    module.handle_caps(:input, caps, cb_context, state)
  end

  defp perform_action({:event, {:output, event}}, module, context, state) do
    cb_context = struct!(CallbackContext.Caps, context)

    module.handle_event(:input, event, cb_context, state)
  end

  # Pseudo-action that doesn't exist used to trigger handle_start_of_stream
  defp perform_action({:start_of_stream, :output}, module, context, state) do
    cb_context = struct!(CallbackContext.StreamManagement, context)

    {{:ok, actions}, new_state} =
      case module.handle_start_of_stream(:input, cb_context, state) do
        {:ok, state} -> {{:ok, []}, state}
        result -> result
      end

    {{:ok, Keyword.put_new(actions, :start_of_stream, :output)}, new_state}
  end

  defp perform_action({:end_of_stream, :output}, module, context, state) do
    cb_context = struct!(CallbackContext.StreamManagement, context)

    module.handle_end_of_stream(:input, cb_context, state)
  end

  defp perform_action({:demand, {:input, size}}, module, context, state) do
    cb_context =
      context
      |> Map.put(:incoming_demand, size)
      |> then(&struct!(CallbackContext.Demand, &1))

    # If downstream demands on input, we'd receive that on output
    # TODO: how to handle demand size unit
    module.handle_demand(:output, size, :buffers, cb_context, state)
  end

  defp perform_action({:redemand, :output}, _module, _context, state) do
    # Pass the action downstream, it may come back as a handle_demand call in FilterStage
    {{:ok, redemand: :output}, state}
  end

  defp perform_action({:notify, message}, _module, _context, state) do
    # Pass the action downstream
    {{:ok, notify: message}, state}
  end

  # pseudo-action used to manipulate context after performing an action
  defp perform_action({:merge_context, _ctx_data}, _module, _context, state) do
    {:ok, state}
  end

  defp perform_action({:split, {:handle_process, args_lists}}, module, context, state) do
    {{:ok, actions}, {context, state}} =
      args_lists
      |> Bunch.Enum.try_flat_map_reduce({context, state}, fn [:input, buffer],
                                                             {acc_context, acc_state} ->
        acc_context = Context.before_incoming_action(acc_context, {:buffer, {:output, buffer}})
        cb_context = struct!(CallbackContext.Process, acc_context)
        {result, state} = module.handle_process(:input, buffer, cb_context, acc_state)
        acc_context = Context.after_incoming_action(acc_context, {:buffer, {:output, buffer}})

        result =
          case result do
            :ok -> {:ok, []}
            _ -> result
          end

        {result, {acc_context, state}}
      end)

    # instead of redemands from splitted callback calls, put one after all other actions
    actions =
      actions
      |> Enum.split_with(fn
        {:redemand, _pad} -> true
        _other -> false
      end)
      |> case do
        {[], actions} -> actions ++ [merge_context: context]
        {_redemands, actions} -> actions ++ [merge_context: context, redemand: :output]
      end

    {{:ok, actions}, state}
  end

  # Playback state change actions. They use pseudo-action to invoke proper callback in following element
  defp perform_action(action, module, context, state)
       when action in [
              :stopped_to_prepared,
              :prepared_to_playing,
              :playing_to_prepared,
              :prepared_to_stopped
            ] do
    perform_playback_change(action, module, context, state)
  end

  defp perform_action({:latency, _latency}, _module, _context, _state) do
    raise "latency action not supported in #{inspect(__MODULE__)}"
  end

  defp perform_playback_change(pseudo_action, module, context, state) do
    callback =
      case pseudo_action do
        :stopped_to_prepared -> :handle_stopped_to_prepared
        :prepared_to_playing -> :handle_prepared_to_playing
        :playing_to_prepared -> :handle_playing_to_prepared
        :prepared_to_stopped -> :handle_prepared_to_stopped
      end

    cb_context = struct!(CallbackContext.PlaybackChange, context)

    {{:ok, actions}, new_state} =
      case apply(module, callback, [cb_context, state]) do
        {:ok, state} -> {{:ok, []}, state}
        result -> result
      end

    {{:ok, actions ++ [pseudo_action]}, new_state}
  end
end
