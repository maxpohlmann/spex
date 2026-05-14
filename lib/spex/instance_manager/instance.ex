defmodule Spex.InstanceManager.Instance do
  @moduledoc """
  Runtime representation of a specification instance and its observed history.
  """

  @type instance_identifier :: term()
  @type meta :: map()

  @type transition_record :: {
          action :: Spex.action(),
          to_state :: Spex.state(),
          timestamp :: DateTime.t()
        }

  @type t :: %__MODULE__{
          specification: Spex.Specification.t(),
          identifier: instance_identifier(),
          meta: meta() | nil,
          current_state: Spex.state() | nil,
          transitions: [transition_record()]
        }

  defstruct [:specification, :identifier, :meta, :current_state, :transitions]

  @doc """
  Initialises a new instance with an empty transition history.
  """
  @spec initialise(Spex.Specification.t(), instance_identifier(), meta() | nil) :: t()
  def initialise(specification, identifier, meta) do
    %__MODULE__{
      specification: specification,
      identifier: identifier,
      meta: meta,
      current_state: nil,
      transitions: []
    }
  end

  @doc """
  Records an observed transition and updates the current state.
  """
  @spec observe_transition(t(), Spex.action(), Spex.state()) :: t()
  def observe_transition(
        %__MODULE__{transitions: transitions} = instance,
        action,
        to_state
      ) do
    transition_record = {action, to_state, DateTime.utc_now()}
    %{instance | transitions: [transition_record | transitions], current_state: to_state}
  end

  @doc """
  Returns whether the instance exceeded its specification transition timeout.
  """
  @spec beyond_transition_timeout?(t(), DateTime.t()) :: boolean()
  def beyond_transition_timeout?(instance, now \\ DateTime.utc_now())

  def beyond_transition_timeout?(%__MODULE__{transitions: []}, _now), do: false

  def beyond_transition_timeout?(
        %__MODULE__{
          specification: specification,
          transitions: [{_, _, last_transition_timestamp} | _]
        },
        now
      ) do
    DateTime.diff(now, last_transition_timestamp, :millisecond) >
      specification.transition_timeout()
  end

  @doc """
  Returns whether the instance is currently eligible for pruning.
  """
  @spec prunable?(t()) :: boolean()

  def prunable?(%__MODULE__{transitions: []}), do: false

  def prunable?(%__MODULE__{
        specification: specification,
        current_state: current_state,
        transitions: [{_, _, last_transition_timestamp} | _]
      }) do
    beyond_prune_timeout?(last_transition_timestamp, specification) and
      state_is_prunable?(current_state, specification)
  end

  @spec beyond_prune_timeout?(DateTime.t(), Spex.Specification.t()) :: boolean()
  defp beyond_prune_timeout?(last_transition_timestamp, specification) do
    DateTime.diff(DateTime.utc_now(), last_transition_timestamp, :millisecond) >
      specification.prune_timeout()
  end

  @spec state_is_prunable?(Spex.state(), Spex.Specification.t()) :: boolean()
  defp state_is_prunable?(current_state, specification) do
    case specification.prunable_states() do
      :all -> true
      :terminal -> current_state in specification.terminal_states()
      states when is_list(states) -> current_state in states
    end
  end
end
