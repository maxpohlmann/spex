defmodule Spex.ImplModel do
  @moduledoc """
  Represents the observed implementation model built from runtime transitions.
  """

  alias Spex.BisimilarityChecker

  @type t :: %__MODULE__{
          specification: Spex.Specification.t(),
          transitions: MapSet.t(Spex.transition()),
          learning_mode?: boolean()
        }

  @type serialisation :: String.t()

  defstruct [:specification, :transitions, :learning_mode?]

  @doc """
  Creates an empty implementation model for a specification in learning mode.
  """
  @spec initialise(Spex.Specification.t()) :: t()
  def initialise(specification) do
    %__MODULE__{
      specification: specification,
      transitions: MapSet.new(),
      learning_mode?: true
    }
  end

  @type observation_status ::
          :ok
          | :deviation_still_equivalent
          | :deviation_not_equivalent

  @doc """
  Observes a transition and returns its status and resulting model.

  In learning mode, the transition is added. Outside learning mode, the model
  is checked for bisimilarity impact without mutating stored transitions.
  """
  @spec observe_transition(t(), Spex.transition()) :: {observation_status(), t()}
  def observe_transition(impl_model, transition)

  def observe_transition(
        %__MODULE__{transitions: transitions, learning_mode?: true} = impl_model,
        transition
      ) do
    {:ok, %{impl_model | transitions: MapSet.put(transitions, transition)}}
  end

  def observe_transition(
        %__MODULE__{transitions: transitions, learning_mode?: false} =
          impl_model,
        transition
      ) do
    observation_status =
      cond do
        MapSet.member?(transitions, transition) ->
          :ok

        %{impl_model | transitions: MapSet.put(transitions, transition)}
        |> BisimilarityChecker.bisimilar_to_specification?() ->
          :deviation_still_equivalent

        true ->
          :deviation_not_equivalent
      end

    {observation_status, impl_model}
  end

  @doc """
  Serialises an implementation model into `.spex` text format. For info on the format, just see the
  implementation of this function.
  """
  @spec serialise(t()) :: serialisation()
  def serialise(impl_model) do
    transitions =
      Enum.map_join(impl_model.transitions, "\n", fn {from_state, action, to_state} ->
        "#{Atom.to_string(from_state)} --[#{Atom.to_string(action)}]-> #{Atom.to_string(to_state)}"
      end)

    """
    Specification: #{impl_model.specification}
    Learning mode: #{impl_model.learning_mode?}
    Transitions:
    #{transitions}
    """
  end

  @doc """
  Deserialises `.spex` content into an implementation model.
  """
  @spec deserialise(serialisation()) :: {:ok, t()} | {:error, Spex.Errors.ImplModelError.t()}
  def deserialise(serialisation) do
    [spec_line, learning_mode_line, _transitions_heading | transition_lines] =
      String.split(serialisation, "\n")

    specification = spec_line |> String.replace("Specification: ", "") |> String.to_atom()
    learning_mode? = learning_mode_line |> String.replace("Learning mode: ", "") == "true"

    transitions =
      transition_lines
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(fn line ->
        [from_state, action, to_state] =
          Regex.run(~r/^(.+) --\[(.+)\]-> (.+)$/, line, capture: :all_but_first)

        {String.to_atom(from_state), String.to_atom(action), String.to_atom(to_state)}
      end)
      |> MapSet.new()

    {:ok,
     %__MODULE__{
       specification: specification,
       learning_mode?: learning_mode?,
       transitions: transitions
     }}
  rescue
    e ->
      {:error,
       %Spex.Errors.ImplModelError{reason: :deserialisation_failed, context: %{original_error: e}}}
  end
end
