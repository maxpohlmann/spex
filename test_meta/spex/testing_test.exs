defmodule Spex.TestingTest do
  use ExUnit.Case, async: false

  alias SpexTest.Specifications.Point
  alias SpexTest.Specifications.Cycle
  alias SpexTest.Specifications.Tree

  test "init and transition an instance of a specification without impl_model" do
    assert Spex.init_instance(Point, :foo) == :ok
    assert Spex.transition(:foo, :a, :s0) == :ok
  end

  test "record transition that is new in the impl_model but keeps it bisimilar" do
    Spex.Testing.mock_instance!(Cycle, :bar, :x3)
    assert Spex.transition(:bar, :__internal__, :x0) == :ok
  end

  test "record transition that is new in the impl_model and breaks bisimilarity" do
    Spex.Testing.mock_instance!(Tree, :fizz, :s2)
    assert Spex.transition(:fizz, :a, :s1) == :ok
  end

  test "init instance in a non-initial state to break bisimilarity" do
    assert Spex.init_instance(Tree, :buzz, :s2) == :ok
  end
end
