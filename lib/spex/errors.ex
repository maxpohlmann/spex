defmodule Spex.Errors do
  @moduledoc """
  Error types used across Spex runtime and persistence boundaries.
  """

  defmodule Template do
    @moduledoc """
    Macro for defining Spex exception modules with typed reasons and context.
    """

    defmacro __using__(args) do
      reasons = Keyword.fetch!(args, :reasons)
      reason_type_ast = Enum.reduce(reasons, &{:|, [], [&1, &2]})

      quote do
        @type reason :: unquote(reason_type_ast)
        @type t :: %__MODULE__{
                reason: reason(),
                context: map() | nil
              }

        @required_fields [:reason]
        defexception [:reason, context: nil]

        @impl Exception
        def message(error)

        def message(%__MODULE__{reason: reason, context: nil}) do
          "#{reason}"
        end

        def message(%__MODULE__{reason: reason, context: context}) do
          "#{reason}; context: #{inspect(context)}"
        end
      end
    end
  end

  defmodule TransitionError do
    @moduledoc """
    Transition-level error used for deviations and timeout conditions.
    """

    use Template,
      reasons: [
        :deviation_still_bisimilar,
        :deviation_not_bisimilar,
        :transition_timeout
      ]
  end

  defmodule InstanceError do
    @moduledoc """
    Instance lifecycle errors such as duplicate or missing identifiers.
    """

    use Template,
      reasons: [
        :instance_identifier_already_in_use,
        :instance_identifier_not_found
      ]
  end

  defmodule ImplModelError do
    @moduledoc """
    ImplModel loading and lookup errors.
    """

    use Template,
      reasons: [
        :deserialisation_failed,
        :impl_model_not_found
      ]
  end

  defmodule DetsError do
    @moduledoc """
    DETS backend operation errors.
    """

    use Template,
      reasons: [
        :close,
        :delete_all_objects,
        :delete,
        :foldl,
        :insert,
        :lookup,
        :member,
        :open_file,
        :traverse
      ]
  end

  defmodule FileError do
    @moduledoc """
    Alias type wrapper for file-system errors represented by `File.Error`.
    """

    # credo:disable-for-next-line Credo.Check.Warning.SpecWithStruct
    @type t :: %File.Error{}
  end
end
