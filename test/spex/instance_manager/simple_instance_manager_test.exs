defmodule Spex.InstanceManager.SimpleInstanceManagerTest do
  use ExUnit.Case, async: true

  alias SpexTest.Specifications.Tree
  alias SpexTest.Specifications.Arrow
  alias SpexTest.Specifications.Point
  alias SpexTest.Specifications.Cycle
  alias Spex.InstanceManager.SimpleInstanceManager

  import ExUnit.CaptureLog

  # This is the default instance manager and is started by default

  describe "init_instance/4" do
    test "returns :ok when initialising a valid new instance and stores instance correctly" do
      identifier = random_identifier(Tree)
      meta = %{foo: :bar}

      assert SimpleInstanceManager.init_instance(Tree, identifier, meta) == :ok
      refute_receive {:from_error_handler, _error}

      assert {:ok, instance} = SimpleInstanceManager.get_instance(identifier)
      assert instance.specification == Tree
      assert instance.identifier == identifier
      assert instance.meta == meta
      # :s0 is the initial state of the Tree specification
      assert instance.current_state == :s0
      assert [{:__initialisation__, :s0, _timestamp}] = instance.transitions
    end

    test "returns error when initialising an instance that already exists" do
      identifier = random_identifier(Tree)

      :ok = SimpleInstanceManager.mock_instance!(Tree, identifier, :s0)

      assert {:error, error} = SimpleInstanceManager.init_instance(Tree, identifier)
      assert is_struct(error, Spex.Errors.InstanceError)
      assert error.reason == :instance_identifier_already_in_use
      assert error.context.instance_identifier == identifier

      assert_receive {:from_error_handler, ^error}
    end

    test "returns error when initialising in a non-initial state" do
      identifier = random_identifier(Tree)

      assert {:error, error} = SimpleInstanceManager.init_instance(Tree, identifier, nil, :s2)
      assert is_struct(error, Spex.Errors.TransitionError)
      assert error.reason == :deviation_not_bisimilar
      assert error.context.instance.identifier == identifier
      assert error.context.instance.current_state == :s2
      assert error.context.deviating_transition == {nil, :__initialisation__, :s2}

      assert_receive {:from_error_handler, ^error}
    end

    test "calls error_handler when initialising an instance of a specification for which no impl_model yet exists - returns error" do
      identifier = random_identifier(Arrow)
      assert {:error, error} = SimpleInstanceManager.init_instance(Arrow, identifier)
      assert is_struct(error, Spex.Errors.ImplModelError)
      assert error.reason == :impl_model_not_found
      assert error.context == nil

      assert_receive {:from_error_handler, ^error}

      {:ok, impl_models} = SimpleInstanceManager.all_impl_models()
      refute Enum.any?(impl_models, &(&1.specification == Arrow))
    end

    test "calls error_handler when initialising an instance of a specification for which no impl_model yet exists - returns ok" do
      identifier = random_identifier(Point)

      # See Point.error_handler/2
      assert SimpleInstanceManager.init_instance(Point, identifier) == :ok

      assert_receive {:from_error_handler, error}
      assert is_struct(error, Spex.Errors.ImplModelError)
      assert error.reason == :impl_model_not_found
      assert error.context == nil

      {:ok, impl_models} = SimpleInstanceManager.all_impl_models()
      point_impl_model = Enum.find(impl_models, &(&1.specification == Point))
      assert point_impl_model.transitions == MapSet.new([{nil, :__initialisation__, :s0}])
      assert point_impl_model.learning_mode? == true
    end

    test "calls error_handler when no transition after timeout" do
      identifier = random_identifier(Cycle)
      # See Cycle.handle_error/2
      meta = %{test_pid: self()}

      assert SimpleInstanceManager.init_instance(Cycle, identifier, meta, :x0) == :ok

      # Cycle.transition_timeout() == 50
      refute_receive {:from_error_handler, _error}, 40
      assert_receive {:from_error_handler, error}, 60
      assert error.reason == :transition_timeout
      assert error.context.instance.identifier == identifier
    end
  end

  describe "init_instance!/4" do
    test "returns :ok when all is well" do
      identifier = random_identifier(Tree)
      assert SimpleInstanceManager.init_instance!(Tree, identifier) == :ok
      refute_receive {:from_error_handler, _error}
      assert {:ok, _instance} = SimpleInstanceManager.get_instance(identifier)
    end

    test "raises when initialising an instance that already exists" do
      identifier = random_identifier(Tree)

      :ok = SimpleInstanceManager.mock_instance!(Tree, identifier, :s0)

      assert_raise Spex.Errors.InstanceError, ~r/instance_identifier_already_in_use/, fn ->
        SimpleInstanceManager.init_instance!(Tree, identifier)
      end
    end
  end

  describe "init_instance_async/4" do
    test "returns :ok when all is well" do
      identifier = random_identifier(Tree)
      assert SimpleInstanceManager.init_instance_async(Tree, identifier) == :ok
      refute_receive {:from_error_handler, _error}
      assert {:ok, _instance} = SimpleInstanceManager.get_instance(identifier)
    end

    test "sends message to caller when initialising an instance that already exists" do
      identifier = random_identifier(Tree)

      :ok = SimpleInstanceManager.mock_instance!(Tree, identifier, :s0)

      assert SimpleInstanceManager.init_instance_async(Tree, identifier) == :ok

      assert_receive {:from_error_handler, error}
      assert is_struct(error, Spex.Errors.InstanceError)
      assert error.reason == :instance_identifier_already_in_use
      assert error.context.instance_identifier == identifier
    end
  end

  describe "transition/3" do
    test "records valid transition" do
      identifier = random_identifier(Tree)
      :ok = SimpleInstanceManager.mock_instance!(Tree, identifier, :s0)

      assert SimpleInstanceManager.transition(identifier, :a, :s1) == :ok
      refute_receive {:from_error_handler, _error}

      assert {:ok, instance} = SimpleInstanceManager.get_instance(identifier)
      assert instance.current_state == :s1
      assert [{:a, :s1, _timestamp}] = instance.transitions

      {:ok, impl_models} = SimpleInstanceManager.all_impl_models()
      tree_impl_model = Enum.find(impl_models, &(&1.specification == Tree))
      assert tree_impl_model.learning_mode? == false
      assert Enum.count(tree_impl_model.transitions) == 5
    end

    test "returns error when instance_identifier is unknown" do
      identifier = random_identifier(Tree)

      log =
        capture_log(fn ->
          assert {:error, error} = SimpleInstanceManager.transition(identifier, :a, :s1)
          assert is_struct(error, Spex.Errors.InstanceError)
          assert error.reason == :instance_identifier_not_found
          assert error.context.instance_identifier == identifier
        end)

      assert log =~
               "[Spex] Error: %Spex.Errors.InstanceError{" <>
                 "reason: :instance_identifier_not_found, " <>
                 "context: %{instance_identifier: #{inspect(identifier)}}}"

      assert {:error, error} = SimpleInstanceManager.get_instance(identifier)
      assert is_struct(error, Spex.Errors.InstanceError)
      assert error.reason == :instance_identifier_not_found
      assert error.context.instance_identifier == identifier
    end

    test "returns error on deviating transition (still bisimilar)" do
      identifier = random_identifier(Tree)
      :ok = SimpleInstanceManager.mock_instance!(Tree, identifier, :s0)

      # reflexive internal transition makes the resulting impl_model still bisimilar
      assert {:error, error} = SimpleInstanceManager.transition(identifier, :__internal__, :s0)
      assert is_struct(error, Spex.Errors.TransitionError)
      assert error.reason == :deviation_still_bisimilar
      assert error.context.instance.identifier == identifier
      assert error.context.deviating_transition == {:s0, :__internal__, :s0}

      assert_receive {:from_error_handler, ^error}

      assert {:ok, instance} = SimpleInstanceManager.get_instance(identifier)
      assert instance.current_state == :s0
      assert [{:__internal__, :s0, _timestamp}] = instance.transitions

      {:ok, impl_models} = SimpleInstanceManager.all_impl_models()
      tree_impl_model = Enum.find(impl_models, &(&1.specification == Tree))
      assert tree_impl_model.learning_mode? == false
      assert Enum.count(tree_impl_model.transitions) == 5
      assert {:s0, :__internal__, :s0} not in tree_impl_model.transitions
    end

    test "returns error on deviating transition (not bisimilar)" do
      identifier = random_identifier(Tree)
      :ok = SimpleInstanceManager.mock_instance!(Tree, identifier, :s0)

      # this transition breaks the specification
      assert {:error, error} = SimpleInstanceManager.transition(identifier, :b, :s1)
      assert is_struct(error, Spex.Errors.TransitionError)
      assert error.reason == :deviation_not_bisimilar
      assert error.context.instance.identifier == identifier
      assert error.context.deviating_transition == {:s0, :b, :s1}

      assert_receive {:from_error_handler, ^error}

      assert {:ok, instance} = SimpleInstanceManager.get_instance(identifier)
      assert instance.current_state == :s1
      assert [{:b, :s1, _timestamp}] = instance.transitions

      {:ok, impl_models} = SimpleInstanceManager.all_impl_models()
      tree_impl_model = Enum.find(impl_models, &(&1.specification == Tree))
      assert tree_impl_model.learning_mode? == false
      assert Enum.count(tree_impl_model.transitions) == 5
      assert {:s0, :b, :s1} not in tree_impl_model.transitions
    end

    test "records (deviating) transition when impl_model is in learning mode" do
      identifier = random_identifier(Cycle)
      :ok = SimpleInstanceManager.mock_instance!(Cycle, identifier, :x0)

      assert SimpleInstanceManager.transition(identifier, :a, :x3) == :ok
      refute_receive {:from_error_handler, _error}

      assert {:ok, instance} = SimpleInstanceManager.get_instance(identifier)
      assert instance.current_state == :x3
      assert [{:a, :x3, _timestamp}] = instance.transitions

      {:ok, impl_models} = SimpleInstanceManager.all_impl_models()
      point_impl_model = Enum.find(impl_models, &(&1.specification == Cycle))
      assert point_impl_model.learning_mode? == true
      assert {:x0, :a, :x3} in point_impl_model.transitions
    end

    test "calls error_handler when no transition after timeout" do
      identifier = random_identifier(Cycle)
      # See Cycle.handle_error/2
      meta = %{test_pid: self()}
      :ok = SimpleInstanceManager.mock_instance!(Cycle, identifier, :x0, meta)

      assert SimpleInstanceManager.transition(identifier, :a, :x1) == :ok

      # Cycle.transition_timeout() == 50
      refute_receive {:from_error_handler, _error}, 40
      assert_receive {:from_error_handler, error}, 60
      assert error.reason == :transition_timeout
      assert error.context.instance.identifier == identifier
    end
  end

  describe "transition!/3" do
    test "returns :ok when all is well" do
      identifier = random_identifier(Tree)
      :ok = SimpleInstanceManager.mock_instance!(Tree, identifier, :s0)

      assert SimpleInstanceManager.transition!(identifier, :a, :s1) == :ok
      refute_receive {:from_error_handler, _error}
      assert {:ok, instance} = SimpleInstanceManager.get_instance(identifier)
      assert instance.current_state == :s1
    end

    test "raises on deviating transition" do
      identifier = random_identifier(Tree)
      :ok = SimpleInstanceManager.mock_instance!(Tree, identifier, :s0)

      assert_raise Spex.Errors.TransitionError, ~r/deviation_not_bisimilar/, fn ->
        SimpleInstanceManager.transition!(identifier, :b, :s1)
      end
    end
  end

  describe "transition_async/3" do
    test "returns :ok when all is well" do
      identifier = random_identifier(Tree)
      :ok = SimpleInstanceManager.mock_instance!(Tree, identifier, :s0)

      assert SimpleInstanceManager.transition_async(identifier, :a, :s1) == :ok
      refute_receive {:from_error_handler, _error}
      assert {:ok, instance} = SimpleInstanceManager.get_instance(identifier)
      assert instance.current_state == :s1
    end

    test "sends message to caller on deviating transition" do
      identifier = random_identifier(Tree)
      :ok = SimpleInstanceManager.mock_instance!(Tree, identifier, :s0)

      assert SimpleInstanceManager.transition_async(identifier, :b, :s1) == :ok

      assert_receive {:from_error_handler, error}
      assert is_struct(error, Spex.Errors.TransitionError)
      assert error.reason == :deviation_not_bisimilar
      assert error.context.instance.identifier == identifier
      assert error.context.deviating_transition == {:s0, :b, :s1}
    end
  end

  describe "get_instance/1" do
    test "returns {:ok, instance} when instance exists" do
      identifier = random_identifier(Tree)
      :ok = SimpleInstanceManager.mock_instance!(Tree, identifier, :s0)

      assert {:ok, instance} = SimpleInstanceManager.get_instance(identifier)
      assert instance.identifier == identifier
    end

    test "returns {:error, error} when instance_identifier is unknown" do
      identifier = random_identifier(Tree)

      assert {:error, error} = SimpleInstanceManager.get_instance(identifier)
      assert is_struct(error, Spex.Errors.InstanceError)
      assert error.reason == :instance_identifier_not_found
      assert error.context.instance_identifier == identifier
    end
  end

  describe "all_instances/0" do
    test "returns all instances" do
      identifier1 = random_identifier(Tree)
      identifier2 = random_identifier(Tree)

      :ok = SimpleInstanceManager.mock_instance!(Tree, identifier1, :s0)
      :ok = SimpleInstanceManager.mock_instance!(Tree, identifier2, :s0)

      assert {:ok, instances} = SimpleInstanceManager.all_instances()
      assert Enum.any?(instances, &(&1.identifier == identifier1))
      assert Enum.any?(instances, &(&1.identifier == identifier2))
    end
  end

  describe "all_instances/1" do
    test "returns instances of the given specification" do
      identifier1 = random_identifier(Tree)
      identifier2 = random_identifier(Arrow)

      :ok = SimpleInstanceManager.mock_instance!(Tree, identifier1, :s0)
      :ok = SimpleInstanceManager.mock_instance!(Arrow, identifier2, :s0)

      assert {:ok, tree_instances} = SimpleInstanceManager.all_instances(Tree)
      assert Enum.any?(tree_instances, &(&1.identifier == identifier1))
      refute Enum.any?(tree_instances, &(&1.identifier == identifier2))

      assert {:ok, arrow_instances} = SimpleInstanceManager.all_instances(Arrow)
      assert Enum.any?(arrow_instances, &(&1.identifier == identifier2))
      refute Enum.any?(arrow_instances, &(&1.identifier == identifier1))
    end
  end

  describe "delete_instance/1" do
    test "deletes the instance with the given identifier" do
      identifier = random_identifier(Tree)
      :ok = SimpleInstanceManager.mock_instance!(Tree, identifier, :s0)

      assert SimpleInstanceManager.delete_instance(identifier) == :ok
      assert {:error, error} = SimpleInstanceManager.get_instance(identifier)
      assert is_struct(error, Spex.Errors.InstanceError)
      assert error.reason == :instance_identifier_not_found
      assert error.context.instance_identifier == identifier
    end

    test "returns :ok even when instance didn't exist" do
      identifier = random_identifier(Tree)
      assert SimpleInstanceManager.delete_instance(identifier) == :ok
    end
  end

  describe "delete_instances/1" do
    test "deletes instances matching the filter function" do
      identifier1 = random_identifier(Tree)
      identifier2 = random_identifier(Tree)

      :ok = SimpleInstanceManager.mock_instance!(Tree, identifier1, :s0, %{foo: :bar})
      :ok = SimpleInstanceManager.mock_instance!(Tree, identifier2, :s0, %{foo: :baz})

      filter_fun = fn instance -> instance.meta[:foo] == :bar end

      assert SimpleInstanceManager.delete_instances(filter_fun) == :ok

      assert {:error, error} = SimpleInstanceManager.get_instance(identifier1)
      assert is_struct(error, Spex.Errors.InstanceError)
      assert error.reason == :instance_identifier_not_found
      assert error.context.instance_identifier == identifier1

      assert {:ok, _instance} = SimpleInstanceManager.get_instance(identifier2)
    end

    test "can delete all instances" do
      identifier1 = random_identifier(Tree)
      identifier2 = random_identifier(Arrow)

      :ok = SimpleInstanceManager.mock_instance!(Tree, identifier1, :s0)
      :ok = SimpleInstanceManager.mock_instance!(Arrow, identifier2, :s0)

      assert SimpleInstanceManager.delete_instances(fn _instance -> true end) == :ok

      assert SimpleInstanceManager.all_instances() == {:ok, []}
    end
  end

  describe "all_impl_models/0" do
    test "returns all impl_models" do
      assert {:ok, impl_models} = SimpleInstanceManager.all_impl_models()

      # The Point ImplModel may or may not be in there, depending on whether the test above ran yet
      assert length(impl_models) >= 2

      specifications = Enum.map(impl_models, & &1.specification)
      assert Cycle in specifications
      assert Tree in specifications
    end
  end

  describe "export_impl_models/0" do
    test "returns serialised impl_models" do
      assert {:ok, exports} = SimpleInstanceManager.export_impl_models()
      assert length(exports) >= 2

      for {filename, serialisation} <- exports do
        assert String.starts_with?(filename, "Elixir.SpexTest.Specifications.")
        assert String.ends_with?(filename, ".spex")
        assert serialisation =~ "Specification:"
      end
    end
  end

  describe "mock_instance/1" do
    test "stores the given instance directly, bypassing all checks and impl_model updating" do
      identifier = random_identifier(Tree)
      meta = %{foo: :bar}

      assert SimpleInstanceManager.mock_instance!(Tree, identifier, :xxx, meta) == :ok
      refute_receive {:from_error_handler, _error}

      assert {:ok, retrieved_instance} = SimpleInstanceManager.get_instance(identifier)
      assert retrieved_instance.identifier == identifier
      assert retrieved_instance.meta == meta

      {:ok, impl_models} = SimpleInstanceManager.all_impl_models()
      tree_impl_model = Enum.find(impl_models, &(&1.specification == Tree))

      for {from_state, _action, to_state} <- tree_impl_model.transitions do
        refute from_state == :xxx
        refute to_state == :xxx
      end
    end
  end

  @spec random_identifier(Spex.Specification.t()) ::
          Spex.InstanceManager.Instance.instance_identifier()
  defp random_identifier(spec), do: {spec, :rand.uniform()}
end
