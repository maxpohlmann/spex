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

  Call this in your `test_helper.exs`.

  It accepts the following opts:

  - `:instance_manager`: An instance manager module. By default, it uses the configured default
    instance manager (see `m:Spex#module-using-other-instance-managers`). Specify this if you are
    starting your instance manager in your supervision tree directly.
  - `:impl_models_dir`: Path to the directory where collected implementation models are exported
    after tests. By default, this is the configured implementation models directory (see
    `m:Spex#module-configuration`).
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

  Use this in unit tests to setup an instance without affecting the impl_model.
  """
  defdelegate mock_instance!(spec, instance_identifier, state, meta \\ nil),
    to: @default_instance_manager
end
