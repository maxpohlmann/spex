# `Spex.InstanceManager.Server`
[🔗](https://github.com/maxpohlmann/spex/blob/main/lib/spex/instance_manager/server.ex#L1)

Core GenServer that manages instances and implementation-model observation.

This process is the stateful runtime engine behind both simple and
distributed instance managers.

Responsibilities include:

- loading implementation models on startup,
- storing and retrieving instances via `Spex.InstanceManager.InstanceStore`,
- validating observed transitions against implementation models,
- scheduling transition timeout checks,
- pruning stale instances.

# `impl_models_map`

```elixir
@type impl_models_map() :: %{optional(Spex.Specification.t()) =&gt; Spex.ImplModel.t()}
```

# `server_opt`

```elixir
@type server_opt() ::
  {:impl_models_dir, String.t()}
  | {:dets_table, atom()}
  | {:dets_dir, String.t()}
  | {:check_transition_timeouts_on_start?, boolean()}
  | {:prune_interval, timeout()}
```

# `server_state`

```elixir
@type server_state() :: %{
  dets_table: atom(),
  impl_models: impl_models_map(),
  prune_interval: timeout()
}
```

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
