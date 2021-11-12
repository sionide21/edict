defmodule Edict.Redis.Connection.State do
  alias Edict.Redis.Protocol
  defstruct [:ranch_ref, :transport, :socket, :handler, :handler_state, buffer: ""]

  def new(ranch_ref) do
    %__MODULE__{ranch_ref: ranch_ref}
  end

  def set_transport(state, transport) do
    %{state | transport: transport}
  end

  def set_socket(state, socket) do
    %{state | socket: socket}
  end

  def set_handler(state, handler) do
    %{state | handler: handler}
  end

  def init_handler(state) do
    {:ok, handler_state} = state.handler.init()
    %{state | handler_state: handler_state}
  end

  def accept(state = %{transport: transport, socket: socket}) do
    :ok = transport.setopts(socket, active: :once)
    state
  end

  def buffer_line(state = %{buffer: ""}, line) do
    %{state | buffer: line}
  end

  def buffer_line(state = %{buffer: buffer}, line) do
    %{state | buffer: buffer <> line}
  end

  def next_command(state) do
    state.buffer
    |> Protocol.parse()
    |> case do
      {:ok, value, rem} ->
        {:ok, value, %{state | buffer: rem}}

      {:read, count} ->
        {:read, count, state}

      :readline ->
        {:readline, state}
    end
  end

  def run_command(state, command) do
    command
    |> state.handler.handle_command(state.handler_state)
    |> case do
      {:reply, reply, handler_state} ->
        %{state | handler_state: handler_state}
        |> reply(reply)
    end
  end

  def reply(state, value) do
    {:ok, response} = Protocol.serialize(value)
    state.transport.send(state.socket, response)
    state
  end

  def peername(%{transport: transport, socket: socket}) do
    {:ok, {ip, port}} = transport.peername(socket)
    "#{:inet.ntoa(ip)}:#{port}"
  end
end
