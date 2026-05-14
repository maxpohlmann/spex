defmodule Spex.Testing do
  @moduledoc """
  Test helpers for preparing and manipulating Spex runtime state.
  """

  # By default, this is: Spex.InstanceManager.SimpleInstanceManager
  @default_instance_manager Spex.InstanceManager.default_instance_manager()

  @type opt ::
          {:instance_manager, module()}
          | {:impl_models_dir, Path.t()}

  @doc """
  Prepares after-suite hooks that export collected implementation models.
  """
  @spec prepare_for_test_suite([opt()]) :: :ok
  def prepare_for_test_suite(opts \\ []) do
    instance_manager = Keyword.get(opts, :instance_manager, @default_instance_manager)

    impl_models_dir =
      Keyword.get(opts, :impl_models_dir) ||
        Application.get_env(:spex, :impl_models_dir) ||
        raise(
          ArgumentError,
          "Missing required option :impl_models_dir. Please provide it as an argument or " <>
            "configure it in the application environment; see the `Spex` moduledoc for details."
        )

    ExUnit.after_suite(fn _ ->
      {:ok, impl_models} = instance_manager.all_impl_models()
      impl_models = Enum.map(impl_models, &%{&1 | learning_mode?: false})
      :ok = Spex.ImplModelStore.save(impl_models, impl_models_dir)
    end)
  end

  @doc """
  Inserts or updates a mock instance at a specific state for test setup.
  """
  defdelegate mock_instance!(spec, instance_identifier, state, meta \\ nil),
    to: @default_instance_manager
end
