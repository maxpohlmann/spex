# `Spex.Errors.InstanceError`
[🔗](https://github.com/maxpohlmann/spex/blob/main/lib/spex/errors.ex#L52)

Instance lifecycle errors such as duplicate or missing identifiers.

# `reason`

```elixir
@type reason() :: :instance_identifier_not_found | :instance_identifier_already_in_use
```

# `t`

```elixir
@type t() :: %Spex.Errors.InstanceError{
  __exception__: true,
  context: map() | nil,
  reason: reason()
}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
