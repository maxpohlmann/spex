defmodule Spex.InstanceManager.InstanceStore do
  @moduledoc """
  Abstraction layer for instance storage using DETS.
  """

  alias Spex.Errors.DetsError
  alias Spex.Errors.FileError
  alias Spex.Errors.InstanceError
  alias Spex.InstanceManager.Instance

  @type instance_hash :: non_neg_integer()

  @doc """
  Initializes the DETS table for storing instances.
  """
  @spec init(:dets.tab_name(), Path.t()) :: :ok | {:error, DetsError.t() | FileError.t()}
  def init(dets_table, dets_dir) do
    with :ok <- ensure_dir_exists(dets_dir),
         :ok <- open_dets_table(dets_table, dets_dir) do
      :ok
    end
  end

  @spec ensure_dir_exists(Path.t()) :: :ok | {:error, FileError.t()}
  defp ensure_dir_exists(dir) do
    case File.mkdir_p(dir) do
      :ok -> :ok
      {:error, reason} -> {:error, %File.Error{action: :mkdir_p, path: dir, reason: reason}}
    end
  end

  @spec open_dets_table(:dets.tab_name(), Path.t()) :: :ok | {:error, DetsError.t()}
  defp open_dets_table(dets_table, dets_dir) do
    dets_file_path =
      dets_dir
      |> Path.join("#{dets_table}.dets")
      |> String.to_charlist()

    case :dets.open_file(dets_table, file: dets_file_path) do
      {:ok, _name} ->
        :ok

      {:error, reason} ->
        {:error, %DetsError{reason: :open_file, context: %{dets_reason: reason}}}
    end
  end

  @doc """
  Gets an instance by hash.
  """
  @spec get(:dets.tab_name(), Instance.instance_identifier()) ::
          {:ok, Instance.t()} | {:error, InstanceError.t()} | {:error, DetsError.t()}
  def get(dets_table, instance_identifier) do
    hash = hash_identifier(instance_identifier)

    case :dets.lookup(dets_table, hash) do
      [{^hash, instance}] ->
        {:ok, instance}

      [] ->
        {:error,
         %InstanceError{
           reason: :instance_identifier_not_found,
           context: %{instance_identifier: instance_identifier}
         }}

      {:error, reason} ->
        {:error, %DetsError{reason: :lookup, context: %{dets_reason: reason}}}
    end
  end

  @doc """
  Stores an instance with the given hash.
  """
  @spec put(:dets.tab_name(), Instance.t()) :: :ok | {:error, DetsError.t()}
  def put(dets_table, instance) do
    hash = hash_identifier(instance.identifier)

    case :dets.insert(dets_table, {hash, instance}) do
      :ok -> :ok
      {:error, reason} -> {:error, %DetsError{reason: :insert, context: %{dets_reason: reason}}}
    end
  end

  @doc """
  Deletes an instance by hash.
  """
  @spec delete(:dets.tab_name(), Instance.instance_identifier()) :: :ok | {:error, DetsError.t()}
  def delete(dets_table, instance_identifier) do
    hash = hash_identifier(instance_identifier)

    case :dets.delete(dets_table, hash) do
      :ok -> :ok
      {:error, reason} -> {:error, %DetsError{reason: :delete, context: %{dets_reason: reason}}}
    end
  end

  @doc """
  Checks if an instance exists for the given hash.
  """
  @spec exists?(:dets.tab_name(), Instance.instance_identifier()) ::
          {:ok, boolean()} | {:error, DetsError.t()}
  def exists?(dets_table, instance_identifier) do
    hash = hash_identifier(instance_identifier)

    case :dets.member(dets_table, hash) do
      {:error, reason} -> {:error, %DetsError{reason: :member, context: %{dets_reason: reason}}}
      exists? -> {:ok, exists?}
    end
  end

  @doc """
  Gets all instances.
  """
  @spec all(:dets.tab_name()) :: {:ok, list()} | {:error, DetsError.t()}
  def all(dets_table) do
    fn {_hash, instance}, acc -> [instance | acc] end
    |> :dets.foldl([], dets_table)
    |> case do
      {:error, reason} -> {:error, %DetsError{reason: :foldl, context: %{dets_reason: reason}}}
      all_instances -> {:ok, all_instances}
    end
  end

  @doc """
  Gets all instances for a specific specification.
  """
  @spec all(:dets.tab_name(), module()) :: {:ok, list()} | {:error, DetsError.t()}
  def all(dets_table, specification) do
    fn
      {_hash, %{specification: ^specification} = instance}, acc -> [instance | acc]
      {_hash, _instance}, acc -> acc
    end
    |> :dets.foldl([], dets_table)
    |> case do
      {:error, reason} -> {:error, %DetsError{reason: :foldl, context: %{dets_reason: reason}}}
      all_instances -> {:ok, all_instances}
    end
  end

  @doc """
  Deletes instances matching the given filter function.
  """
  @spec delete_matching(:dets.tab_name(), (Instance.t() -> as_boolean(term()))) ::
          :ok | {:error, DetsError.t()}
  def delete_matching(dets_table, filter_fun) do
    :dets.traverse(dets_table, fn {hash, instance} ->
      if filter_fun.(instance), do: :dets.delete(dets_table, hash)
      :continue
    end)
    |> case do
      {:error, reason} -> {:error, %DetsError{reason: :traverse, context: %{dets_reason: reason}}}
      _ -> :ok
    end
  end

  @doc """
  Traverses all instances with the given function.
  """
  @spec traverse(:dets.tab_name(), (Instance.t() -> term())) :: :ok | {:error, DetsError.t()}
  def traverse(dets_table, fun) do
    :dets.traverse(dets_table, fn {_hash, instance} ->
      fun.(instance)
      :continue
    end)
    |> case do
      {:error, reason} -> {:error, %DetsError{reason: :traverse, context: %{dets_reason: reason}}}
      _ -> :ok
    end
  end

  @doc """
  Deletes all instances from the DETS table.
  """
  @spec truncate(:dets.tab_name()) :: :ok | {:error, DetsError.t()}
  def truncate(dets_table) do
    case :dets.delete_all_objects(dets_table) do
      :ok ->
        :ok

      {:error, reason} ->
        {:error, %DetsError{reason: :delete_all_objects, context: %{dets_reason: reason}}}
    end
  end

  @doc """
  Closes the DETS table.
  """
  @spec close(:dets.tab_name()) :: :ok | {:error, DetsError.t()}
  def close(dets_table) do
    case :dets.close(dets_table) do
      :ok -> :ok
      {:error, reason} -> {:error, %DetsError{reason: :close, context: %{dets_reason: reason}}}
    end
  end

  @spec hash_identifier(Instance.instance_identifier()) :: non_neg_integer()
  defp hash_identifier(instance_identifier), do: :erlang.phash2(instance_identifier)
end
