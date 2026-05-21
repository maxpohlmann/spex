# `Spex.InstanceManager.DistributedInstanceManager`
[🔗](https://github.com/maxpohlmann/spex/blob/main/lib/spex/instance_manager/distributed_instance_manager.ex#L1)

Instance manager that shards instances across multiple `Spex.InstanceManager.Server` processes.

This manager hashes each instance identifier and routes operations to one of
several server shards. It is useful when you want to reduce contention versus
a single-manager setup while preserving the same high-level API.

See `m:Spex#module-using-other-instance-managers` for info on using this instance manager.

## Configuration

This manager accepts one distribution-specific option (`:distribution_factor`) plus server options
forwarded to each shard (`Spex.InstanceManager.Server.server_opt()`).

- `:distribution_factor` (`pos_integer()`)
  Number of server shards.
  Default: `4`.
  Must be a positive integer; otherwise `start_link/1` raises `ArgumentError`.

- `:dets_table` is set per shard by this module
  (`Spex.InstanceManager.DistributedInstanceManager.Server_<n>`), so callers should not provide
  it.

- For the other opts, see `Spex.InstanceManager.SimpleInstanceManager`

## Routing semantics

Instance routing is deterministic:

- hash = `:erlang.phash2(instance_identifier)`
- shard index = `rem(hash, distribution_factor) + 1`

All operations for a given instance identifier are routed to the same shard.

Methods that aggregate globally (`all_instances/0`, `all_instances/1`, `delete_instances/1`,
`all_impl_models/0`) query all shards and combine the results.

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
