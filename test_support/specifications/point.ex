defmodule SpexTest.Specifications.Point do
  @moduledoc """
  A specification that forms a simple, reflexive point structure:

       s0
      ↑  |a
       --

  """
  use Spex.Specification

  def_transition :s0, :a, :s0

  @impl Spex.Specification
  def error_handler(error, caller)

  # Note that this case differs from the other specifications and is used in tests
  def error_handler(%Spex.Errors.ImplModelError{reason: :impl_model_not_found} = error, caller) do
    send(caller, {:from_error_handler, error})

    :ok
  end

  def error_handler(error, caller) do
    send(caller, {:from_error_handler, error})

    {:error, error}
  end
end
