defmodule Spex.Application do
  @moduledoc """
  Application entrypoint for starting the Spex supervision tree.
  """

  use Application

  @impl Application
  def start(_type, _args) do
    Supervisor.start_link([Spex], strategy: :one_for_one, name: __MODULE__)
  end
end
