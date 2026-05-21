# `Spex.InstanceManager.DistributedInstanceManager.DistributionFactorState`
[🔗](https://github.com/maxpohlmann/spex/blob/main/lib/spex/instance_manager/distributed_instance_manager.ex#L42)

Agent storing the configured distribution factor.

# `distribution_factor`

```elixir
@type distribution_factor() :: non_neg_integer()
```

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `get`

```elixir
@spec get() :: distribution_factor()
```

Returns the currently configured distribution factor.

# `start_link`

```elixir
@spec start_link(distribution_factor()) :: Agent.on_start()
```

Starts the distribution-factor agent.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
