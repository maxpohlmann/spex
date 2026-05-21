# `Spex`
[🔗](https://github.com/maxpohlmann/spex/blob/main/lib/spex.ex#L1)

Entry point for Spex runtime APIs and high-level integration.

## Install, configure, and start Spex

Add Spex to your dependencies:

    def deps do
    [
      {:spex, "~> 0.1.1", hex: :lts_spex}
    ]
    end

Please note the `hex: :lts_spex`.
The package name `:spex` itself was [already taken](https://hex.pm/packages/spex) (which I
realised only after becoming attached to the name). However, since that package is unmaintained
and not widely used, I decided to keep the namespace simply as `Spex`. The _lts_ prefix stands for
_labelled transition system_ (see the [Theoretical background section of the readme](README.md#theoretical-background)).

Optionally, add `:spex` to your [`.formatter.exs` file under `:import_deps`](https://hexdocs.pm/mix/main/Mix.Tasks.Format.html#module-importing-dependencies-configuration).

### Configuration

The derived implementation models are stored in a custom format in a given folder. Ideally, this
should be within the priv directory of your application (`:code.priv_dir(:your_app)`).

[`:dets`](https://www.erlang.org/doc/apps/stdlib/dets.html) is used to persist information about
instances (like previous transitions). You can configure the directory in which these dets files
are stored.

When you specify a transition timeout in your specification (see `Spex.Specification`), timeouts
are detected and reported. You might or might not want to have these timeouts checked at
application startup for persisted instances. Enabling it might lead to many timeout reports at
startup, disabling it might lead to missed timeouts.

Similarly, you can specify prunable states and prune timeouts to avoid storing instances
indefinitely. You can configure how often this pruning should happen.

Here is a sample configuration with the default values:

    config :spex,
      impl_models_dir: "./spex_impl_models",
      dets_dir: "./spex_dets",
      check_transition_timeouts_on_start?: true,
      prune_interval: %Duration{hour: 6} |> to_timeout()

### Manual Supervision

By default, Spex starts its own application incl. supervision tree and is usable right away. If
you'd rather supervise it yourself, you can also disable the Spex application and add it to your
supervision tree manually:

    def deps do
    [
      {:spex, "~> 0.1.1", hex: :lts_spex, runtime: false}
    ]
    end

    children = [
      ...,
      {Spex, spex_config_opts}
    ]

    Supervisor.start(children, supervisor_opts)

Note that you can pass spex_config_opts to Spex here. These options are the same as the ones
described in the configuration section above.

### Using other instance managers

By default, `Spex` is a convenience front for the `Spex.InstanceManager.SimpleInstanceManager`,
which starts a single GenServer that handles all instances. Should this become a bottleneck, there
is also the `Spex.InstanceManager.DistributedInstanceManager`. To use it, you can configure it as
follows (note that this a compile time config):

    config :spex,
      instance_manager: Spex.InstanceManager.DistributedInstanceManager,
      instance_manager_opts: [distribution_factor: 4] # 4 is the default

Alternatively, you can also add either instance manager to your supervision tree directly, e.g.:

    children = [
      ...,
      # spex_config_opts are the same as the ones described in the configuration section above
      {Spex.InstanceManager.DistributedInstanceManager, [distribution_factor: 4] ++ spex_config_opts}
    ]

    Supervisor.start(children, supervisor_opts)

If you choose to do this, however, do note that `Spex` does no longer work as a convenience front
and you need to make all calls to your chosen instance manager directly (e.g.
`Spex.InstanceManager.DistributedInstanceManager.transition(...)` rather than
`Spex.transition(...)`).

### Define specifications

Specifications represent protocols or workflows and are modelled as graphs / state machines. The
focus lies on the transitions (edges) rather than the states (nodes): when we compare an
implementation model against its specification, their states can be entirely distinct, since
behavioural equivalence is judged entirely based on their transition behaviours (basically: action
sequences).

In the simplest case, you can create a specification as follows:

    defmodule YourApp.Specifications.Tree do
      @moduledoc """
      A specification that forms a small, simple tree structure:

                   s0
                  /  |
                a/    |a
                /      |
              s1       s2
              / |
            b/   |c
            /     |
          s3      s4

      """
      use Spex.Specification

      def_transition :s0, :a, :s1
      def_transition :s0, :a, :s2

      def_transition :s1, :b, :s3
      def_transition :s1, :c, :s4
    end

Each _transition_ consists of a _from_state_, an _action_, and a _to_state_.

Specifications can have custom error handlers, to which any reported errors are passed for
processing, e.g. logging and deciding which errors are okay.

For details on configuring and customising specifications, see `Spex.Specification`.

### Observe transitions in your implementation

In your actual implementation code, you need to initialise instances of your specification and
record transitions.

As a useless toy example, say we manage a pine forest where each pine has a number. We offer a
function for planting a seedling:

    alias YourApp.Specifications.Tree

    def plant_seedling(pine_id) do
      specification = Tree
      instance_identifier = {Tree, pine_id}
      meta = %{planting_datetime: DateTime.utc_now()}
      initial_state = :seedling

      Spex.init_instance(specification, instance_identifier, meta, initial_state)
    end

Note that the instance identifier is an arbitrary term that uniquely identifies the instance
across all specifications (hence it can make sense to include the specification module). The meta
can optionally be added to make possible error reports regarding the instance more useful. The
initial state is also optional and defaults to the specification's initial state.

After an instance is initialised, we can record its transitions with
`Spex.transition(instance_identifier, action, new_state)`:

    def pour_onto(pine_id, :water), do: Spex.transition({Tree, pine_id}, :a, :sapling)
    def pour_onto(pine_id, :oil), do: Spex.transition({Tree, pine_id}, :a, :withered)
    def observe_growth(pine_id), do: Spex.transition({Tree, pine_id}, :__internal__, :mature_tree)
    def cut_down(pine_id), do: Spex.transition({Tree, pine_id}, :b, :lumber)
    def burn(pine_id), do: Spex.transition({Tree, pine_id}, :c, :ash)

As mentioned above, the states do not have to match the specification states. The actions,
however, do need to match, as these are what the behavioural equivalence is judged on.

An exception to this and a useful addition is the `__internal__` action, which can be used to
record internal state transitions that are not part of the specification but that you still want
to be recorded in the implementation model. These are ignored (or rather: treated specially) for
the behavioural equivalence checks.

Both `Spex.init_instance/4` and `Spex.transition/3` will return `:ok` on success or
`{:error, error}` on failure; this error will be one of the errors from `Spex.Errors` by default.
If you configured a custom error handler in your specifications (see `Spex.Specification`), the
functions will return whatever your error handler returned for the given error.

There are also, `Spex.init_instance!/4` and `Spex.transition!/3`, which raise when their non-bang
counterparts would return an error. Since these errors point to bugs in your implementation, using
these bang variants might be reasonable.

On the other end, there are `Spex.init_instance_async/4` and `Spex.transition_async/3`, which
asynchronously cast to the underlying GenServer and always return `:ok`. Error handling is then
entirely up to your specifications' error handlers and impact on the running system is minimised.

### Derive implementation models: in tests

Your tests should cover all possible transitions of your implementation, so we can use them to
derive an implementation model. To do this, add the following to your `test_helper.exs`:

    Spex.Testing.prepare_for_test_suite()

This prepares the Spex engine to record all transitions from tests and write derived
implementation models in the directory configured above.

In unit tests, we often construct our parameters to be in a certain state. When using
`Spex.init_instance/4`, though, the given initial state is added as an initial state of the
implementation model, which we don't want in these cases. To construct an instance in a certain
state without affecting the implementation model, there is `Spex.Testing.mock_instance!/4`. In a
test for our pine forest above, you might do something like this:

    alias YourApp.Specifications.Tree

    Spex.Testing.mock_instance!(Tree, {Tree, 1}, :mature_tree)

    assert YourApp.Pine.cut_down(1) == :ok

Since `cut_down/1` calls `Spex.transition({Tree, pine_id}, :b, :lumber)`, this test would add a
transition from state `:mature_tree` with action `:b` to state `:lumber` to the implementation
model.

### Derive implementation models: live

When running in non-test environments, Spex expects all implementation models to exist already. If
you'd rather derive your implementation models live, you can either (1) ignore
implementation-model-not-found errors or (2) create empty implementation models in learning mode.

For (1), adjust/add an error handler in your specifications, e.g. as so:

    defmodule YourApp.Specifications.Tree do
      use Spex.Specification

      #...

      @impl Spex.Specification
      def error_handler(%Spex.Errors.ImplModelError{reason: :impl_model_not_found}, _caller), do: :ok
      def error_handler(error, caller), do: super(error, caller)
    end

For (2), for each specification, create a file
`"Elixir.YourApp.Specifications.[YOUR_SPECIFICATION].spex` in your configured implementation model
directory (`:impl_models_dir`) with this content:

```text
Specification: Elixir.YourApp.Specifications.[YOUR_SPECIFICATION]
Learning mode: true
Transitions:
```

For both options, when you think that all transitions have been recorded, via a remote shell, call
`Spex.export_impl_models()`. This will return a list of tuples `{filename, serialisation}`, which
you can then store in your implementation model directory (with the given filename and the
serialisation as content).

### Check behavioural equivalence: offline

After implementation models have been derived and stored, you can run `mix spex` (see
`Mix.Tasks.Spex`) to check whether they are behaviourally equivalent. Currently, the output only
tells you _if_ an implementation model is not behaviourally equivalent to its specification and
you are required to analyse the model to understand why.

### Check behavioural equivalence: online

Once you have derived implementation models that were deemed behaviourally equivalent to their
specification, you are ready to use Spex in production. Every time you initialise and instance or
record a transition, it is checked whether the initialisation or transition is part of the
implementation model. If it is, all is well. If it isn't, a behavioural equivalence check on the
resultant model against the specification is run. In any case, an `%Spex.Errors.InstanceError{}`
is reported, either with `:reason` being `:deviation_still_equivalent` or
`:deviation_not_equivalent`. It is up to your specification's error handler to handle these cases
accordingly (e.g. log the occurrence but still return `:ok` in the former case). The reason is
that even deviations that don't break the equivalence hint at scenarios your tests don't cover.
You can then fix these reports in the future by adding a test that covers the transition or by
adding the transition manually to your implementation model.

### Manual instance management

To inspect or delete the instances managed by an instance manager, each instance manager offers
more functionality than that exposed through `Spex`. See
`Spex.InstanceManager.SimpleInstanceManager` and `Spex.InstanceManager.DistributedInstanceManager`
for details.

# `action`

```elixir
@type action() :: atom()
```

Action label on transitions.

Conventional reserved actions used internally by Spex are:

- `:__internal__` for unobservable/internal steps,
- `:__initialisation__` for synthetic instance initialization transitions.

# `state`

```elixir
@type state() :: atom()
```

State label used in specifications and runtime observations.

# `transition`

```elixir
@type transition() :: {from_state :: state(), action :: action(), to_state :: state()}
```

A labelled transition tuple `{from_state, action, to_state}`.

# `child_spec`

```elixir
@spec child_spec(keyword()) :: Supervisor.child_spec()
```

# `export_impl_models`

# `init_instance`

# `init_instance!`

# `init_instance_async`

# `transition`

# `transition!`

# `transition_async`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
