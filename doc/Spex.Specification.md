# `Spex.Specification`
[🔗](https://github.com/maxpohlmann/spex/blob/main/lib/spex/specification.ex#L1)

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

# `error_handler_return`

```elixir
@type error_handler_return() :: :ok | {:error, Exception.t() | term()}
```

The return type for `error_handler/2` callbacks.

# `t`

```elixir
@type t() :: module()
```

A module implementing this behaviour

# `error_handler`

```elixir
@callback error_handler(handled_error(), caller_process :: pid()) ::
  error_handler_return()
```

Callback for handling errors emitted by Spex during instance management.

# `def_transition`
*macro* 

Defines a transition from one state to another via an action.

The first state of the first transition becomes the initial state.
States and actions are automatically collected and deduplicated.

## Example

    def_transition :idle, :start, :working
    def_transition :working, :complete, :idle

# `default_error_handler`

```elixir
@spec default_error_handler(handled_error(), caller_process :: pid()) ::
  error_handler_return()
```

Default error handling strategy used by specification modules.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
