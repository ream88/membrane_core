defmodule Membrane.Element.Base do
  @moduledoc """
  Module defining behaviour common to all elements.

  When used declares behaviour implementation, provides default callback definitions
  and imports macros.

  # Elements

  Elements are units that produce, process or consume data. They can be linked
  with `Membrane.Pipeline`, and thus form a pipeline able to perform complex data
  processing. Each element defines a set of pads, through which it can be linked
  with other elements. During playback, pads can either send (output pads) or
  receive (input pads) data. For more information on pads, see
  `Membrane.Element.Pad`.

  To implement an element, one of base modules (`Membrane.Source`,
  `Membrane.Filter`, `Membrane.Sink`)
  has to be `use`d, depending on the element type:
  - source, producing buffers (contain only output pads),
  - filter, processing buffers (contain both input and output pads),
  - sink, consuming buffers (contain only input pads).
  For more information on each element type, check documentation for appropriate
  base module.

  ## Behaviours
  Element-specific behaviours are specified in modules:
  - `Membrane.Element.Base` - this module, behaviour common to all
  elements,
  - `Membrane.WithOutputPads` - behaviour common to sources
  and filters,
  - `Membrane.WithInputPads` - behaviour common to sinks and
  filters,
  - Base modules (`Membrane.Source`, `Membrane.Filter`,
  `Membrane.Sink`) - behaviours specific to each element type.

  ## Callbacks
  Modules listed above provide specifications of callbacks that define elements
  lifecycle. All of these callbacks have names with the `handle_` prefix.
  They are used to define reaction to certain events that happen during runtime,
  and indicate what actions framework should undertake as a result, besides
  executing element-specific code.

  For actions that can be returned by each callback, see `Membrane.Element.Action`
  module.
  """

  use Bunch

  alias Membrane.Core.{PadsSpecs, OptionsSpecs}
  alias Membrane.{Element, Event}
  alias Membrane.Element.{Action, CallbackContext, Pad}

  @typedoc """
  Type that defines all valid return values from most callbacks.

  In case of error, a callback is supposed to return `{:error, any}` if it is not
  passed state, and `{{:error, any}, state}` otherwise.
  """
  @type callback_return_t ::
          {:ok | {:ok, [Action.t()]} | {:error, any}, Element.state_t()} | {:error, any}

  @doc """
  Automatically implemented callback returning specification of pads exported
  by the element.

  Generated by `Membrane.WithInputPads.def_input_pad/2`
  and `Membrane..WithOutputPads.def_output_pad/2` macros.
  """
  @callback membrane_pads() :: [{Pad.name_t(), Pad.description_t()}]

  @doc """
  Automatically implemented callback used to determine if module is a membrane element.
  """
  @callback membrane_element? :: true

  @doc """
  Automatically implemented callback used to determine whether element exports clock.
  """
  @callback membrane_clock? :: true

  @doc """
  Automatically implemented callback determining whether element is a source,
  a filter or a sink.
  """
  @callback membrane_element_type :: Element.type_t()

  @doc """
  Callback invoked on initialization of element process. It should parse options
  and initialize element internal state. Internally it is invoked inside
  `c:GenServer.init/1` callback.
  """
  @callback handle_init(options :: Element.options_t()) ::
              {:ok, Element.state_t()}
              | {:error, any}

  @doc """
  Callback invoked when element goes to `:prepared` state from state `:stopped` and should get
  ready to enter `:playing` state.

  Usually most resources used by the element are allocated here.
  For example, if element opens a file, this is the place to try to actually open it
  and return error if that has failed. Such resources should be released in `c:handle_prepared_to_stopped/2`.
  """
  @callback handle_stopped_to_prepared(
              context :: CallbackContext.PlaybackChange.t(),
              state :: Element.state_t()
            ) :: callback_return_t

  @doc """
  Callback invoked when element goes to `:prepared` state from state `:playing` and should get
  ready to enter `:stopped` state.

  All resources allocated in `c:handle_prepared_to_playing/2` callback should be released here, and no more buffers or
  demands should be sent.
  """
  @callback handle_playing_to_prepared(
              context :: CallbackContext.PlaybackChange.t(),
              state :: Element.state_t()
            ) :: callback_return_t

  @doc """
  Callback invoked when element is supposed to start playing (goes from state `:prepared` to `:playing`).

  This is moment when initial demands are sent and first buffers are generated
  if there are any pads in the push mode.
  """
  @callback handle_prepared_to_playing(
              context :: CallbackContext.PlaybackChange.t(),
              state :: Element.state_t()
            ) :: callback_return_t

  @doc """
  Callback invoked when element is supposed to stop (goes from state `:prepared` to `:stopped`).

  Usually this is the place for releasing all remaining resources
  used by the element. For example, if element opens a file in `c:handle_stopped_to_prepared/2`,
  this is the place to close it.
  """
  @callback handle_prepared_to_stopped(
              context :: CallbackContext.PlaybackChange.t(),
              state :: Element.state_t()
            ) :: callback_return_t

  @doc """
  Callback invoked when element receives a message that is not recognized
  as an internal membrane message.

  Useful for receiving ticks from timer, data sent from NIFs or other stuff.
  """
  @callback handle_other(
              message :: any(),
              context :: CallbackContext.Other.t(),
              state :: Element.state_t()
            ) :: callback_return_t

  @doc """
  Callback that is called when new pad has beed added to element. Executed
  ONLY for dynamic pads.
  """
  @callback handle_pad_added(
              pad :: Pad.ref_t(),
              context :: CallbackContext.PadAdded.t(),
              state :: Element.state_t()
            ) :: callback_return_t

  @doc """
  Callback that is called when some pad of the element has beed removed. Executed
  ONLY for dynamic pads.
  """
  @callback handle_pad_removed(
              pad :: Pad.ref_t(),
              context :: CallbackContext.PadRemoved.t(),
              state :: Element.state_t()
            ) :: callback_return_t

  @doc """
  Callback that is called when event arrives.

  Events may arrive from both sinks and sources. In filters by default event is
  forwarded to all sources or sinks, respectively. If event is either
  `Membrane.Event.StartOfStream` or `Membrane.Event.EndOfStream`, notification
  is sent, to notify the pipeline that data processing is started or finished.
  This behaviour can be overriden, e.g. by sending end of stream notification
  after elements internal buffers become empty.
  """
  @callback handle_event(
              pad :: Pad.ref_t(),
              event :: Event.t(),
              context :: CallbackContext.Event.t(),
              state :: Element.state_t()
            ) :: callback_return_t

  @doc """
  Callback invoked upon each timer tick. A timer can be started with `Action.timer_t`
  action.
  """
  @callback handle_tick(
              timer_id :: any,
              context :: CallbackContext.Tick.t(),
              state :: Element.state_t()
            ) :: callback_return_t

  @doc """
  Callback invoked when element is shutting down just before process is exiting.
  Internally called in `c:GenServer.terminate/2` callback.
  """
  @callback handle_shutdown(reason, state :: Element.state_t()) :: :ok
            when reason: :normal | :shutdown | {:shutdown, any}

  @optional_callbacks membrane_clock?: 0,
                      handle_init: 1,
                      handle_stopped_to_prepared: 2,
                      handle_prepared_to_playing: 2,
                      handle_playing_to_prepared: 2,
                      handle_prepared_to_stopped: 2,
                      handle_other: 3,
                      handle_pad_added: 3,
                      handle_pad_removed: 3,
                      handle_event: 4,
                      handle_tick: 3,
                      handle_shutdown: 2

  @docs_order [
    :moduledoc,
    :membrane_options_moduledoc,
    :membrane_pads_moduledoc,
    :membrane_clock_moduledoc
  ]

  @doc """
  Macro defining options that parametrize element.

  It automatically generates appropriate struct and documentation.

  #{OptionsSpecs.options_doc()}
  """
  defmacro def_options(options) do
    OptionsSpecs.def_options(__CALLER__.module, options)
  end

  @doc """
  Defines that element exports a clock to pipeline.

  Exporting clock allows pipeline to choose it as the pipeline clock, enabling other
  elements to synchronize with it. Element's clock is accessible via `clock` field,
  while pipeline's one - via `parent_clock` field in callback contexts. Both of
  them can be used for starting timers.
  """
  defmacro def_clock(doc \\ "") do
    quote do
      @membrane_element_has_clock true

      Module.put_attribute(__MODULE__, :membrane_clock_moduledoc, """
      ## Clock

      This element provides a clock to its pipeline.

      #{unquote(doc)}
      """)

      @impl true
      def membrane_clock?, do: true
    end
  end

  defmacro generate_moduledoc(env) do
    membrane_pads_moduledoc =
      Module.get_attribute(env.module, :membrane_pads)
      |> PadsSpecs.generate_docs_from_pads_specs()

    Module.put_attribute(env.module, :membrane_pads_moduledoc, membrane_pads_moduledoc)

    quote do
      if @moduledoc != false do
        @moduledoc unquote(
                     @docs_order
                     |> Enum.map(&Module.get_attribute(__CALLER__.module, &1))
                     |> Enum.map(fn
                       # built-in @moduledoc writes docs in the form of {integer(), string}
                       {_, text} -> text
                       e -> e
                     end)
                     |> Enum.filter(& &1)
                     |> Enum.reduce(fn x, acc ->
                       quote do
                         unquote(acc) <> unquote(x)
                       end
                     end)
                   )
      end
    end
  end

  defmacro __using__(_) do
    quote location: :keep do
      @behaviour unquote(__MODULE__)

      @before_compile {unquote(__MODULE__), :generate_moduledoc}

      use Membrane.Log, tags: :element, import: false

      alias Membrane.Element.CallbackContext, as: Ctx

      import unquote(__MODULE__), only: [def_clock: 0, def_clock: 1, def_options: 1]

      @impl true
      def membrane_element?, do: true

      @impl true
      def handle_init(%opt_struct{} = options), do: {:ok, options |> Map.from_struct()}
      def handle_init(options), do: {:ok, options}

      @impl true
      def handle_stopped_to_prepared(_context, state), do: {:ok, state}

      @impl true
      def handle_prepared_to_playing(_context, state), do: {:ok, state}

      @impl true
      def handle_playing_to_prepared(_context, state), do: {:ok, state}

      @impl true
      def handle_prepared_to_stopped(_context, state), do: {:ok, state}

      @impl true
      def handle_other(_message, _context, state), do: {:ok, state}

      @impl true
      def handle_pad_added(_pad, _context, state), do: {:ok, state}

      @impl true
      def handle_pad_removed(_pad, _context, state), do: {:ok, state}

      @impl true
      def handle_event(_pad, _event, _context, state), do: {:ok, state}

      @impl true
      def handle_shutdown(_reason, _state), do: :ok

      defoverridable handle_init: 1,
                     handle_stopped_to_prepared: 2,
                     handle_playing_to_prepared: 2,
                     handle_prepared_to_playing: 2,
                     handle_prepared_to_stopped: 2,
                     handle_other: 3,
                     handle_pad_added: 3,
                     handle_pad_removed: 3,
                     handle_event: 4,
                     handle_shutdown: 2
    end
  end
end
