defmodule SpexTest.Specifications.Arrow do
  @moduledoc """
  A specification that forms a simple, single arrow structure:

          a
      s0 ---> s1

  """
  use Spex.Specification,
    prunable_states: :terminal

  def_transition :s0, :a, :s1

  @impl Spex.Specification
  def error_handler(error, caller) do
    send(caller, {:from_error_handler, error})

    {:error, error}
  end
end
