defmodule EdgeDB.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = []

    opts = [strategy: :one_for_one, name: EdgeDB.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
