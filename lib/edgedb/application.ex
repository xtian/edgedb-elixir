defmodule EdgeDB.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    # {:ok, conn} = EdgeDB.start_link(username: "edgedb", password: "password", database: "tutorial")
    {:ok, socket} = EdgeDB.Client.connect(username: "edgedb", password: "password", database: "tutorial")
    :ok = EdgeDB.Client.send_sync(socket) |> IO.inspect()

    {:ok, rest} = :gen_tcp.recv(socket, 0)
    rest |> :binpp.pprint()

    :ok = EdgeDB.Client.send_sync(socket) |> IO.inspect()

    {:ok, rest} = :gen_tcp.recv(socket, 0)
    rest |> :binpp.pprint()

    children = []

    opts = [strategy: :one_for_one, name: EdgeDB.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
