defmodule Mix.Tasks.Spex do
  @moduledoc """
  Mix task that checks saved implementation models for behavioural equivalence.

  This is the offline verification entry point for `.spex` model files.
  """

  use Mix.Task

  @requirements ["app.config"]

  @doc """
  Runs Spex behavioural equivalence checks for all loaded implementation models.

  Accepts either no arguments (uses configured `:impl_models_dir`) or one path argument to a
  directory or file containing `.spex` models.

  If an implementation model is found to be not behaviourally equivalent to its specification, a
  warning is logged and the task exits with status code 1. Currently, it is not possible to give
  information about _why_ they are not equivalent. It is up to the developer to analyse the
  implementation model and compare it to its specification.
  """
  @impl Mix.Task
  def run(args)

  def run([]) do
    impl_models_dir =
      Application.get_env(:spex, :impl_models_dir) ||
        raise(
          ArgumentError,
          "Missing path to impl models. Please provide it as an argument or configure an " <>
            " :impl_models_dir in the application environment; for details, run " <>
            "`mix help spex`."
        )

    run_checks(impl_models_dir)
  end

  def run([path]) do
    run_checks(path)
  end

  @spec run_checks(Path.t()) :: :ok
  defp run_checks(path) do
    case Spex.ImplModelStore.load(path) do
      {:ok, impl_models} -> do_run_checks(impl_models)
      {:error, error} -> raise error
    end
  end

  @spec do_run_checks([Spex.ImplModel.t()]) :: :ok
  defp do_run_checks(impl_models) when is_list(impl_models) do
    bisimilarity_statuses = Enum.map(impl_models, &check_bisimilarity/1)

    n_total = bisimilarity_statuses |> Enum.count()
    n_not_bisimilar = bisimilarity_statuses |> Stream.filter(&(&1 == false)) |> Enum.count()

    if n_not_bisimilar == 0 do
      IO.puts(
        IO.ANSI.green() <>
          "[Spex] All #{n_total} ImplModels are behaviourally equivalent to their " <>
          "specifications." <>
          IO.ANSI.default_color()
      )

      :ok
    else
      IO.puts(
        IO.ANSI.red() <>
          "[Spex] #{n_not_bisimilar} out of #{n_total} ImplModels are " <>
          "#{IO.ANSI.italic()}not#{IO.ANSI.not_italic()} behaviourally equivalent to their " <>
          "specifications." <>
          IO.ANSI.default_color()
      )

      exit({:shutdown, 1})
    end
  end

  @spec check_bisimilarity(Spex.ImplModel.t()) :: boolean()
  defp check_bisimilarity(%Spex.ImplModel{} = impl_model) do
    bisimilarity_status = Spex.BisimilarityChecker.bisimilar_to_specification?(impl_model)

    if bisimilarity_status == false do
      IO.puts(
        IO.ANSI.red() <>
          "[Spex] ImplModel is not behaviourally equivalent after tests finished:\n" <>
          Spex.ImplModel.serialise(impl_model) <>
          "\n" <>
          IO.ANSI.default_color()
      )
    end

    bisimilarity_status
  end
end
