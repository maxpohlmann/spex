defmodule Spex.InstanceManager.InstanceStoreTest do
  use ExUnit.Case, async: false

  alias Spex.Errors.InstanceError
  alias Spex.InstanceManager.Instance
  alias Spex.InstanceManager.InstanceStore
  alias SpexTest.Specifications.Cycle
  alias SpexTest.Specifications.Tree

  @dets_dir "./spex_dets"

  setup do
    # We want a separate DETS table per test
    dets_table = Module.concat(__MODULE__, "DetsTable_#{:erlang.unique_integer([:positive])}")

    :ok = InstanceStore.init(dets_table, @dets_dir)

    %{dets_table: dets_table}
  end

  describe "init/2" do
    test "initializes a DETS table that can be used", %{dets_table: dets_table} do
      :ok = InstanceStore.close(dets_table)

      assert :ok = InstanceStore.init(dets_table, @dets_dir)

      instance = instance_fixture(Tree, :init_roundtrip)
      assert :ok = InstanceStore.put(dets_table, instance)
      assert {:ok, ^instance} = InstanceStore.get(dets_table, :init_roundtrip)
    end
  end

  describe "put/2 and get/2" do
    test "stores and retrieves an instance", %{dets_table: dets_table} do
      instance = instance_fixture(Tree, :tree_1)

      assert :ok = InstanceStore.put(dets_table, instance)
      assert {:ok, ^instance} = InstanceStore.get(dets_table, :tree_1)
    end

    test "returns instance_identifier_not_found for unknown identifiers", %{
      dets_table: dets_table
    } do
      assert {:error, %InstanceError{} = error} = InstanceStore.get(dets_table, :does_not_exist)
      assert error.reason == :instance_identifier_not_found
      assert error.context == %{instance_identifier: :does_not_exist}
    end
  end

  describe "delete/2" do
    test "deletes an existing instance", %{dets_table: dets_table} do
      instance = instance_fixture(Tree, :delete_me)
      :ok = InstanceStore.put(dets_table, instance)

      assert :ok = InstanceStore.delete(dets_table, :delete_me)

      assert {:error, %InstanceError{reason: :instance_identifier_not_found}} =
               InstanceStore.get(dets_table, :delete_me)
    end
  end

  describe "exists?/2" do
    test "returns true when an instance exists and false otherwise", %{dets_table: dets_table} do
      instance = instance_fixture(Tree, :existing)
      :ok = InstanceStore.put(dets_table, instance)

      assert {:ok, true} = InstanceStore.exists?(dets_table, :existing)
      assert {:ok, false} = InstanceStore.exists?(dets_table, :missing)
    end
  end

  describe "all/1" do
    test "returns all stored instances", %{dets_table: dets_table} do
      instance_1 = instance_fixture(Tree, :tree_1)
      instance_2 = instance_fixture(Cycle, :cycle_1, :x0)

      :ok = InstanceStore.put(dets_table, instance_1)
      :ok = InstanceStore.put(dets_table, instance_2)

      assert {:ok, instances} = InstanceStore.all(dets_table)

      assert instances
             |> Enum.map(& &1.identifier)
             |> Enum.sort() == [:cycle_1, :tree_1]
    end
  end

  describe "all/2" do
    test "returns only instances for the requested specification", %{dets_table: dets_table} do
      tree_instance = instance_fixture(Tree, :tree_1)
      cycle_instance = instance_fixture(Cycle, :cycle_1, :x0)

      :ok = InstanceStore.put(dets_table, tree_instance)
      :ok = InstanceStore.put(dets_table, cycle_instance)

      assert {:ok, tree_instances} = InstanceStore.all(dets_table, Tree)
      assert Enum.map(tree_instances, & &1.identifier) == [:tree_1]

      assert {:ok, cycle_instances} = InstanceStore.all(dets_table, Cycle)
      assert Enum.map(cycle_instances, & &1.identifier) == [:cycle_1]
    end
  end

  describe "delete_matching/2" do
    test "deletes only instances that match the filter", %{dets_table: dets_table} do
      keep_instance = instance_fixture(Tree, :keep)
      delete_instance = instance_fixture(Tree, :delete)

      :ok = InstanceStore.put(dets_table, keep_instance)
      :ok = InstanceStore.put(dets_table, delete_instance)

      assert :ok =
               InstanceStore.delete_matching(dets_table, fn instance ->
                 instance.identifier == :delete
               end)

      assert {:ok, true} = InstanceStore.exists?(dets_table, :keep)
      assert {:ok, false} = InstanceStore.exists?(dets_table, :delete)
    end
  end

  describe "traverse/2" do
    test "visits every stored instance", %{dets_table: dets_table} do
      instance_1 = instance_fixture(Tree, :tree_1)
      instance_2 = instance_fixture(Cycle, :cycle_1, :x0)
      parent = self()

      :ok = InstanceStore.put(dets_table, instance_1)
      :ok = InstanceStore.put(dets_table, instance_2)

      assert :ok =
               InstanceStore.traverse(dets_table, fn instance ->
                 send(parent, {:visited, instance.identifier})
               end)

      assert_receive {:visited, :tree_1}
      assert_receive {:visited, :cycle_1}
    end
  end

  describe "truncate/1" do
    test "deletes all instances from the table", %{dets_table: dets_table} do
      :ok = InstanceStore.put(dets_table, instance_fixture(Tree, :tree_1))
      :ok = InstanceStore.put(dets_table, instance_fixture(Cycle, :cycle_1, :x0))

      assert :ok = InstanceStore.truncate(dets_table)
      assert {:ok, []} = InstanceStore.all(dets_table)
    end
  end

  describe "close/1" do
    test "closes the table", %{
      dets_table: dets_table
    } do
      info = :dets.info(dets_table)
      assert Keyword.has_key?(info, :type)

      assert :ok = InstanceStore.close(dets_table)

      assert :dets.info(dets_table) == :undefined
    end
  end

  @spec instance_fixture(Spex.Specification.t(), Instance.instance_identifier(), Spex.state()) ::
          Instance.t()
  defp instance_fixture(specification, identifier, current_state \\ :s0) do
    %Instance{
      specification: specification,
      identifier: identifier,
      meta: nil,
      current_state: current_state,
      transitions: [{:__initialisation__, current_state, DateTime.utc_now()}]
    }
  end
end
