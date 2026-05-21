defmodule Mix.Tasks.SpexTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  test "run/1 returns :ok when all impl models are bisimilar" do
    output =
      capture_io(fn ->
        assert Mix.Tasks.Spex.run([]) == :ok
      end)

    plain_output = strip_ansi(output)

    assert plain_output =~
             "[Spex] All 2 ImplModels are behaviourally equivalent to their " <> "specifications."
  end

  test "run/1 exits with failure and reports non-bisimilar models" do
    output =
      capture_io(fn ->
        assert catch_exit(Mix.Tasks.Spex.run(["test_meta/impl_models/expected"])) ==
                 {:shutdown, 1}
      end)

    plain_output = strip_ansi(output)

    assert plain_output =~
             "[Spex] 2 out of 4 ImplModels are not behaviourally equivalent to their " <>
               "specifications."

    assert plain_output =~
             "[Spex] ImplModel is not behaviourally equivalent after tests finished:"
  end

  @spec strip_ansi(String.t()) :: String.t()
  defp strip_ansi(output) do
    Regex.replace(~r/\e\[[0-9;]*m/, output, "")
  end
end
