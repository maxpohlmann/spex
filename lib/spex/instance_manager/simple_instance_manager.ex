defmodule Spex.InstanceManager.SimpleInstanceManager do
  @moduledoc """
  Single-node instance manager backed by one `Spex.InstanceManager.Server` process.

  Use this manager when you want all instance operations handled by a single
  GenServer and a single DETS table.

  See `m:Spex#module-using-other-instance-managers` for info on using this instance manager.

  ## Configuration

  `SimpleInstanceManager` forwards server options to `Spex.InstanceManager.Server` (see
  `Spex.InstanceManager.Server.server_opt()`), with one internal detail:

  - `:dets_table` is always set to `Spex.InstanceManager.SimpleInstanceManager` by this module and
    should not be provided by callers.

  Supported options (see `m:Spex#module-configuration`):

  - `:impl_models_dir` (`String.t()`)
    Path to `.spex` implementation model files loaded on startup.
    Default: value from config or else `"./spex_impl_models"`.

  - `:dets_dir` (`String.t()`)
    Directory where the DETS file for this manager is stored.
    Default: value from config or else `"./spex_dets"`.

  - `:check_transition_timeouts_on_start?` (`boolean()`)
    When `true`, existing instances in DETS are checked during startup and transition timeout errors
    are emitted if needed.
    Default: `true`.

  - `:prune_interval` (`timeout()`)
    Interval for periodic pruning checks. Use `:infinity` to disable periodic
    checks after startup.
    Default: `%Duration{hour: 6} |> to_timeout()`.

  Pruning semantics:

  - one prune pass is always executed immediately on startup,
  - when `:prune_interval != :infinity`, additional periodic prune passes are scheduled,
  - when `:prune_interval == :infinity`, no periodic passes are scheduled after the initial startup
    pass.

  ## Option resolution order

  For each server option, effective value is resolved in this order:

  1. option passed to `start_link/1` / supervisor child spec,
  2. application environment key under `:spex`,
  3. the default value.
  """

  use Spex.InstanceManager

  @server_name Module.concat(__MODULE__, "Server")

  @doc "Callback implementation for `c:Spex.InstanceManager.start_link/1`."
  @impl Spex.InstanceManager
  def start_link(opts) do
    server_opts = Keyword.put(opts, :dets_table, __MODULE__)

    children = [
      %{
        id: :server,
        start:
          {GenServer, :start_link,
           [Spex.InstanceManager.Server, server_opts, [name: @server_name]]}
      }
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: __MODULE__)
  end

  @doc "Callback implementation for `c:Spex.InstanceManager.init_instance/4`."
  @impl Spex.InstanceManager
  def init_instance(spec, instance_identifier, meta \\ nil, initial_state \\ nil) do
    GenServer.call(
      @server_name,
      {:init_instance, spec, instance_identifier, meta, initial_state}
    )
  end

  @doc "Callback implementation for `c:Spex.InstanceManager.init_instance_async/4`."
  @impl Spex.InstanceManager
  def init_instance_async(spec, instance_identifier, meta \\ nil, initial_state \\ nil) do
    GenServer.cast(
      @server_name,
      {{:init_instance, spec, instance_identifier, meta, initial_state}, self()}
    )
  end

  @doc "Callback implementation for `c:Spex.InstanceManager.transition/3`."
  @impl Spex.InstanceManager
  def transition(instance_identifier, action, state) do
    GenServer.call(
      @server_name,
      {:transition, instance_identifier, action, state}
    )
  end

  @doc "Callback implementation for `c:Spex.InstanceManager.transition_async/3`."
  @impl Spex.InstanceManager
  def transition_async(instance_identifier, action, state) do
    GenServer.cast(
      @server_name,
      {{:transition, instance_identifier, action, state}, self()}
    )
  end

  @doc "Callback implementation for `c:Spex.InstanceManager.get_instance/1`."
  @impl Spex.InstanceManager
  def get_instance(instance_identifier) do
    GenServer.call(@server_name, {:get_instance, instance_identifier})
  end

  @doc "Callback implementation for `c:Spex.InstanceManager.all_instances/0`."
  @impl Spex.InstanceManager
  def all_instances do
    GenServer.call(@server_name, :all_instances)
  end

  @doc "Callback implementation for `c:Spex.InstanceManager.all_instances/1`."
  @impl Spex.InstanceManager
  def all_instances(specification) do
    GenServer.call(@server_name, {:all_instances, specification})
  end

  @doc "Callback implementation for `c:Spex.InstanceManager.delete_instance/1`."
  @impl Spex.InstanceManager
  def delete_instance(instance_identifier) do
    GenServer.call(@server_name, {:delete_instance, instance_identifier})
  end

  @doc "Callback implementation for `c:Spex.InstanceManager.delete_instances/1`."
  @impl Spex.InstanceManager
  def delete_instances(filter_fun) do
    GenServer.call(@server_name, {:delete_instances, filter_fun})
  end

  @doc "Callback implementation for `c:Spex.InstanceManager.all_impl_models/0`."
  @impl Spex.InstanceManager
  def all_impl_models do
    GenServer.call(@server_name, :all_impl_models)
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
    GenServer.call(
      @server_name,
      {:mock_instance, spec, instance_identifier, state, meta}
    )
    |> __ok__!()
  end
end
