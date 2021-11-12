defmodule Edict.Redis.Connection.Server do
  use GenServer
  require Logger
  alias Edict.Redis.Connection.State
  @behaviour :ranch_protocol

  def start_link(ref, _socket, transport, opts) do
    handler = Keyword.fetch!(opts, :handler)

    state =
      ref
      |> State.new()
      |> State.set_handler(handler)
      |> State.set_transport(transport)

    GenServer.start_link(__MODULE__, state)
  end

  def init(state) do
    {:ok, state, {:continue, :handshake}}
  end

  def handle_continue(:handshake, state) do
    {:ok, socket} = :ranch.handshake(state.ranch_ref)

    state =
      state
      |> State.set_socket(socket)
      |> State.init_handler()
      |> State.accept()

    Logger.info("New connection from #{State.peername(state)}")

    {:noreply, state}
  end

  def handle_info({:tcp, _socket, line}, state) do
    Logger.debug(fn -> "Raw input: #{inspect(line)}" end)

    state =
      state
      |> State.accept()
      |> State.buffer_line(line)
      |> process_commands()

    {:noreply, state}
  end

  def handle_info({:tcp_closed, _socket}, state) do
    Logger.info("Connection closed by peer")
    {:stop, :normal, state}
  end

  def handle_info({:tcp_error, _socket, reason}, state) do
    Logger.error("Connection error", reason)
    {:stop, reason, state}
  end

  defp process_commands(state) do
    state
    |> State.next_command()
    |> case do
      {:ok, command, state} ->
        Logger.debug(fn -> "Running command #{inspect(command)}" end)

        state
        |> State.run_command(command)
        |> process_commands()

      {:read, n, state} ->
        Logger.debug(fn -> "Awaiting #{n} bytes" end)
        state

      {:readline, state} ->
        Logger.debug(fn -> "Awaiting next line" end)
        state
    end
  end
end
