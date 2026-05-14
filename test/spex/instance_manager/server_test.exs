defmodule Spex.InstanceManager.ServerTest do
  use ExUnit.Case, async: true

  alias Spex.InstanceManager.Server
  alias Spex.InstanceManager.Instance
  alias Spex.InstanceManager.InstanceStore
  alias SpexTest.Specifications.Tree
  alias SpexTest.Specifications.Cycle

  @server_name Module.concat(__MODULE__, Server)
  @dets_dir "./spex_dets"

  setup do
    # We want a separate dets table per test
    dets_table = Module.concat(__MODULE__, "DetsTable_#{:erlang.unique_integer([:positive])}")
    %{dets_table: dets_table}
  end

  test "prunes prunable instances on startup", %{dets_table: dets_table} do
    now_minus_24h = DateTime.utc_now() |> DateTime.add(-24, :hour)
    now_minus_1h = DateTime.utc_now() |> DateTime.add(-1, :hour)

    prunable_instance = %Instance{
      specification: Tree,
      identifier: :prunable_instance,
      meta: nil,
      current_state: :s0,
      transitions: [{:__initialisation__, :s0, now_minus_24h}]
    }

    non_prunable_instance = %Instance{
      specification: Tree,
      identifier: :non_prunable_instance,
      meta: nil,
      current_state: :s0,
      transitions: [{:__initialisation__, :s0, now_minus_1h}]
    }

    :ok = InstanceStore.init(dets_table, @dets_dir)
    :ok = InstanceStore.put(dets_table, prunable_instance)
    :ok = InstanceStore.put(dets_table, non_prunable_instance)
    :ok = InstanceStore.close(dets_table)

    pid =
      start_supervised!(%{
        id: :server,
        start:
          {GenServer, :start_link,
           [
             Server,
             [dets_table: dets_table, dets_dir: @dets_dir, prune_interval: :infinity],
             [name: @server_name]
           ]}
      })

    # Pruning happens async'ly, so give it a moment
    Process.sleep(10)

    {:ok, all_instances} = GenServer.call(pid, :all_instances)
    assert Enum.map(all_instances, & &1.identifier) == [:non_prunable_instance]
  end

  test "prunes prunable instances after interval", %{dets_table: dets_table} do
    now_minus_24h = DateTime.utc_now() |> DateTime.add(-24, :hour)
    now_minus_1h = DateTime.utc_now() |> DateTime.add(-1, :hour)

    prunable_instance = %Instance{
      specification: Tree,
      identifier: :prunable_instance,
      meta: nil,
      current_state: :s0,
      transitions: [{:__initialisation__, :s0, now_minus_24h}]
    }

    non_prunable_instance = %Instance{
      specification: Tree,
      identifier: :non_prunable_instance,
      meta: nil,
      current_state: :s0,
      transitions: [{:__initialisation__, :s0, now_minus_1h}]
    }

    pid =
      start_supervised!(%{
        id: :server,
        start:
          {GenServer, :start_link,
           [
             Server,
             [dets_table: dets_table, dets_dir: @dets_dir, prune_interval: 100],
             [name: @server_name]
           ]}
      })

    # Wait for initial pruning check
    Process.sleep(10)

    :ok = InstanceStore.put(dets_table, prunable_instance)
    :ok = InstanceStore.put(dets_table, non_prunable_instance)

    {:ok, all_instances} = GenServer.call(pid, :all_instances)

    # Pruning should not have run again yet
    Process.sleep(80)

    assert Enum.map(all_instances, & &1.identifier) == [
             :prunable_instance,
             :non_prunable_instance
           ]

    # Now pruning should run again
    Process.sleep(20)

    {:ok, all_instances} = GenServer.call(pid, :all_instances)
    assert Enum.map(all_instances, & &1.identifier) == [:non_prunable_instance]
  end

  test "checks transition timeouts on startup if configured", %{dets_table: dets_table} do
    now_minus_200ms = DateTime.utc_now() |> DateTime.add(-200, :millisecond)
    now_minus_10ms = DateTime.utc_now() |> DateTime.add(-10, :millisecond)

    timed_out_instance = %Instance{
      specification: Cycle,
      identifier: :timed_out_instance,
      # Used by Cycle.error_handler/2
      meta: %{test_pid: self()},
      current_state: :s0,
      transitions: [{:__initialisation__, :s0, now_minus_200ms}]
    }

    non_timed_out_instance = %Instance{
      specification: Cycle,
      identifier: :non_timed_out_instance,
      meta: %{test_pid: self()},
      current_state: :s0,
      transitions: [{:__initialisation__, :s0, now_minus_10ms}]
    }

    :ok = InstanceStore.init(dets_table, @dets_dir)
    :ok = InstanceStore.truncate(dets_table)
    :ok = InstanceStore.put(dets_table, timed_out_instance)
    :ok = InstanceStore.put(dets_table, non_timed_out_instance)
    :ok = InstanceStore.close(dets_table)

    start_supervised!(%{
      id: :server,
      start:
        {GenServer, :start_link,
         [
           Server,
           [
             dets_table: dets_table,
             dets_dir: @dets_dir,
             check_transition_timeouts_on_start?: true
           ],
           [name: @server_name]
         ]}
    })

    assert_receive {:from_error_handler,
                    %Spex.Errors.TransitionError{
                      reason: :transition_timeout,
                      context: %{instance: ^timed_out_instance}
                    }}

    refute_receive {:from_error_handler,
                    %Spex.Errors.TransitionError{
                      reason: :transition_timeout,
                      context: %{instance: ^non_timed_out_instance}
                    }}
  end

  test "does not check transition timeouts on startup if not configured", %{
    dets_table: dets_table
  } do
    now_minus_200ms = DateTime.utc_now() |> DateTime.add(-200, :millisecond)

    timed_out_instance = %Instance{
      specification: Cycle,
      identifier: :timed_out_instance,
      # Used by Cycle.error_handler/2
      meta: %{test_pid: self()},
      current_state: :s0,
      transitions: [{:__initialisation__, :s0, now_minus_200ms}]
    }

    :ok = InstanceStore.init(dets_table, @dets_dir)
    :ok = InstanceStore.truncate(dets_table)
    :ok = InstanceStore.put(dets_table, timed_out_instance)
    :ok = InstanceStore.close(dets_table)

    start_supervised!(%{
      id: :server,
      start:
        {GenServer, :start_link,
         [
           Server,
           [
             dets_table: dets_table,
             dets_dir: @dets_dir,
             check_transition_timeouts_on_start?: false
           ],
           [name: @server_name]
         ]}
    })

    refute_receive {:from_error_handler,
                    %Spex.Errors.TransitionError{
                      reason: :transition_timeout,
                      context: %{instance: ^timed_out_instance}
                    }}
  end
end
