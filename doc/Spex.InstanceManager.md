# `Spex.InstanceManager`
[🔗](https://github.com/maxpohlmann/spex/blob/main/lib/spex/instance_manager.ex#L1)

Behaviour contract plus shared helpers for Spex instance managers.

# `instance_manager_opt`

```elixir
@type instance_manager_opt() ::
  Spex.InstanceManager.Server.server_opt() | (other_opt :: {atom(), term()})
```

# `all_impl_models`

```elixir
@callback all_impl_models() :: {:ok, [Spex.ImplModel.t()]}
```

Returns all currently known implementation models.

# `all_instances`

```elixir
@callback all_instances() ::
  {:ok, [Spex.InstanceManager.Instance.t()]}
  | {:error, Spex.Errors.DetsError.t()}
```

Returns all instances managed by this instance manager.

# `all_instances`

```elixir
@callback all_instances(Spex.Specification.t()) ::
  {:ok, [Spex.InstanceManager.Instance.t()]}
  | {:error, Spex.Errors.DetsError.t()}
```

Returns all instances for a given specification module.

# `child_spec`

```elixir
@callback child_spec(term()) :: Supervisor.child_spec()
```

Returns a child spec for supervising the instance manager.

# `delete_instance`

```elixir
@callback delete_instance(Spex.InstanceManager.Instance.instance_identifier()) ::
  :ok | {:error, Spex.Errors.DetsError.t()}
```

Deletes one instance by identifier.

# `delete_instances`

```elixir
@callback delete_instances((Spex.InstanceManager.Instance.t() -&gt; as_boolean(term()))) ::
  :ok | {:error, Spex.Errors.DetsError.t()}
```

Deletes all instances matching the provided filter function.

# `export_impl_models`

```elixir
@callback export_impl_models() ::
  {:ok, [{filename :: String.t(), Spex.ImplModel.serialisation()}]}
```

Serialises and exports implementation models as `{filename, content}` tuples.

# `get_instance`

```elixir
@callback get_instance(Spex.InstanceManager.Instance.instance_identifier()) ::
  {:ok, Spex.InstanceManager.Instance.t()}
  | {:error, Spex.Errors.InstanceError.t()}
  | {:error, Spex.Errors.DetsError.t()}
```

Fetches one instance by identifier.

# `init_instance`

```elixir
@callback init_instance(
  Spex.Specification.t(),
  Spex.InstanceManager.Instance.instance_identifier(),
  Spex.InstanceManager.Instance.meta() | nil,
  Spex.state() | nil
) :: :ok | Spex.Specification.error_handler_return()
```

Initializes a new instance and records initialisation as the first transition.

Returns `:ok` on success or an error-handler return when initialization fails.

# `init_instance!`

```elixir
@callback init_instance!(
  Spex.Specification.t(),
  Spex.InstanceManager.Instance.instance_identifier(),
  Spex.InstanceManager.Instance.meta() | nil,
  Spex.state() | nil
) :: :ok
```

Same as `init_instance/4`, but raises on errors.

# `init_instance_async`
*optional* 

```elixir
@callback init_instance_async(
  Spex.Specification.t(),
  Spex.InstanceManager.Instance.instance_identifier(),
  Spex.InstanceManager.Instance.meta() | nil,
  Spex.state() | nil
) :: :ok
```

Asynchronously initializes a new instance.

Errors are reported via specification error handling instead of direct return.

# `mock_instance!`

```elixir
@callback mock_instance!(
  Spex.Specification.t(),
  Spex.InstanceManager.Instance.instance_identifier(),
  Spex.state(),
  Spex.InstanceManager.Instance.meta() | nil
) :: :ok
```

Inserts or updates a mock instance at a given state for testing purposes.

# `start_link`

```elixir
@callback start_link([instance_manager_opt()]) :: Supervisor.on_start()
```

Starts the instance manager process tree.

# `transition`

```elixir
@callback transition(
  Spex.InstanceManager.Instance.instance_identifier(),
  Spex.action(),
  Spex.state()
) :: :ok | Spex.Specification.error_handler_return()
```

Records an observed transition for an existing instance.

Returns `:ok` on success or an error-handler return when validation/storage fails.

# `transition!`

```elixir
@callback transition!(
  Spex.InstanceManager.Instance.instance_identifier(),
  Spex.action(),
  Spex.state()
) :: :ok
```

Same as `transition/3`, but raises on errors.

# `transition_async`
*optional* 

```elixir
@callback transition_async(
  Spex.InstanceManager.Instance.instance_identifier(),
  Spex.action(),
  Spex.state()
) :: :ok
```

Asynchronously records a transition for an existing instance.

# `__using__`
*macro* 

Injects the `Spex.InstanceManager` behaviour and shared convenience functions.

Generated convenience functions:

- `child_spec/1`
- `init_instance!/4`
- `transition!/3`

# `default_instance_manager`

```elixir
@spec default_instance_manager() :: module()
```

Returns the compile-time configured default instance manager module.

# `default_instance_manager_opts`

```elixir
@spec default_instance_manager_opts() :: keyword()
```

Returns compile-time options for the default instance manager.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
