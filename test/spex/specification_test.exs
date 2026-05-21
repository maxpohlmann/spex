defmodule Spex.SpecificationTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  defmodule DefaultSpec do
    use Spex.Specification
  end

  defmodule ConfiguredSpec do
    use Spex.Specification,
      transition_timeout: 150,
      prune_timeout: %Duration{minute: 2},
      prunable_states: [:done, :failed]

    def_transition :idle, :start, :running
    def_transition :running, :finish, :done
    def_transition :running, :fail, :failed
    def_transition :done, :restart, :running
    def_transition :running, :fail, :failed

    @impl Spex.Specification
    def error_handler(_error, _caller) do
      :ok
    end
  end

  describe "default generated functions" do
    test "returns default option values" do
      assert DefaultSpec.transition_timeout() == :infinity
      assert DefaultSpec.prune_timeout() == :infinity
      assert DefaultSpec.prunable_states() == []
    end

    test "returns empty graph-derived values when no transitions are defined" do
      assert DefaultSpec.states() == []
      assert DefaultSpec.actions() == []
      assert DefaultSpec.transitions() == []
      assert DefaultSpec.initial_state() == nil
      assert DefaultSpec.terminal_states() == []
    end

    test "default error handler writes log and returns error" do
      error = %Spex.Errors.TransitionError{reason: :deviation_not_equivalent}

      log =
        capture_log(fn ->
          assert DefaultSpec.error_handler(error, self()) == {:error, error}
        end)

      assert log =~ "[Spex] Error"
      assert log =~ "TransitionError"
      assert log =~ "deviation_not_equivalent"
    end
  end

  describe "configured generated functions" do
    test "returns explicitly configured option values" do
      assert ConfiguredSpec.transition_timeout() == 150
      assert ConfiguredSpec.prune_timeout() == %Duration{minute: 2} |> to_timeout()
      assert ConfiguredSpec.prunable_states() == [:done, :failed]
    end

    test "returns computed graph values from transitions" do
      assert ConfiguredSpec.states() == [:idle, :running, :done, :failed]
      assert ConfiguredSpec.actions() == [:start, :finish, :fail, :restart]

      assert ConfiguredSpec.transitions() == [
               {:idle, :start, :running},
               {:running, :finish, :done},
               {:running, :fail, :failed},
               {:done, :restart, :running}
             ]

      assert ConfiguredSpec.initial_state() == :idle
      assert ConfiguredSpec.terminal_states() == [:failed]
    end

    test "error handler does not write log and returns :ok" do
      error = %Spex.Errors.TransitionError{reason: :deviation_not_equivalent}

      log =
        capture_log(fn ->
          assert ConfiguredSpec.error_handler(error, self()) == :ok
        end)

      refute log =~ "[Spex] Error"
    end
  end
end
