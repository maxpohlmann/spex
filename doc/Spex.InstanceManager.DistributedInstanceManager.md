# `Spex.InstanceManager.DistributedInstanceManager`
[🔗](https://github.com/maxpohlmann/spex/blob/main/lib/spex/instance_manager/distributed_instance_manager.ex#L1)

Instance manager that shards instances across multiple
`Spex.InstanceManager.Server` processes.

This manager hashes each instance identifier and routes operations to one of
several server shards. It is useful when you want to reduce contention versus
a single-manager setup while preserving the same high-level API.

This module is designed to be added directly to your supervision tree:

    children = [
      {Spex.InstanceManager.DistributedInstanceManager,
       distribution_factor: 8,
       impl_models_dir: "./spex_impl_models",
       dets_dir: "./spex_dets"}
    ]

You may pass options at startup or configure them in application config.

## Configuration

This manager accepts one distribution-specific option plus server options
forwarded to each shard (`Spex.InstanceManager.Server.server_opt()`).

- `:distribution_factor` (`pos_integer()`)
  Number of server shards.
  Default: `4`.
  Must be a positive integer; otherwise `start_link/1` raises
  `ArgumentError`.

Forwarded server options:

- `:impl_models_dir` (`String.t()`)
  Directory from which `.spex` impl models are loaded.
  Each shard loads from the same directory at startup.
  Default: `"./spex_impl_models"`.

- `:dets_dir` (`String.t()`)
  Base directory for shard DETS files.
  Default: `"./spex_dets"`.

- `:check_transition_timeouts_on_start?` (`boolean()`)
  Enables startup timeout checks per shard.
  Default: `true`.

- `:prune_interval` (`timeout()`)
  Periodic pruning interval per shard.
  Default: `to_timeout(%Duration{hour: 6})`.

Pruning semantics per shard:

- one prune pass is always executed immediately on shard startup,
- when `:prune_interval != :infinity`, additional periodic prune passes are
  scheduled,
- when `:prune_interval == :infinity`, no periodic passes are scheduled after
  the initial startup pass.

Internal shard detail:

- `:dets_table` is set per shard by this module
  (`Spex.InstanceManager.DistributedInstanceManager.Server_<n>`), so callers
  should not provide it.

## Option Resolution Order

For forwarded server options, each shard resolves values in this order:

1. option passed to this manager at startup,
2. application environment key under `:spex`,
3. server default.

## Routing Semantics

Instance routing is deterministic:

- hash = `:erlang.phash2(instance_identifier)`
- shard index = `rem(hash, distribution_factor) + 1`

All operations for a given instance identifier are routed to the same shard.

Methods that aggregate globally (`all_instances/0`, `all_instances/1`,
`delete_instances/1`, `all_impl_models/0`) query all shards and combine the
results.

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
