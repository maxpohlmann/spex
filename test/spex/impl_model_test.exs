defmodule Spex.ImplModelTest do
  use ExUnit.Case, async: true

  alias Spex.ImplModel
  alias Spex.Errors.ImplModelError
  alias SpexTest.Specifications.Tree

  describe "initialise/1" do
    test "returns a model with empty transitions in learning mode" do
      impl_model = ImplModel.initialise(Tree)

      assert impl_model.specification == Tree
      assert impl_model.transitions == MapSet.new()
      assert impl_model.learning_mode? == true
    end
  end

  describe "observe_transition/2" do
    test "adds transition and returns :ok in learning mode" do
      impl_model = ImplModel.initialise(Tree)
      transition = {:s0, :a, :s1}

      assert {:ok, updated_model} = ImplModel.observe_transition(impl_model, transition)
      assert updated_model.learning_mode? == true
      assert MapSet.member?(updated_model.transitions, transition)
    end

    test "returns :ok and leaves model unchanged when transition already exists outside learning mode" do
      transition = {:s0, :a, :s1}

      impl_model = %ImplModel{
        specification: Tree,
        transitions: MapSet.new([transition]),
        learning_mode?: false
      }

      assert {:ok, ^impl_model} = ImplModel.observe_transition(impl_model, transition)
    end

    test "returns :deviation_still_bisimilar for reflexive internal transition outside learning mode" do
      impl_model = %ImplModel{
        specification: Tree,
        transitions:
          MapSet.new([{nil, :__initialisation__, Tree.initial_state()} | Tree.transitions()]),
        learning_mode?: false
      }

      transition = {:s0, :__internal__, :s0}

      assert {:deviation_still_bisimilar, ^impl_model} =
               ImplModel.observe_transition(impl_model, transition)
    end

    test "returns :deviation_not_bisimilar for breaking deviation outside learning mode" do
      impl_model = %ImplModel{
        specification: Tree,
        transitions:
          MapSet.new([{nil, :__initialisation__, Tree.initial_state()} | Tree.transitions()]),
        learning_mode?: false
      }

      transition = {:s0, :b, :s1}

      assert {:deviation_not_bisimilar, ^impl_model} =
               ImplModel.observe_transition(impl_model, transition)
    end
  end

  describe "serialise/1" do
    test "serialises specification, learning mode, and transitions" do
      impl_model = %ImplModel{
        specification: Tree,
        transitions: MapSet.new([{:s0, :a, :s1}]),
        learning_mode?: false
      }

      serialised = ImplModel.serialise(impl_model)

      assert serialised =~ "Specification: Elixir.SpexTest.Specifications.Tree"
      assert serialised =~ "Learning mode: false"
      assert serialised =~ "s0 --[a]-> s1"
    end
  end

  describe "deserialise/1" do
    test "deserialises valid serialised model" do
      serialised = """
      Specification: Elixir.SpexTest.Specifications.Tree
      Learning mode: false
      Transitions:
      s0 --[a]-> s1
      s1 --[b]-> s3
      """

      assert {:ok, impl_model} = ImplModel.deserialise(serialised)
      assert impl_model.specification == Tree
      assert impl_model.learning_mode? == false

      assert impl_model.transitions ==
               MapSet.new([
                 {:s0, :a, :s1},
                 {:s1, :b, :s3}
               ])
    end

    test "returns deserialisation_failed on malformed input" do
      assert {:error, %ImplModelError{} = error} = ImplModel.deserialise("invalid")
      assert error.reason == :deserialisation_failed
      assert is_map(error.context)
      assert Map.has_key?(error.context, :original_error)
    end
  end
end
