# `Spex.ImplModelStore`
[🔗](https://github.com/maxpohlmann/spex/blob/main/lib/spex/impl_model_store.ex#L1)

Loads and persists implementation models in `.spex` file format.

# `load`

```elixir
@spec load(Path.t()) ::
  {:ok, [Spex.ImplModel.t()]} | {:error, Spex.Errors.FileError.t()}
```

Loads all `.spex` models from a directory or a single file path.

# `save`

```elixir
@spec save([Spex.ImplModel.t()], Path.t()) ::
  :ok | {:error, [Spex.Errors.FileError.t()]}
```

Saves implementation models to the target directory.

Returns all write errors if one or more files fail to persist.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
