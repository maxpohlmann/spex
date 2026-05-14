# `Spex.ImplModel`
[🔗](https://github.com/maxpohlmann/spex/blob/main/lib/spex/impl_model.ex#L1)

Represents the observed implementation model built from runtime transitions.

# `observation_status`

```elixir
@type observation_status() ::
  :ok | :deviation_still_bisimilar | :deviation_not_bisimilar
```

# `serialisation`

```elixir
@type serialisation() :: String.t()
```

# `t`

```elixir
@type t() :: %Spex.ImplModel{
  learning_mode?: boolean(),
  specification: Spex.Specification.t(),
  transitions: MapSet.t(Spex.transition())
}
```

# `deserialise`

```elixir
@spec deserialise(serialisation()) ::
  {:ok, t()} | {:error, Spex.Errors.ImplModelError.t()}
```

Deserialises `.spex` content into an implementation model.

# `initialise`

```elixir
@spec initialise(Spex.Specification.t()) :: t()
```

Creates an empty implementation model for a specification in learning mode.

# `observe_transition`

```elixir
@spec observe_transition(t(), Spex.transition()) :: {observation_status(), t()}
```

Observes a transition and returns its status and resulting model.

In learning mode, the transition is added. Outside learning mode, the model
is checked for bisimilarity impact without mutating stored transitions.

# `serialise`

```elixir
@spec serialise(t()) :: serialisation()
```

Serialises an implementation model into `.spex` text format.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
