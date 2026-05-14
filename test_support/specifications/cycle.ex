defmodule SpexTest.Specifications.Cycle do
  @moduledoc """
  A specification that forms a small, simple cycle structure:

               s0
              /  ↑
            a/    |
            /      |c
           ↓        |
          s1 --b--→ s2

  """
  use Spex.Specification,
    transition_timeout: 100

  def_transition :s0, :a, :s1
  def_transition :s1, :b, :s2
  def_transition :s2, :c, :s0

  @impl Spex.Specification
  def error_handler(error, caller)

  # For these test cases, the instances have been prepared for this to work, since the caller is the
  # instance manager server itself for these errors
  def error_handler(
        %Spex.Errors.TransitionError{
          reason: :transition_timeout,
          context: %{instance: %Spex.InstanceManager.Instance{meta: %{test_pid: test_pid}}}
        } = error,
        _caller
      ) do
    send(test_pid, {:from_error_handler, error})

    {:error, error}
  end

  def error_handler(%Spex.Errors.TransitionError{reason: :transition_timeout} = error, _caller) do
    {:error, error}
  end

  def error_handler(error, caller) do
    send(caller, {:from_error_handler, error})

    {:error, error}
  end
end
