# `Spex.Testing`
[🔗](https://github.com/maxpohlmann/spex/blob/main/lib/spex/testing.ex#L1)

Test helpers for preparing and manipulating Spex runtime state.

# `opt`

```elixir
@type opt() :: {:instance_manager, module()} | {:impl_models_dir, Path.t()}
```

# `mock_instance!`

Inserts or updates a mock instance at a specific state for test setup.

Use this in unit tests to setup an instance without affecting the impl_model.

# `prepare_for_test_suite`

```elixir
@spec prepare_for_test_suite([opt()]) :: :ok
```

Prepares after-suite hooks that export collected implementation models.

Call this in your `test_helper.exs`.

It accepts the following opts:

- `:instance_manager`: An instance manager module. By default, it uses the configured default
  instance manager (see `m:Spex#module-using-other-instance-managers`). Specify this if you are
  starting your instance manager in your supervision tree directly.
- `:impl_models_dir`: Path to the directory where collected implementation models are exported
  after tests. By default, this is the configured implementation models directory (see
  `m:Spex#module-configuration`).

---

*Consult [api-reference.md](api-reference.md) for complete listing*
