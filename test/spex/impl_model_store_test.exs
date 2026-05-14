defmodule Spex.ImplModelStoreTest do
  use ExUnit.Case, async: true

  alias Spex.ImplModel
  alias Spex.ImplModelStore
  alias Spex.Errors.ImplModelError
  alias SpexTest.Specifications.Cycle
  alias SpexTest.Specifications.Tree

  describe "load/1" do
    test "creates missing directory and returns empty list" do
      dir = unique_tmp_dir("missing_dir")
      File.rm_rf!(dir)

      assert {:ok, []} = ImplModelStore.load(dir)
      assert File.dir?(dir)
    end

    test "loads all .spex models from a directory and ignores other files" do
      dir = unique_tmp_dir("load_from_dir")
      File.mkdir_p!(dir)

      tree_model = %ImplModel{
        specification: Tree,
        transitions: MapSet.new([{:s0, :a, :s1}]),
        learning_mode?: false
      }

      cycle_model = %ImplModel{
        specification: Cycle,
        transitions: MapSet.new([{:x0, :a, :x1}]),
        learning_mode?: true
      }

      dir |> Path.join("tree.spex") |> File.write!(ImplModel.serialise(tree_model))
      dir |> Path.join("cycle.spex") |> File.write!(ImplModel.serialise(cycle_model))
      dir |> Path.join("notes.txt") |> File.write!("not a spex model")

      assert {:ok, loaded_models} = ImplModelStore.load(dir)

      assert Enum.map(loaded_models, & &1.specification) |> Enum.sort() == [Cycle, Tree]

      loaded_tree = Enum.find(loaded_models, &(&1.specification == Tree))
      loaded_cycle = Enum.find(loaded_models, &(&1.specification == Cycle))

      assert loaded_tree.transitions == MapSet.new([{:s0, :a, :s1}])
      assert loaded_tree.learning_mode? == false

      assert loaded_cycle.transitions == MapSet.new([{:x0, :a, :x1}])
      assert loaded_cycle.learning_mode? == true
    end

    test "loads a single .spex file path directly" do
      dir = unique_tmp_dir("load_single_file")
      File.mkdir_p!(dir)

      model = %ImplModel{
        specification: Tree,
        transitions: MapSet.new([{:s0, :a, :s2}]),
        learning_mode?: false
      }

      file_path = Path.join(dir, "single.spex")
      File.write!(file_path, ImplModel.serialise(model))

      assert {:ok, [loaded_model]} = ImplModelStore.load(file_path)
      assert loaded_model.specification == Tree
      assert loaded_model.learning_mode? == false
      assert loaded_model.transitions == MapSet.new([{:s0, :a, :s2}])
    end

    test "returns deserialisation error when a .spex file is malformed" do
      dir = unique_tmp_dir("malformed_file")
      File.mkdir_p!(dir)

      dir |> Path.join("bad.spex") |> File.write!("this is not a valid impl model")

      assert {:error, %ImplModelError{} = error} = ImplModelStore.load(dir)
      assert error.reason == :deserialisation_failed
      assert is_struct(error.context.original_error, MatchError)
    end
  end

  describe "save/2" do
    test "writes all models to .spex files" do
      dir = unique_tmp_dir("save_success")
      File.mkdir_p!(dir)

      tree_model = %ImplModel{
        specification: Tree,
        transitions: MapSet.new([{:s0, :a, :s1}]),
        learning_mode?: false
      }

      cycle_model = %ImplModel{
        specification: Cycle,
        transitions: MapSet.new([{:x0, :a, :x1}]),
        learning_mode?: true
      }

      assert :ok = ImplModelStore.save([tree_model, cycle_model], dir)

      assert dir |> Path.join("Elixir.SpexTest.Specifications.Tree.spex") |> File.exists?()
      assert dir |> Path.join("Elixir.SpexTest.Specifications.Cycle.spex") |> File.exists?()

      assert {:ok, loaded_models} = ImplModelStore.load(dir)
      assert Enum.map(loaded_models, & &1.specification) |> Enum.sort() == [Cycle, Tree]
    end

    test "returns all write errors when target directory does not exist" do
      dir = unique_tmp_dir("save_error")
      File.rm_rf!(dir)

      tree_model = %ImplModel{
        specification: Tree,
        transitions: MapSet.new([{:s0, :a, :s1}]),
        learning_mode?: false
      }

      cycle_model = %ImplModel{
        specification: Cycle,
        transitions: MapSet.new([{:x0, :a, :x1}]),
        learning_mode?: true
      }

      assert {:error, errors} = ImplModelStore.save([tree_model, cycle_model], dir)
      assert Enum.count(errors) == 2
      assert Enum.all?(errors, &match?(%File.Error{action: :write}, &1))
      assert Enum.all?(errors, &(&1.reason == :enoent))
    end
  end

  @spec unique_tmp_dir(String.t()) :: Path.t()
  defp unique_tmp_dir(suffix) do
    Path.join(
      System.tmp_dir!(),
      "spex_impl_model_store_test_#{suffix}_#{:erlang.unique_integer([:positive])}"
    )
  end
end
