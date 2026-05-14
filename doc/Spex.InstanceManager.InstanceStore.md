# `Spex.InstanceManager.InstanceStore`
[🔗](https://github.com/maxpohlmann/spex/blob/main/lib/spex/instance_manager/instance_store.ex#L1)

Abstraction layer for instance storage using DETS.

# `instance_hash`

```elixir
@type instance_hash() :: non_neg_integer()
```

# `all`

```elixir
@spec all(:dets.tab_name()) :: {:ok, list()} | {:error, Spex.Errors.DetsError.t()}
```

Gets all instances.

# `all`

```elixir
@spec all(:dets.tab_name(), module()) ::
  {:ok, list()} | {:error, Spex.Errors.DetsError.t()}
```

Gets all instances for a specific specification.

# `close`

```elixir
@spec close(:dets.tab_name()) :: :ok | {:error, Spex.Errors.DetsError.t()}
```

Closes the DETS table.

# `delete`

```elixir
@spec delete(:dets.tab_name(), Spex.InstanceManager.Instance.instance_identifier()) ::
  :ok | {:error, Spex.Errors.DetsError.t()}
```

Deletes an instance by hash.

# `delete_matching`

```elixir
@spec delete_matching(:dets.tab_name(), (Spex.InstanceManager.Instance.t() -&gt;
                                     as_boolean(term()))) ::
  :ok | {:error, Spex.Errors.DetsError.t()}
```

Deletes instances matching the given filter function.

# `exists?`

```elixir
@spec exists?(:dets.tab_name(), Spex.InstanceManager.Instance.instance_identifier()) ::
  {:ok, boolean()} | {:error, Spex.Errors.DetsError.t()}
```

Checks if an instance exists for the given hash.

# `get`

```elixir
@spec get(:dets.tab_name(), Spex.InstanceManager.Instance.instance_identifier()) ::
  {:ok, Spex.InstanceManager.Instance.t()}
  | {:error, Spex.Errors.InstanceError.t()}
  | {:error, Spex.Errors.DetsError.t()}
```

Gets an instance by hash.

# `init`

```elixir
@spec init(:dets.tab_name(), Path.t()) ::
  :ok | {:error, Spex.Errors.DetsError.t() | Spex.Errors.FileError.t()}
```

Initializes the DETS table for storing instances.

# `put`

```elixir
@spec put(:dets.tab_name(), Spex.InstanceManager.Instance.t()) ::
  :ok | {:error, Spex.Errors.DetsError.t()}
```

Stores an instance with the given hash.

# `traverse`

```elixir
@spec traverse(:dets.tab_name(), (Spex.InstanceManager.Instance.t() -&gt; term())) ::
  :ok | {:error, Spex.Errors.DetsError.t()}
```

Traverses all instances with the given function.

# `truncate`

```elixir
@spec truncate(:dets.tab_name()) :: :ok | {:error, Spex.Errors.DetsError.t()}
```

Deletes all instances from the DETS table.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
