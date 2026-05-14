# `Spex.Errors.ImplModelError`
[🔗](https://github.com/maxpohlmann/spex/blob/main/lib/spex/errors.ex#L64)

ImplModel loading and lookup errors.

# `reason`

```elixir
@type reason() :: :impl_model_not_found | :deserialisation_failed
```

# `t`

```elixir
@type t() :: %Spex.Errors.ImplModelError{
  __exception__: true,
  context: map() | nil,
  reason: reason()
}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
