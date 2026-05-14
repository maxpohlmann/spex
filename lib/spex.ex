defmodule Spex do
  @moduledoc """
  Entry point for Spex runtime APIs and high-level integration.

  Spex tracks observed runtime behaviour as implementation models and compares
  those models to declarative specifications (LTSs). It is designed for:

  - online runtime observation (`init_instance*`, `transition*`),
  - detection/reporting of behavioural deviations,
  - export and offline checking of derived implementation models.

  ## Quick Start

  1. Define one or more specifications with `Spex.Specification`.
  2. Start Spex (or an instance manager) under a supervisor.
  3. Initialize instances with `init_instance/4`.
  4. Feed observed transitions with `transition/3`.

  Minimal usage example:

      :ok = Spex.init_instance(MySpec, :order_123)
      :ok = Spex.transition(:order_123, :pay, :paid)
      :ok = Spex.transition(:order_123, :ship, :shipped)

  ## How To Start Spex

  There are two primary integration styles.

  ### 1) Spex As Its Own OTP Application

  This is the usual setup when the dependency is started normally
  (`runtime: true`, default). Your app depends on Spex and Spex boots its own
  supervision tree.

  ### 2) Explicit Supervision (`runtime: false`)

  If Spex is configured with `runtime: false`, add either `Spex` or a concrete
  instance manager directly to your supervision tree:

      children = [
        Spex
      ]

  or:

      children = [
        {Spex.InstanceManager.SimpleInstanceManager,
         impl_models_dir: "./spex_impl_models",
         dets_dir: "./spex_dets"}
      ]

  or:

      children = [
        {Spex.InstanceManager.DistributedInstanceManager,
         distribution_factor: 8,
         impl_models_dir: "./spex_impl_models",
         dets_dir: "./spex_dets"}
      ]

  ## Online Production Usage

  In production, call `init_instance/4` when a domain entity begins its tracked
  lifecycle, then call `transition/3` for each observed state change.

  Behavioural checks and error handling are driven by the underlying
  specification (`error_handler/2`, timeout settings, pruning rules).

  ## ImplModel Derivation During Tests

  Spex can derive implementation models from test execution and persist them as
  `.spex` files. The main purpose of this derivation flow is to run offline
  bisimilarity checks with the `mix spex` task.

  Typical flow:

  - call `Spex.Testing.prepare_for_test_suite/1` in test setup,
  - run tests while using normal Spex APIs,
  - after suite completion, derived models are exported,
  - run `mix spex` (or `mix spex <path>`) to validate derived models.

  Example:

      # test/test_helper.exs
      Spex.Testing.prepare_for_test_suite(impl_models_dir: "./test_meta/impl_models/live")

      # CI or local verification
      # Uses configured :impl_models_dir when no path is given
      mix spex

  ## Configuration Entry Point

  This module delegates to a compile-time default instance manager selected via
  `config :spex, :instance_manager`.

  Accepted forms are:

  - `MyManagerModule`
  - `{MyManagerModule, manager_opts}`

  ## Documentation Map

  - `Spex.Specification`: define specifications and options.
  - `Spex.InstanceManager`: behaviour contract for manager implementations.
  - `Spex.InstanceManager.SimpleInstanceManager`: single-node manager setup.
  - `Spex.InstanceManager.DistributedInstanceManager`: sharded manager setup.
  - `Spex.Testing`: test helpers and suite-level model export.
  - `Spex.ImplModel` / `Spex.ImplModelStore`: model representation and storage.
  - `Spex.BisimilarityChecker`: bisimilarity validation internals.
  - `Mix.Tasks.Spex`: offline bisimilarity checks over saved `.spex` files.
  """

  @typedoc """
  State label used in specifications and runtime observations.
  """
  @type state :: atom()

  @typedoc """
  Action label on transitions.

  Conventional reserved actions used internally by Spex are:

  - `:__internal__` for unobservable/internal steps,
  - `:__initialisation__` for synthetic instance initialization transitions.
  """
  @type action :: atom()

  @typedoc """
  A labelled transition tuple `{from_state, action, to_state}`.
  """
  @type transition :: {from_state :: state(), action :: action(), to_state :: state()}

  # By default, this is: Spex.InstanceManager.SimpleInstanceManager and []
  @instance_manager Spex.InstanceManager.default_instance_manager()
  @instance_manager_opts Spex.InstanceManager.default_instance_manager_opts()

  Code.ensure_compiled!(@instance_manager)

  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(_opts) do
    @instance_manager.child_spec(@instance_manager_opts)
  end

  defdelegate init_instance(spec, instance_identifier, meta \\ nil, initial_state \\ nil),
    to: @instance_manager

  defdelegate init_instance!(spec, instance_identifier, meta \\ nil, initial_state \\ nil),
    to: @instance_manager

  if function_exported?(@instance_manager, :init_instance_async, 4) do
    defdelegate init_instance_async(spec, instance_identifier, meta \\ nil, initial_state \\ nil),
      to: @instance_manager
  end

  defdelegate transition(instance_identifier, action, state),
    to: @instance_manager

  defdelegate transition!(instance_identifier, action, state),
    to: @instance_manager

  if function_exported?(@instance_manager, :transition_async, 3) do
    defdelegate transition_async(instance_identifier, action, state),
      to: @instance_manager
  end

  defdelegate export_impl_models, to: @instance_manager
end
