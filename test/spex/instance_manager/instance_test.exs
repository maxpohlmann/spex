defmodule Spex.InstanceManager.InstanceTest do
  use ExUnit.Case, async: true

  alias Spex.InstanceManager.Instance

  defmodule Specifications.FiniteTransitionTimeout do
    use Spex.Specification,
      transition_timeout: 100

    def_transition :s0, :a, :s1
  end

  defmodule Specifications.InfiniteTransitionTimeout do
    use Spex.Specification

    def_transition :s0, :a, :s1
  end

  defmodule Specifications.AllPrunable do
    use Spex.Specification,
      prune_timeout: 100,
      prunable_states: :all

    def_transition :s0, :a, :s1
  end

  defmodule Specifications.NeverPrunable do
    use Spex.Specification,
      prune_timeout: 100,
      prunable_states: []

    def_transition :s0, :a, :s1
  end

  defmodule Specifications.TerminalPrunable do
    use Spex.Specification,
      prune_timeout: 100,
      prunable_states: :terminal

    def_transition :s0, :a, :s1
  end

  defmodule Specifications.ListPrunable do
    use Spex.Specification,
      prune_timeout: 100,
      prunable_states: [:done]

    def_transition :s0, :a, :done
    def_transition :s0, :b, :in_progress
  end

  describe "initialise/3" do
    test "builds a new instance with default state and no transitions" do
      meta = %{source: :test}

      instance = Instance.initialise(Specifications.FiniteTransitionTimeout, :id_1, meta)

      assert instance.specification == Specifications.FiniteTransitionTimeout
      assert instance.identifier == :id_1
      assert instance.meta == meta
      assert instance.current_state == nil
      assert instance.transitions == []
    end
  end

  describe "observe_transition/3" do
    test "updates current_state and prepends a transition record with current timestamp" do
      before = DateTime.utc_now()

      instance =
        %Instance{
          specification: Specifications.FiniteTransitionTimeout,
          identifier: :id_1,
          meta: nil,
          current_state: :s0,
          transitions: [{:old, :s0, DateTime.add(before, -10, :second)}]
        }

      updated_instance = Instance.observe_transition(instance, :a, :s1)

      assert updated_instance.current_state == :s1
      assert [{:a, :s1, ts}, {:old, :s0, _old_ts}] = updated_instance.transitions
      assert DateTime.compare(ts, before) in [:eq, :gt]
      assert DateTime.compare(ts, DateTime.utc_now()) in [:eq, :lt]
    end
  end

  describe "beyond_transition_timeout?/2" do
    test "returns false when no transitions have been observed" do
      instance = Instance.initialise(Specifications.FiniteTransitionTimeout, :id_1, nil)

      refute Instance.beyond_transition_timeout?(instance, DateTime.utc_now())
    end

    test "returns true when elapsed time is strictly greater than timeout" do
      now = DateTime.utc_now()

      instance =
        instance_with_last_transition(
          Specifications.FiniteTransitionTimeout,
          :s1,
          DateTime.add(now, -101, :millisecond)
        )

      assert Instance.beyond_transition_timeout?(instance, now)
    end

    test "returns false when elapsed time equals timeout" do
      now = DateTime.utc_now()

      instance =
        instance_with_last_transition(
          Specifications.FiniteTransitionTimeout,
          :s1,
          DateTime.add(now, -100, :millisecond)
        )

      refute Instance.beyond_transition_timeout?(instance, now)
    end

    test "returns false for specifications with infinite transition timeout" do
      now = DateTime.utc_now()

      instance =
        instance_with_last_transition(
          Specifications.InfiniteTransitionTimeout,
          :s1,
          DateTime.add(now, -24, :hour)
        )

      refute Instance.beyond_transition_timeout?(instance, now)
    end

    test "uses DateTime.utc_now/0 when no reference time is provided" do
      instance =
        instance_with_last_transition(
          Specifications.FiniteTransitionTimeout,
          :s1,
          DateTime.add(DateTime.utc_now(), -1, :second)
        )

      assert Instance.beyond_transition_timeout?(instance)
    end
  end

  describe "prunable?/1" do
    test "returns false when no transitions have been observed" do
      instance = Instance.initialise(Specifications.AllPrunable, :id_1, nil)

      refute Instance.prunable?(instance)
    end

    test "returns true for :all prunable states when beyond prune timeout" do
      instance =
        instance_with_last_transition(
          Specifications.AllPrunable,
          :s1,
          DateTime.add(DateTime.utc_now(), -1, :second)
        )

      assert Instance.prunable?(instance)
    end

    test "returns false when not beyond prune timeout" do
      instance =
        instance_with_last_transition(
          Specifications.AllPrunable,
          :s1,
          DateTime.utc_now()
        )

      refute Instance.prunable?(instance)
    end

    test "returns false for NeverPrunable specification" do
      instance =
        instance_with_last_transition(
          Specifications.NeverPrunable,
          :s1,
          DateTime.add(DateTime.utc_now(), -1, :second)
        )

      refute Instance.prunable?(instance)
    end

    test "returns true for :terminal when current state is terminal" do
      instance =
        instance_with_last_transition(
          Specifications.TerminalPrunable,
          :s1,
          DateTime.add(DateTime.utc_now(), -1, :second)
        )

      assert Instance.prunable?(instance)
    end

    test "returns false for :terminal when current state is not terminal" do
      instance =
        instance_with_last_transition(
          Specifications.TerminalPrunable,
          :s0,
          DateTime.add(DateTime.utc_now(), -1, :second)
        )

      refute Instance.prunable?(instance)
    end

    test "returns true when current state is explicitly listed as prunable" do
      prunable_instance =
        instance_with_last_transition(
          Specifications.ListPrunable,
          :done,
          DateTime.add(DateTime.utc_now(), -1, :second)
        )

      assert Instance.prunable?(prunable_instance)
    end

    test "returns false when current state is not in explicit prunable list" do
      non_prunable_instance =
        instance_with_last_transition(
          Specifications.ListPrunable,
          :in_progress,
          DateTime.add(DateTime.utc_now(), -1, :second)
        )

      refute Instance.prunable?(non_prunable_instance)
    end
  end

  @spec instance_with_last_transition(Spex.Specification.t(), Spex.state(), DateTime.t()) ::
          Instance.t()
  defp instance_with_last_transition(specification, current_state, last_transition_timestamp) do
    %Instance{
      specification: specification,
      identifier: :id_1,
      meta: nil,
      current_state: current_state,
      transitions: [{:a, current_state, last_transition_timestamp}]
    }
  end
end
