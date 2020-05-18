defmodule EdgeDB.Connection do
  @moduledoc false

  use DBConnection

  alias EdgeDB.Client

  @enforce_keys [:socket]
  defstruct @enforce_keys

  @impl true
  def connect(options) do
    case Client.connect(options) do
      {:ok, socket} -> %__MODULE__{socket: socket}
      # TODO: exception
      {:error, _} = error -> error
    end
  end

  @impl true
  def disconnect(_reason, state) do
    Client.disconnect(state.socket)
  end

  @impl true
  def checkin(state) do
    {:ok, state}
  end

  @impl true
  def checkout(state) do
    {:ok, state}
  end

  @impl true
  def ping(state) do
    # case Client.send_sync(state.socket) do
    #   :ok -> {:ok, state}
    #   # TODO: exception
    #   {:error, reason} -> {:disconnect, reason, state}
    # end
    {:ok, state}
  end

  @impl true
  def handle_begin(opts, state) do
    {:disconnect, nil, state}
  end

  @impl true
  def handle_close(query, opts, state) do
    {:disconnect, nil, state}
  end

  @impl true
  def handle_commit(opts, state) do
    {:disconnect, nil, state}
  end

  @impl true
  def handle_deallocate(query, cursor, opts, state) do
    {:disconnect, nil, state}
  end

  @impl true
  def handle_declare(query, params, opts, state) do
    {:disconnect, nil, state}
  end

  @impl true
  def handle_execute(query, params, opts, state) do
    {:disconnect, nil, state}
  end

  @impl true
  def handle_fetch(query, cursor, opts, state) do
    {:disconnect, nil, state}
  end

  @impl true
  def handle_prepare(query, opts, state) do
    {:disconnect, nil, state}
  end

  @impl true
  def handle_rollback(opts, state) do
    {:disconnect, nil, state}
  end

  @impl true
  def handle_status(opts, state) do
    {:disconnect, nil, state}
  end
end
