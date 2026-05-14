defmodule SpexTest.Specifications.Tree do
  @moduledoc """
  A specification that forms a small, simple tree structure:

               s0
              /  |
            a/    |a
            /      |
          s1       s2
          / |
        b/   |c
        /     |
      s3      s4

  """
  use Spex.Specification,
    prunable_states: :all,
    prune_timeout: %Duration{hour: 6}

  def_transition :s0, :a, :s1
  def_transition :s0, :a, :s2

  def_transition :s1, :b, :s3
  def_transition :s1, :c, :s4

  @impl Spex.Specification
  def error_handler(error, caller) do
    send(caller, {:from_error_handler, error})

    {:error, error}
  end
end
