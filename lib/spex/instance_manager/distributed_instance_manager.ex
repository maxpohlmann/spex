defmodule Spex.InstanceManager.DistributedInstanceManager do
  @moduledoc """
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
  """

  use Spex.InstanceManager

  defmodule DistributionFactorState do
    @moduledoc """
    Agent storing the configured distribution factor.
    """

    use Agent

    @type distribution_factor :: non_neg_integer()

    @doc """
    Starts the distribution-factor agent.
    """
    @spec start_link(distribution_factor()) :: Agent.on_start()
    def start_link(df), do: Agent.start_link(fn -> df end, name: __MODULE__)

    @doc """
    Returns the currently configured distribution factor.
    """
    @spec get :: distribution_factor()
    def get, do: Agent.get(__MODULE__, & &1)
  end

  @doc "Callback implementation for `c:Spex.InstanceManager.start_link/1`."
  @impl Spex.InstanceManager
  def start_link(opts) do
    {distribution_factor, server_opts} = Keyword.pop(opts, :distribution_factor, 4)

    if not is_integer(distribution_factor) or distribution_factor <= 0,
      do: raise(ArgumentError, "distribution_factor must be a positive integer")

    server_children =
      for i <- 1..distribution_factor do
        server_name = Module.concat(__MODULE__, "Server_#{i}")
        server_opts = Keyword.put(server_opts, :dets_table, server_name)

        %{
          id: i,
          start:
            {GenServer, :start_link,
             [Spex.InstanceManager.Server, server_opts, [name: server_name]]}
        }
      end

    state_child = {DistributionFactorState, distribution_factor}
    children = [state_child | server_children]

    Supervisor.start_link(children, strategy: :one_for_one, name: __MODULE__)
  end

  @doc "Callback implementation for `c:Spex.InstanceManager.init_instance/4`."
  @impl Spex.InstanceManager
  def init_instance(spec, instance_identifier, meta \\ nil, initial_state \\ nil) do
    call_relevant_server(
      {:init_instance, spec, instance_identifier, meta, initial_state},
      instance_identifier
    )
  end

  @doc "Callback implementation for `c:Spex.InstanceManager.init_instance_async/4`."
  @impl Spex.InstanceManager
  def init_instance_async(spec, instance_identifier, meta \\ nil, initial_state \\ nil) do
    cast_relevant_server(
      {{:init_instance, spec, instance_identifier, meta, initial_state}, self()},
      instance_identifier
    )
  end

  @doc "Callback implementation for `c:Spex.InstanceManager.transition/3`."
  @impl Spex.InstanceManager
  def transition(instance_identifier, action, state) do
    call_relevant_server(
      {:transition, instance_identifier, action, state},
      instance_identifier
    )
  end

  @doc "Callback implementation for `c:Spex.InstanceManager.transition_async/3`."
  @impl Spex.InstanceManager
  def transition_async(instance_identifier, action, state) do
    cast_relevant_server(
      {{:transition, instance_identifier, action, state}, self()},
      instance_identifier
    )
  end

  @doc "Callback implementation for `c:Spex.InstanceManager.get_instance/1`."
  @impl Spex.InstanceManager
  def get_instance(instance_identifier) do
    call_relevant_server({:get_instance, instance_identifier}, instance_identifier)
  end

  @doc "Callback implementation for `c:Spex.InstanceManager.all_instances/0`."
  @impl Spex.InstanceManager
  def all_instances do
    call_all_servers_and_aggregate_responses(:all_instances)
  end

  @doc "Callback implementation for `c:Spex.InstanceManager.all_instances/1`."
  @impl Spex.InstanceManager
  def all_instances(specification) do
    call_all_servers_and_aggregate_responses({:all_instances, specification})
  end

  @doc "Callback implementation for `c:Spex.InstanceManager.delete_instance/1`."
  @impl Spex.InstanceManager
  def delete_instance(instance_identifier) do
    call_relevant_server({:delete_instance, instance_identifier}, instance_identifier)
  end

  @doc "Callback implementation for `c:Spex.InstanceManager.delete_instances/1`."
  @impl Spex.InstanceManager
  def delete_instances(filter_fun) do
    call_all_servers_and_aggregate_responses({:delete_instances, filter_fun})
  end

  @doc "Callback implementation for `c:Spex.InstanceManager.all_impl_models/0`."
  @impl Spex.InstanceManager
  def all_impl_models do
    with {:ok, impl_models} <- call_all_servers_and_aggregate_responses(:all_impl_models) do
      impl_models
      |> Enum.group_by(& &1.specification)
      |> Enum.map(fn {specification, impl_models} ->
        transitions = impl_models |> Stream.flat_map(& &1.transitions) |> Enum.uniq()
        learning_mode? = Enum.any?(impl_models, & &1.learning_mode?)

        %Spex.ImplModel{
          specification: specification,
          transitions: MapSet.new(transitions),
          learning_mode?: learning_mode?
        }
      end)
      |> then(&{:ok, &1})
    end
  end

  @doc "Callback implementation for `c:Spex.InstanceManager.export_impl_models/0`."
  @impl Spex.InstanceManager
  def export_impl_models do
    with {:ok, impl_models} <- all_impl_models() do
      impl_models
      |> Enum.map(&{"#{&1.specification}.spex", Spex.ImplModel.serialise(&1)})
      |> then(&{:ok, &1})
    end
  end

  @doc "Callback implementation for `c:Spex.InstanceManager.mock_instance!/4`."
  @impl Spex.InstanceManager
  def mock_instance!(spec, instance_identifier, state, meta \\ nil) do
    call_relevant_server(
      {:mock_instance, spec, instance_identifier, state, meta},
      instance_identifier
    )
    |> __ok__!()
  end

  @spec call_relevant_server(request, Spex.InstanceManager.Instance.instance_identifier()) ::
          response
        when request: term(), response: term()
  defp call_relevant_server(request, instance_identifier) do
    server_name = get_relevant_server_name(instance_identifier)
    GenServer.call(server_name, request)
  end

  @spec cast_relevant_server(request, Spex.InstanceManager.Instance.instance_identifier()) :: :ok
        when request: term()
  defp cast_relevant_server(request, instance_identifier) do
    server_name = get_relevant_server_name(instance_identifier)
    GenServer.cast(server_name, request)
  end

  @spec get_relevant_server_name(Spex.InstanceManager.Instance.instance_identifier()) ::
          GenServer.server()
  defp get_relevant_server_name(instance_identifier) do
    distribution_factor = DistributionFactorState.get()
    hash = :erlang.phash2(instance_identifier)
    server_index = rem(hash, distribution_factor) + 1
    Module.concat(__MODULE__, "Server_#{server_index}")
  end

  @spec call_all_servers_and_aggregate_responses(request) :: response
        when request: term(), response: term()
  defp call_all_servers_and_aggregate_responses(request) do
    get_all_server_names()
    |> Enum.map(fn server_name ->
      Task.async(fn -> GenServer.call(server_name, request) end)
    end)
    |> Task.await_many()
    |> Enum.reduce_while(_results = [], fn
      :ok, results_acc -> {:cont, results_acc}
      {:ok, results}, results_acc -> {:cont, results ++ results_acc}
      {:error, error}, _results_acc -> {:halt, {:error, error}}
    end)
    |> case do
      {:error, error} -> {:error, error}
      [] = _aggregated_results -> :ok
      aggregated_results -> {:ok, aggregated_results}
    end
  end

  @spec get_all_server_names :: [GenServer.server()]
  defp get_all_server_names do
    distribution_factor = DistributionFactorState.get()

    for i <- 1..distribution_factor do
      Module.concat(__MODULE__, "Server_#{i}")
    end
  end
end
