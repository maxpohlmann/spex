defmodule Spex.SpexTest do
  use ExUnit.Case, async: true

  test "child_spec/1 returns expected result" do
    assert Spex.child_spec(impl_models_dir: "imps") == %{
             id: Spex.InstanceManager.SimpleInstanceManager,
             start:
               {Spex.InstanceManager.SimpleInstanceManager, :start_link,
                [[impl_models_dir: "imps"]]}
           }
  end

  test "async functions are available (with default instance manager)" do
    assert function_exported?(Spex, :init_instance_async, 4)
    assert function_exported?(Spex, :init_instance_async, 3)
    assert function_exported?(Spex, :init_instance_async, 2)
    assert function_exported?(Spex, :transition_async, 3)
  end
end
