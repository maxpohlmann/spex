defmodule Spex.BisimilarityChecker do
  @moduledoc """
  Compares implementation models against specifications via branching bisimilarity.
  """

  defmodule MercWrapper do
    @moduledoc """
    Rust NIF wrapper used to execute bisimilarity checks.
    """

    use Rustler, otp_app: :spex, crate: "spex_merc_wrapper"

    @doc """
    Compares implementation and specification LTS data for branching bisimilarity.
    """
    @spec compare_bisimilarity(impl_data, spec_data) :: boolean()
          when impl_data: {[Spex.transition()], Spex.state()},
               spec_data: {[Spex.state()], [Spex.action()], [Spex.transition()], Spex.state()}
    def compare_bisimilarity(impl_data, spec_data)
    def compare_bisimilarity(_, _), do: :erlang.nif_error(:nif_not_loaded)
  end

  @doc """
  Compares an ImplModel against a Specification using bisimilarity checking.

  Returns `true` if the implementation model is bisimilar to the specification,
  `false` otherwise.

  ## Parameters

  - `impl_model`: A `%Spex.ImplModel{}` struct containing observed transitions
  - `specification`: A module implementing the `Spex.Specification` behaviour

  ## Examples

      iex> impl_model = %Spex.ImplModel{...}
      iex> Spex.BisimilarityChecker.bisimilar_to_specification?(impl_model, MySpecification)
      true
  """
  @spec bisimilar_to_specification?(Spex.ImplModel.t()) :: boolean()
  def bisimilar_to_specification?(%Spex.ImplModel{specification: specification} = impl_model) do
    # Extract data from Specification module
    spec_states = specification.states()
    spec_actions = specification.actions()
    spec_transitions = specification.transitions()
    spec_initial_state = specification.initial_state()

    spec_data = {spec_states, spec_actions, spec_transitions, spec_initial_state}

    # Extract data from ImplModel
    impl_transitions = impl_model.transitions |> MapSet.to_list()

    {initialisation_transitions, impl_transitions_proper} =
      Enum.split_with(impl_transitions, fn
        {nil, :__initialisation__, _} -> true
        _ -> false
      end)

    case initialisation_transitions do
      [{nil, :__initialisation__, impl_initial_state}] ->
        impl_data = {impl_transitions_proper, impl_initial_state}

        # Call the Rust NIF
        MercWrapper.compare_bisimilarity(impl_data, spec_data)

      _ ->
        false
    end
  end
end
