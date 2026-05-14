# `Spex.Errors.FileError`
[🔗](https://github.com/maxpohlmann/spex/blob/main/lib/spex/errors.ex#L95)

Alias type wrapper for file-system errors represented by `File.Error`.

# `t`

```elixir
@type t() :: %File.Error{
  __exception__: true,
  action: term(),
  path: term(),
  reason: term()
}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
