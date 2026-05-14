# `Spex.Testing`
[🔗](https://github.com/maxpohlmann/spex/blob/main/lib/spex/testing.ex#L1)

Test helpers for preparing and manipulating Spex runtime state.

# `opt`

```elixir
@type opt() :: {:instance_manager, module()} | {:impl_models_dir, Path.t()}
```

# `mock_instance!`

Inserts or updates a mock instance at a specific state for test setup.

# `prepare_for_test_suite`

```elixir
@spec prepare_for_test_suite([opt()]) :: :ok
```

Prepares after-suite hooks that export collected implementation models.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
