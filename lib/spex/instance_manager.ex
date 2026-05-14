defmodule Spex.InstanceManager do
  @moduledoc """
  Behaviour contract plus shared helpers for Spex instance managers.
  """

  @type instance_manager_opt ::
          Spex.InstanceManager.Server.server_opt() | (other_opt :: {atom(), term()})

  @doc """
  Returns a child spec for supervising the instance manager.
  """
  @callback child_spec(term()) :: Supervisor.child_spec()

  @doc """
  Starts the instance manager process tree.
  """
  @callback start_link([instance_manager_opt()]) :: Supervisor.on_start()

  @doc """
  Initializes a new instance and records initialisation as the first transition.

  Returns `:ok` on success or an error-handler return when initialization fails.
  """
  @callback init_instance(
              Spex.Specification.t(),
              Spex.InstanceManager.Instance.instance_identifier(),
              Spex.InstanceManager.Instance.meta() | nil,
              Spex.state() | nil
            ) :: :ok | Spex.Specification.error_handler_return()

  @doc """
  Same as `init_instance/4`, but raises on errors.
  """
  @callback init_instance!(
              Spex.Specification.t(),
              Spex.InstanceManager.Instance.instance_identifier(),
              Spex.InstanceManager.Instance.meta() | nil,
              Spex.state() | nil
            ) :: :ok

  @doc """
  Asynchronously initializes a new instance.

  Errors are reported via specification error handling instead of direct return.
  """
  @callback init_instance_async(
              Spex.Specification.t(),
              Spex.InstanceManager.Instance.instance_identifier(),
              Spex.InstanceManager.Instance.meta() | nil,
              Spex.state() | nil
            ) :: :ok

  @doc """
  Records an observed transition for an existing instance.

  Returns `:ok` on success or an error-handler return when validation/storage fails.
  """
  @callback transition(
              Spex.InstanceManager.Instance.instance_identifier(),
              Spex.action(),
              Spex.state()
            ) :: :ok | Spex.Specification.error_handler_return()

  @doc """
  Same as `transition/3`, but raises on errors.
  """
  @callback transition!(
              Spex.InstanceManager.Instance.instance_identifier(),
              Spex.action(),
              Spex.state()
            ) :: :ok

  @doc """
  Asynchronously records a transition for an existing instance.
  """
  @callback transition_async(
              Spex.InstanceManager.Instance.instance_identifier(),
              Spex.action(),
              Spex.state()
            ) :: :ok

  @doc """
  Fetches one instance by identifier.
  """
  @callback get_instance(Spex.InstanceManager.Instance.instance_identifier()) ::
              {:ok, Spex.InstanceManager.Instance.t()}
              | {:error, Spex.Errors.InstanceError.t()}
              | {:error, Spex.Errors.DetsError.t()}

  @doc """
  Returns all instances managed by this instance manager.
  """
  @callback all_instances ::
              {:ok, [Spex.InstanceManager.Instance.t()]} | {:error, Spex.Errors.DetsError.t()}

  @doc """
  Returns all instances for a given specification module.
  """
  @callback all_instances(Spex.Specification.t()) ::
              {:ok, [Spex.InstanceManager.Instance.t()]} | {:error, Spex.Errors.DetsError.t()}

  @doc """
  Deletes one instance by identifier.
  """
  @callback delete_instance(Spex.InstanceManager.Instance.instance_identifier()) ::
              :ok | {:error, Spex.Errors.DetsError.t()}

  @doc """
  Deletes all instances matching the provided filter function.
  """
  @callback delete_instances((Spex.InstanceManager.Instance.t() -> as_boolean(term()))) ::
              :ok | {:error, Spex.Errors.DetsError.t()}

  @doc """
  Returns all currently known implementation models.
  """
  @callback all_impl_models :: {:ok, [Spex.ImplModel.t()]}

  @doc """
  Serialises and exports implementation models as `{filename, content}` tuples.
  """
  @callback export_impl_models ::
              {:ok, [{filename :: String.t(), Spex.ImplModel.serialisation()}]}

  @doc """
  Inserts or updates a mock instance at a given state for testing purposes.
  """
  @callback mock_instance!(
              Spex.Specification.t(),
              Spex.InstanceManager.Instance.instance_identifier(),
              Spex.state(),
              Spex.InstanceManager.Instance.meta() | nil
            ) :: :ok

  @optional_callbacks init_instance_async: 4, transition_async: 3

  @doc """
  Injects the `Spex.InstanceManager` behaviour and shared convenience functions.

  Generated convenience functions:

  - `child_spec/1`
  - `init_instance!/4`
  - `transition!/3`
  """
  defmacro __using__(_) do
    quote do
      @behaviour unquote(__MODULE__)

      @doc "Callback implementation for `c:Spex.InstanceManager.child_spec/1`."
      @impl unquote(__MODULE__)
      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]}
        }
      end

      @doc "Callback implementation for `c:Spex.InstanceManager.init_instance!/4`."
      @impl unquote(__MODULE__)
      def init_instance!(spec, instance_identifier, meta \\ nil, initial_state \\ nil) do
        init_instance(spec, instance_identifier, meta, initial_state) |> __ok__!()
      end

      @doc "Callback implementation for `c:Spex.InstanceManager.transition!/3`."
      @impl unquote(__MODULE__)
      def transition!(instance_identifier, action, state) do
        transition(instance_identifier, action, state) |> __ok__!()
      end

      defp __ok__!(:ok), do: :ok
      defp __ok__!({:error, error}) when is_exception(error), do: raise(error)
      defp __ok__!({:error, error}), do: raise(RuntimeError, inspect(error))

      defoverridable unquote(__MODULE__)
    end
  end

  {instance_manager, instance_manager_opts} =
    case Application.compile_env(:spex, :instance_manager) do
      nil -> {Spex.InstanceManager.SimpleInstanceManager, []}
      module when is_atom(module) -> {module, []}
      {module, opts} when is_atom(module) and is_list(opts) -> {module, opts}
    end

  @doc """
  Returns the compile-time configured default instance manager module.
  """
  @spec default_instance_manager :: module()
  def default_instance_manager, do: unquote(instance_manager)

  @doc """
  Returns compile-time options for the default instance manager.
  """
  @spec default_instance_manager_opts :: keyword()
  def default_instance_manager_opts, do: unquote(instance_manager_opts)
end
