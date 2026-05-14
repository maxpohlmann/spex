# `Spex.InstanceManager.Instance`
[🔗](https://github.com/maxpohlmann/spex/blob/main/lib/spex/instance_manager/instance.ex#L1)

Runtime representation of a specification instance and its observed history.

# `instance_identifier`

```elixir
@type instance_identifier() :: term()
```

# `meta`

```elixir
@type meta() :: map()
```

# `t`

```elixir
@type t() :: %Spex.InstanceManager.Instance{
  current_state: Spex.state() | nil,
  identifier: instance_identifier(),
  meta: meta() | nil,
  specification: Spex.Specification.t(),
  transitions: [transition_record()]
}
```

# `transition_record`

```elixir
@type transition_record() ::
  {action :: Spex.action(), to_state :: Spex.state(), timestamp :: DateTime.t()}
```

# `beyond_transition_timeout?`

```elixir
@spec beyond_transition_timeout?(t(), DateTime.t()) :: boolean()
```

Returns whether the instance exceeded its specification transition timeout.

# `initialise`

```elixir
@spec initialise(Spex.Specification.t(), instance_identifier(), meta() | nil) :: t()
```

Initialises a new instance with an empty transition history.

# `observe_transition`

```elixir
@spec observe_transition(t(), Spex.action(), Spex.state()) :: t()
```

Records an observed transition and updates the current state.

# `prunable?`

```elixir
@spec prunable?(t()) :: boolean()
```

Returns whether the instance is currently eligible for pruning.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
