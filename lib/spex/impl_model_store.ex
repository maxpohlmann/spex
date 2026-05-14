defmodule Spex.ImplModelStore do
  @moduledoc """
  Loads and persists implementation models in `.spex` file format.
  """

  alias Spex.Errors.FileError

  @doc """
  Loads all `.spex` models from a directory or a single file path.
  """
  @spec load(Path.t()) :: {:ok, [Spex.ImplModel.t()]} | {:error, FileError.t()}
  def load(impl_models_dir) do
    with :ok <- ensure_dir_exists(impl_models_dir),
         {:ok, file_names} <- list_dir_contents(impl_models_dir) do
      do_load(file_names, impl_models_dir)
    end
  end

  @spec ensure_dir_exists(Path.t()) :: :ok | {:error, FileError.t()}
  defp ensure_dir_exists(dir) do
    case File.mkdir_p(dir) do
      :ok -> :ok
      {:error, :enotdir} -> :ok
      {:error, reason} -> {:error, file_error(:ls, dir, reason)}
    end
  end

  @spec list_dir_contents(Path.t()) :: {:ok, [Path.t()]} | {:error, FileError.t()}
  defp list_dir_contents(dir) do
    case File.ls(dir) do
      {:ok, file_names} -> {:ok, file_names}
      # In case a file path is given directly, which might happen in Mix.Tasks.Spex
      {:error, :enotdir} -> {:ok, [""]}
      {:error, reason} -> {:error, file_error(:ls, dir, reason)}
    end
  end

  @spec do_load([Path.t()], Path.t()) :: {:ok, [Spex.ImplModel.t()]} | {:error, FileError.t()}
  defp do_load(file_names, impl_models_dir) do
    file_names
    |> Stream.map(&Path.join(impl_models_dir, &1))
    |> Stream.filter(&String.ends_with?(&1, ".spex"))
    |> Stream.map(&load_impl_model/1)
    |> Enum.reduce_while(_acc = [], fn
      {:ok, impl_model}, acc -> {:cont, [impl_model | acc]}
      {:error, error}, _acc -> {:halt, {:error, error}}
    end)
    |> case do
      {:error, error} -> {:error, error}
      impl_models -> {:ok, impl_models}
    end
  end

  @spec load_impl_model(Path.t()) :: {:ok, Spex.ImplModel.t()} | {:error, FileError.t()}
  defp load_impl_model(impl_model_path) do
    case File.read(impl_model_path) do
      {:ok, content} -> Spex.ImplModel.deserialise(content)
      {:error, reason} -> {:error, file_error(:read, impl_model_path, reason)}
    end
  end

  @doc """
  Saves implementation models to the target directory.

  Returns all write errors if one or more files fail to persist.
  """
  @spec save([Spex.ImplModel.t()], Path.t()) :: :ok | {:error, [FileError.t()]}
  def save(impl_models, impl_models_dir) do
    Enum.flat_map(impl_models, fn impl_model ->
      case save_impl_model(impl_model, impl_models_dir) do
        :ok -> []
        {:error, error} -> [error]
      end
    end)
    |> case do
      [] -> :ok
      errors -> {:error, errors}
    end
  end

  @spec save_impl_model(Spex.ImplModel.t(), Path.t()) :: :ok | {:error, FileError.t()}
  defp save_impl_model(impl_model, impl_models_dir) do
    path = Path.join(impl_models_dir, "#{impl_model.specification}.spex")
    serialisation = Spex.ImplModel.serialise(impl_model)

    case File.write(path, serialisation) do
      :ok -> :ok
      {:error, reason} -> {:error, file_error(:write, path, reason)}
    end
  end

  @spec file_error(atom(), Path.t(), File.posix()) :: FileError.t()
  defp file_error(action, path, reason) do
    %File.Error{
      action: action,
      path: path,
      reason: reason
    }
  end
end
