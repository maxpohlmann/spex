defmodule Spex.InstanceManager.Server do
  @moduledoc """
  Core GenServer that manages instances and implementation-model observation.

  This process is the stateful runtime engine behind instance managers.
  """

  use GenServer

  alias Spex.Errors.DetsError
  alias Spex.Errors.FileError
  alias Spex.Errors.ImplModelError
  alias Spex.Errors.InstanceError
  alias Spex.Errors.TransitionError
  alias Spex.ImplModel
  alias Spex.ImplModelStore
  alias Spex.InstanceManager.Instance
  alias Spex.InstanceManager.InstanceStore

  @default_opts %{
    impl_models_dir: "./spex_impl_models",
    dets_dir: "./spex_dets",
    check_transition_timeouts_on_start?: true,
    prune_interval: %Duration{hour: 6} |> to_timeout()
  }

  @type server_opt ::
          {:impl_models_dir, String.t()}
          | {:dets_table, atom()}
          | {:dets_dir, String.t()}
          | {:check_transition_timeouts_on_start?, boolean()}
          | {:prune_interval, timeout()}

  @type impl_models_map :: %{optional(Spex.Specification.t()) => Spex.ImplModel.t()}

  @type server_state :: %{
          dets_table: atom(),
          impl_models: impl_models_map(),
          prune_interval: timeout()
        }

  @impl GenServer
  @spec init([server_opt()]) ::
          {:ok, server_state()} | {:stop, FileError.t() | DetsError.t()}
  def init(opts) do
    impl_models_dir = get_opt(opts, :impl_models_dir)
    dets_table = get_opt(opts, :dets_table)
    dets_dir = get_opt(opts, :dets_dir)
    check_transition_timeouts_on_start? = get_opt(opts, :check_transition_timeouts_on_start?)
    prune_interval = get_opt(opts, :prune_interval)

    with {:ok, impl_models} <- load_impl_models(impl_models_dir),
         :ok <- init_dets_table(dets_table, dets_dir),
         :ok <- maybe_check_transition_timeouts(dets_table, check_transition_timeouts_on_start?) do
      Process.send_after(self(), :prune_instances, 0)

      {:ok,
       %{
         dets_table: dets_table,
         impl_models: impl_models,
         prune_interval: prune_interval
       }}
    else
      {:error, error} -> {:stop, error}
    end
  end

  @impl GenServer
  def terminate(_reason, server_state) do
    test_mode? = Application.get_env(:spex, :test_mode?, false)
    if test_mode?, do: InstanceStore.truncate(server_state.dets_table)

    InstanceStore.close(server_state.dets_table)

    :ok
  end

  @spec get_opt([server_opt()], atom()) :: term()
  defp get_opt(opts, key) do
    value =
      Keyword.get(
        opts,
        key,
        Application.get_env(
          :spex,
          key,
          Map.get(
            @default_opts,
            key,
            :missing
          )
        )
      )

    if value == :missing do
      raise(
        ArgumentError,
        "Missing required option :#{key}. Please provide it as an argument or configure it in " <>
          "the application environment; see the `Spex` moduledoc for details."
      )
    else
      value
    end
  end

  @spec load_impl_models(Path.t()) :: {:ok, impl_models_map()} | {:error, FileError.t()}
  defp load_impl_models(impl_models_dir) do
    with {:ok, impl_models} <- ImplModelStore.load(impl_models_dir) do
      test_mode? = Application.get_env(:spex, :test_mode?, false)

      impl_models
      |> maybe_set_learning_mode_for_all(test_mode?)
      |> Map.new(&{&1.specification, &1})
      |> then(&{:ok, &1})
    end
  end

  @spec maybe_set_learning_mode_for_all([Spex.ImplModel.t()], boolean()) :: [Spex.ImplModel.t()]
  defp maybe_set_learning_mode_for_all(impl_models, test_mode?)

  defp maybe_set_learning_mode_for_all(impl_models, false),
    do: impl_models

  defp maybe_set_learning_mode_for_all(impl_models, true),
    do: Enum.map(impl_models, &%{&1 | learning_mode?: true})

  @spec init_dets_table(:dets.tab_name(), Path.t()) :: :ok | {:error, DetsError.t()}
  defp init_dets_table(dets_table, dets_dir) do
    InstanceStore.init(dets_table, dets_dir)
  end

  @spec maybe_check_transition_timeouts(:dets.tab_name(), boolean()) ::
          :ok | {:error, DetsError.t()}
  defp maybe_check_transition_timeouts(dets_table, check_transition_timeouts_on_start?)

  defp maybe_check_transition_timeouts(_, false), do: :ok

  defp maybe_check_transition_timeouts(dets_table, true) do
    now = DateTime.utc_now()

    InstanceStore.traverse(dets_table, fn instance ->
      if Instance.beyond_transition_timeout?(instance, now) do
        error = %TransitionError{
          reason: :transition_timeout,
          context: %{instance: instance}
        }

        instance.specification.error_handler(error, self())
      end
    end)
  end

  @impl GenServer
  def handle_info(request, server_state)

  def handle_info(:prune_instances, server_state) do
    InstanceStore.delete_matching(server_state.dets_table, fn instance ->
      Instance.prunable?(instance)
    end)

    if server_state.prune_interval != :infinity,
      do: Process.send_after(self(), :prune_instances, server_state.prune_interval)

    {:noreply, server_state}
  end

  def handle_info(
        {:check_transition_timeout, instance_identifier, prev_transition_timestamp},
        server_state
      ) do
    case InstanceStore.get(server_state.dets_table, instance_identifier) do
      {:ok,
       %Instance{
         transitions: [{_action, _to_state, ^prev_transition_timestamp} | _],
         specification: specification
       } = instance} ->
        error = %TransitionError{
          reason: :transition_timeout,
          context: %{instance: instance}
        }

        specification.error_handler(error, self())

      {:ok, %Instance{}} ->
        nil

      {:error, error} ->
        Spex.Specification.default_error_handler(error, self())
    end

    {:noreply, server_state}
  end

  @impl GenServer
  def handle_cast(msg, server_state)

  def handle_cast({request, caller}, server_state) do
    {:reply, _reply, server_state} = handle_call(request, {caller, nil}, server_state)
    {:noreply, server_state}
  end

  @impl GenServer
  def handle_call(msg, from, server_state)

  def handle_call({:get_instance, instance_identifier}, _from, server_state) do
    maybe_instance = InstanceStore.get(server_state.dets_table, instance_identifier)
    {:reply, maybe_instance, server_state}
  end

  def handle_call(:all_instances, _from, server_state) do
    maybe_all_instances = InstanceStore.all(server_state.dets_table)
    {:reply, maybe_all_instances, server_state}
  end

  def handle_call({:all_instances, specification}, _from, server_state) do
    maybe_all_instances = InstanceStore.all(server_state.dets_table, specification)
    {:reply, maybe_all_instances, server_state}
  end

  def handle_call({:delete_instance, instance_identifier}, _from, server_state) do
    maybe_ok = InstanceStore.delete(server_state.dets_table, instance_identifier)
    {:reply, maybe_ok, server_state}
  end

  def handle_call({:delete_instances, filter_fun}, _from, server_state) do
    maybe_ok = InstanceStore.delete_matching(server_state.dets_table, filter_fun)
    {:reply, maybe_ok, server_state}
  end

  def handle_call(:all_impl_models, _from, server_state) do
    impl_models = Map.values(server_state.impl_models)
    {:reply, {:ok, impl_models}, server_state}
  end

  def handle_call(
        {:mock_instance, specification, instance_identifier, state, meta},
        _from,
        server_state
      ) do
    instance = Instance.initialise(specification, instance_identifier, meta)
    instance = %Instance{instance | current_state: state}
    maybe_ok = InstanceStore.put(server_state.dets_table, instance)

    {:reply, maybe_ok, server_state}
  end

  def handle_call(
        {:init_instance, specification, instance_identifier, meta, initial_state},
        {caller, _},
        server_state
      ) do
    case InstanceStore.exists?(server_state.dets_table, instance_identifier) do
      {:ok, false} ->
        instance = Instance.initialise(specification, instance_identifier, meta)
        InstanceStore.put(server_state.dets_table, instance)

        action = :__initialisation__
        state = initial_state || specification.initial_state()

        {maybe_ok, server_state} =
          handle_transition(instance, action, state, caller, server_state)

        {:reply, maybe_ok, server_state}

      {:ok, true} ->
        error =
          %InstanceError{
            reason: :instance_identifier_already_in_use,
            context: %{instance_identifier: instance_identifier}
          }

        maybe_ok = specification.error_handler(error, caller)
        {:reply, maybe_ok, server_state}

      {:error, error} ->
        maybe_ok = specification.error_handler(error, caller)
        {:reply, maybe_ok, server_state}
    end
  end

  def handle_call({:transition, instance_identifier, action, state}, {caller, _}, server_state) do
    case InstanceStore.get(server_state.dets_table, instance_identifier) do
      {:ok, instance} ->
        {maybe_ok, server_state} =
          handle_transition(instance, action, state, caller, server_state)

        {:reply, maybe_ok, server_state}

      {:error, error} ->
        maybe_ok = Spex.Specification.default_error_handler(error, caller)
        {:reply, maybe_ok, server_state}
    end
  end

  @spec handle_transition(Instance.t(), Spex.action(), Spex.state(), pid(), server_state()) ::
          {Spex.Specification.error_handler_return(), server_state()}
  defp handle_transition(instance, action, state, caller, server_state) do
    case find_or_init_impl_model(server_state.impl_models, instance.specification, caller) do
      {:ok, impl_model} ->
        {maybe_ok, impl_model} =
          do_handle_transition(impl_model, instance, action, state, caller, server_state)

        impl_models = Map.put(server_state.impl_models, instance.specification, impl_model)
        server_state = %{server_state | impl_models: impl_models}

        {maybe_ok, server_state}

      {:error, error} ->
        {{:error, error}, server_state}
    end
  end

  @spec find_or_init_impl_model(impl_models_map(), Spex.Specification.t(), pid()) ::
          {:ok, ImplModel.t()} | Spex.Specification.error_handler_return()
  defp find_or_init_impl_model(impl_models, specification, caller) do
    case Map.get(impl_models, specification) do
      %ImplModel{} = impl_model ->
        {:ok, impl_model}

      nil ->
        error = %ImplModelError{reason: :impl_model_not_found}

        with :ok <- specification.error_handler(error, caller) do
          {:ok, ImplModel.initialise(specification)}
        end
    end
  end

  @spec do_handle_transition(
          ImplModel.t(),
          Instance.t(),
          Spex.action(),
          Spex.state(),
          pid(),
          server_state()
        ) :: {Spex.Specification.error_handler_return(), ImplModel.t()}
  defp do_handle_transition(impl_model, instance, action, state, caller, server_state) do
    prev_state = instance.current_state
    instance = Instance.observe_transition(instance, action, state)
    transition = {prev_state, action, state}
    {observation_status, impl_model} = ImplModel.observe_transition(impl_model, transition)

    maybe_ok = handle_observation_result(observation_status, instance, transition, caller)

    case InstanceStore.put(server_state.dets_table, instance) do
      :ok ->
        maybe_schedule_timeout_check(instance)
        {maybe_ok, impl_model}

      {:error, dets_error} ->
        maybe_ok = instance.specification.error_handler(dets_error, caller)
        {maybe_ok, impl_model}
    end
  end

  @spec handle_observation_result(
          ImplModel.observation_status(),
          Instance.t(),
          Spex.transition(),
          pid()
        ) :: Spex.Specification.error_handler_return()
  defp handle_observation_result(reason, instance, transition, caller)

  defp handle_observation_result(:ok, _, _, _), do: :ok

  defp handle_observation_result(reason, instance, transition, caller) do
    error = %TransitionError{
      reason: reason,
      context: %{
        instance: instance,
        deviating_transition: transition
      }
    }

    instance.specification.error_handler(error, caller)
  end

  @spec maybe_schedule_timeout_check(Instance.t()) :: :ok
  defp maybe_schedule_timeout_check(%Instance{
         identifier: instance_identifier,
         specification: specification,
         transitions: [{_action, _to_state, last_transition_timestamp} | _]
       }) do
    transition_timeout = specification.transition_timeout()

    if transition_timeout != :infinity do
      msg = {:check_transition_timeout, instance_identifier, last_transition_timestamp}
      Process.send_after(self(), msg, transition_timeout)
    end

    :ok
  end
end
