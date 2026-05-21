defmodule Spex.Specification do
  @moduledoc """
  Behaviour and DSL for defining specifications through labelled transition systems (LTSs).

  ## Configuration Options

  Pass options to `use Spex.Specification, ...`.

  ### `:transition_timeout`

  Maximum time between two observed transitions for an instance.

  - Default: `:infinity`
  - Accepted values: `:infinity`, integer milliseconds, or `%Duration{}` (anything accepted by
    `Kernel.to_timeout/1`)
  - Used by instance manager timeout checks.

  If an instance exceeds this timeout, Spex emits
  `%Spex.Errors.TransitionError{reason: :transition_timeout}` and routes it through the
  specification `error_handler/2`.

  ### `:prune_timeout`

  Minimum idle time before an instance can be considered for pruning.

  - Default: `:infinity`
  - Accepted values: `:infinity`, integer milliseconds, or `%Duration{}` (anything accepted by
    `Kernel.to_timeout/1`)

  Pruning eligibility also depends on `:prunable_states`.

  ### `:prunable_states`

  Controls which states are allowed to be pruned after `:prune_timeout`.

  - Default: `[]` (no states are prunable)
  - Accepted values:
    - `:all`: any current state may be pruned
    - `:terminal`: only terminal states (those without outgoing transitions) may be pruned
    - explicit state list, e.g. `[:done, :failed]`; note that these are the states of your
      implementation model, i.e. those used in `Spex.init_instance/4` and `Spex.transition/3`, which
      may differ from the states of the specification

  ## Transition DSL

  Define transitions with `def_transition from_state, action, to_state`.

  Each call contributes to compile-time metadata used to generate:

  - `states/0`
  - `actions/0`
  - `transitions/0`
  - `initial_state/0`
  - `terminal_states/0`

  Duplicate states/actions/transitions are deduplicated.

  The initial state is the source state of the first declared transition.

  ## Generated Callbacks

  When you `use Spex.Specification`, the following callbacks are generated
  automatically:

  - `transition_timeout/0`
  - `prune_timeout/0`
  - `prunable_states/0`
  - `states/0`
  - `actions/0`
  - `transitions/0`
  - `initial_state/0`
  - `terminal_states/0`
  - `error_handler/2` (delegates to `default_error_handler/2` by default)

  `error_handler/2` is overridable.

  ## Error Handling Contract

  `error_handler/2` receives `(error, caller_pid)` and must return:

  - `:ok` to swallow/accept the error condition, or
  - `{:error, reason}` to propagate failure.

  Default behaviour in `default_error_handler/2`:

  - logs the error and caller stacktrace,
  - returns `:ok` for:
    - `%Spex.Errors.TransitionError{reason: :deviation_still_equivalent}`
    - `%Spex.Errors.ImplModelError{reason: :impl_model_not_found}`
  - returns `{:error, error}` for all other errors.

  ## Full Example

      defmodule MySpec do
        use Spex.Specification,
          transition_timeout: 30_000,
          prune_timeout: %Duration{hour: 1},
          prunable_states: :terminal

        def_transition :idle, :start, :running
        def_transition :running, :complete, :done
        def_transition :running, :fail, :failed

        @impl Spex.Specification
        def error_handler(error, caller) do
          super(error, caller)

          # swallow all errors
          :ok
        end
      end
  """

  require Logger
  @typedoc "A module implementing this behaviour"
  @type t :: module()

  @doc false
  @callback states :: [Spex.state()]
  @doc false
  @callback actions :: [Spex.action()]
  @doc false
  @callback initial_state :: Spex.state()
  @doc false
  @callback terminal_states :: [Spex.state()]
  @doc false
  @callback transitions :: [Spex.transition()]

  @doc false
  @callback transition_timeout :: timeout()
  @doc false
  @callback prune_timeout :: timeout()
  @doc false
  @callback prunable_states :: [Spex.state()] | :all | :terminal

  @typedoc false
  @type handled_error :: Spex.Errors.InstanceError.t() | Spex.Errors.TransitionError.t()

  @typedoc "The return type for `error_handler/2` callbacks."
  @type error_handler_return :: :ok | {:error, Exception.t() | term()}

  @doc """
  Callback for handling errors emitted by Spex during instance management.
  """
  @callback error_handler(handled_error, caller_process :: pid()) :: error_handler_return()

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      # Extract configuration options with defaults
      transition_timeout = Keyword.get(opts, :transition_timeout, :infinity) |> to_timeout()
      prune_timeout = Keyword.get(opts, :prune_timeout, :infinity) |> to_timeout()
      prunable_states = Keyword.get(opts, :prunable_states, [])

      @behaviour Spex.Specification

      # Module attributes to collect data during compilation
      Module.register_attribute(__MODULE__, :spex_transitions, accumulate: true)
      Module.register_attribute(__MODULE__, :spex_states, accumulate: true)
      Module.register_attribute(__MODULE__, :spex_actions, accumulate: true)

      import Spex.Specification, only: [def_transition: 3]

      @before_compile Spex.Specification

      # Configure callbacks based on options

      @impl Spex.Specification
      def transition_timeout, do: unquote(transition_timeout)

      @impl Spex.Specification
      def prune_timeout, do: unquote(prune_timeout)

      @impl Spex.Specification
      def prunable_states, do: unquote(prunable_states)

      # Default error handler (overridable)
      defdelegate error_handler(error, caller), to: Spex.Specification, as: :default_error_handler

      defoverridable error_handler: 2
    end
  end

  @doc """
  Defines a transition from one state to another via an action.

  The first state of the first transition becomes the initial state.
  States and actions are automatically collected and deduplicated.

  ## Example

      def_transition :idle, :start, :working
      def_transition :working, :complete, :idle
  """
  defmacro def_transition(from_state, action, to_state) do
    quote do
      # Add the transition
      @spex_transitions {unquote(from_state), unquote(action), unquote(to_state)}

      # Add states (will be deduplicated later)
      @spex_states unquote(from_state)
      @spex_states unquote(to_state)

      # Add action
      @spex_actions unquote(action)
    end
  end

  @doc false
  defmacro __before_compile__(_env) do
    quote unquote: false do
      # Compute data at compile time

      spex_states_uniq = @spex_states |> Enum.reverse() |> Enum.uniq()
      spex_actions_uniq = @spex_actions |> Enum.reverse() |> Enum.uniq()
      spex_transitions_uniq = @spex_transitions |> Enum.reverse() |> Enum.uniq()

      spex_initial_state =
        case spex_transitions_uniq do
          [{initial_state, _, _} | _] -> initial_state
          [] -> nil
        end

      spex_terminal_states =
        Enum.reject(spex_states_uniq, fn state ->
          Enum.any?(spex_transitions_uniq, &match?({^state, _, _}, &1))
        end)

      # Configure callbacks to return the computed data

      @impl Spex.Specification
      def states, do: unquote(Macro.escape(spex_states_uniq))

      @impl Spex.Specification
      def actions, do: unquote(Macro.escape(spex_actions_uniq))

      @impl Spex.Specification
      def transitions, do: unquote(Macro.escape(spex_transitions_uniq))

      @impl Spex.Specification
      def initial_state, do: unquote(Macro.escape(spex_initial_state))

      @impl Spex.Specification
      def terminal_states, do: unquote(Macro.escape(spex_terminal_states))
    end
  end

  @doc """
  Default error handling strategy used by specification modules.
  """
  @spec default_error_handler(handled_error(), caller_process :: pid()) :: error_handler_return()
  def default_error_handler(error, caller) do
    caller_stacktrace = Process.info(caller, :current_stacktrace)

    Logger.error("[Spex] Error: #{inspect(error)};\n stacktrace: #{inspect(caller_stacktrace)}")

    case error do
      %Spex.Errors.TransitionError{reason: :deviation_still_equivalent} -> :ok
      %Spex.Errors.ImplModelError{reason: :impl_model_not_found} -> :ok
      _other_error -> {:error, error}
    end
  end
end
