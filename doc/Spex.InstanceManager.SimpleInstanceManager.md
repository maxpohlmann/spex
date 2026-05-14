# `Spex.InstanceManager.SimpleInstanceManager`
[🔗](https://github.com/maxpohlmann/spex/blob/main/lib/spex/instance_manager/simple_instance_manager.ex#L1)

Single-node instance manager backed by one `Spex.InstanceManager.Server` process.

Use this manager when you want all instance operations handled by a single
GenServer and a single DETS table.

This module is designed to be added directly to your supervision tree, e.g.
via `child_spec/1`:

    children = [
      {Spex.InstanceManager.SimpleInstanceManager,
       impl_models_dir: "./spex_impl_models",
       dets_dir: "./spex_dets"}
    ]

You may provide runtime options when starting this manager, or provide the
same values via application environment (`config/*.exs`).

## Configuration

`SimpleInstanceManager` forwards server options to
`Spex.InstanceManager.Server` (see `server_opt()`), with one internal detail:

- `:dets_table` is always set to `Spex.InstanceManager.SimpleInstanceManager`
  by this module and should not be provided by callers.

Supported options:

- `:impl_models_dir` (`String.t()`)
  Path to `.spex` implementation model files loaded on startup.
  Default: `"./spex_impl_models"`.

- `:dets_dir` (`String.t()`)
  Directory where the DETS file for this manager is stored.
  Default: `"./spex_dets"`.

- `:check_transition_timeouts_on_start?` (`boolean()`)
  When `true`, existing instances in DETS are checked during startup and
  transition timeout errors are emitted if needed.
  Default: `true`.

- `:prune_interval` (`timeout()`)
  Interval for periodic pruning checks. Use `:infinity` to disable periodic
  checks after startup.
  Default: `to_timeout(%Duration{hour: 6})`.

Pruning semantics:

- one prune pass is always executed immediately on startup,
- when `:prune_interval != :infinity`, additional periodic prune passes are
  scheduled,
- when `:prune_interval == :infinity`, no periodic passes are scheduled after
  the initial startup pass.

## Option Resolution Order

For each server option, effective value is resolved in this order:

1. option passed to `start_link/1` / supervisor child spec,
2. application environment key under `:spex`,
3. server default.

Missing required values raise with a descriptive `ArgumentError`.

## Application Config Example

    config :spex,
      impl_models_dir: "./priv/spex_impl_models",
      dets_dir: "./priv/spex_dets",
      check_transition_timeouts_on_start?: true,
      prune_interval: :timer.hours(6)

# `all_impl_models`

Callback implementation for `c:Spex.InstanceManager.all_impl_models/0`.

# `all_instances`

Callback implementation for `c:Spex.InstanceManager.all_instances/0`.

# `all_instances`

Callback implementation for `c:Spex.InstanceManager.all_instances/1`.

# `child_spec`

Callback implementation for `c:Spex.InstanceManager.child_spec/1`.

# `delete_instance`

Callback implementation for `c:Spex.InstanceManager.delete_instance/1`.

# `delete_instances`

Callback implementation for `c:Spex.InstanceManager.delete_instances/1`.

# `export_impl_models`

Callback implementation for `c:Spex.InstanceManager.export_impl_models/0`.

# `get_instance`

Callback implementation for `c:Spex.InstanceManager.get_instance/1`.

# `init_instance`

Callback implementation for `c:Spex.InstanceManager.init_instance/4`.

# `init_instance!`

Callback implementation for `c:Spex.InstanceManager.init_instance!/4`.

# `init_instance_async`

Callback implementation for `c:Spex.InstanceManager.init_instance_async/4`.

# `mock_instance!`

Callback implementation for `c:Spex.InstanceManager.mock_instance!/4`.

# `start_link`

Callback implementation for `c:Spex.InstanceManager.start_link/1`.

# `transition`

Callback implementation for `c:Spex.InstanceManager.transition/3`.

# `transition!`

Callback implementation for `c:Spex.InstanceManager.transition!/3`.

# `transition_async`

Callback implementation for `c:Spex.InstanceManager.transition_async/3`.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
