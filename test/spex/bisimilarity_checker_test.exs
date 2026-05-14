defmodule Spex.BisimilarityCheckerTest do
  use ExUnit.Case, async: true

  alias Spex.BisimilarityChecker
  alias Spex.ImplModel

  defmodule Specs.SingleStep do
    use Spex.Specification

    def_transition(:s0, :a, :s1)
  end

  describe "bisimilar_to_specification?/1" do
    test "returns true for a model that matches the specification" do
      impl_model = %ImplModel{
        specification: Specs.SingleStep,
        learning_mode?: false,
        transitions:
          MapSet.new([
            {nil, :__initialisation__, :s0},
            {:s0, :a, :s1}
          ])
      }

      assert BisimilarityChecker.bisimilar_to_specification?(impl_model)
    end

    test "returns true with an extra internal self-loop (branching bisimilar)" do
      impl_model = %ImplModel{
        specification: Specs.SingleStep,
        learning_mode?: false,
        transitions:
          MapSet.new([
            {nil, :__initialisation__, :s0},
            {:s0, :a, :s1},
            {:s0, :__internal__, :s0}
          ])
      }

      assert BisimilarityChecker.bisimilar_to_specification?(impl_model)
    end

    test "returns true with internal stuttering before observable action" do
      impl_model = %ImplModel{
        specification: Specs.SingleStep,
        learning_mode?: false,
        transitions:
          MapSet.new([
            {nil, :__initialisation__, :s0},
            {:s0, :__internal__, :s0_tau},
            {:s0_tau, :a, :s1}
          ])
      }

      assert BisimilarityChecker.bisimilar_to_specification?(impl_model)
    end

    test "returns false when no initialisation transition is present" do
      impl_model = %ImplModel{
        specification: Specs.SingleStep,
        learning_mode?: false,
        transitions: MapSet.new([{:s0, :a, :s1}])
      }

      refute BisimilarityChecker.bisimilar_to_specification?(impl_model)
    end

    test "returns false when multiple initialisation transitions are present" do
      impl_model = %ImplModel{
        specification: Specs.SingleStep,
        learning_mode?: false,
        transitions:
          MapSet.new([
            {nil, :__initialisation__, :s0},
            {nil, :__initialisation__, :s1},
            {:s0, :a, :s1}
          ])
      }

      refute BisimilarityChecker.bisimilar_to_specification?(impl_model)
    end

    test "returns false for an observable deviation that breaks bisimilarity" do
      impl_model = %ImplModel{
        specification: Specs.SingleStep,
        learning_mode?: false,
        transitions:
          MapSet.new([
            {nil, :__initialisation__, :s0},
            {:s0, :a, :s1},
            {:s0, :b, :s1}
          ])
      }

      refute BisimilarityChecker.bisimilar_to_specification?(impl_model)
    end
  end
end
