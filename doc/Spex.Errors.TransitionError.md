# `Spex.Errors.TransitionError`
[🔗](https://github.com/maxpohlmann/spex/blob/main/lib/spex/errors.ex#L39)

Transition-level error used for deviations and timeout conditions.

# `reason`

```elixir
@type reason() ::
  :transition_timeout | :deviation_not_equivalent | :deviation_still_equivalent
```

# `t`

```elixir
@type t() :: %Spex.Errors.TransitionError{
  __exception__: true,
  context: map() | nil,
  reason: reason()
}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
