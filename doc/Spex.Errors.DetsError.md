# `Spex.Errors.DetsError`
[🔗](https://github.com/maxpohlmann/spex/blob/main/lib/spex/errors.ex#L76)

DETS backend operation errors.

# `reason`

```elixir
@type reason() ::
  :traverse
  | :open_file
  | :member
  | :lookup
  | :insert
  | :foldl
  | :delete
  | :delete_all_objects
  | :close
```

# `t`

```elixir
@type t() :: %Spex.Errors.DetsError{
  __exception__: true,
  context: map() | nil,
  reason: reason()
}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
