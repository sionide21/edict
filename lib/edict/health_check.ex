defmodule Edict.HealthCheck do
  use GenServer
  require Logger
  @behaviour :ranch_protocol

  def start_link(ref, _socket, transport, _opts) do
    GenServer.start_link(__MODULE__, {ref, transport})
  end

  def init({ref, transport}) do
    {:ok, {ref, transport}, {:continue, :handshake}}
  end

  def handle_continue(:handshake, {ref, transport}) do
    {:ok, socket} = :ranch.handshake(ref)
    :ok = transport.setopts(socket, active: :once)

    {:noreply, transport}
  end

  def handle_info({:tcp, socket, _request}, transport) do
    case Codex.Table.ready?(Edict.Config.topic()) do
      true ->
        transport.send(socket, 'HTTP/1.0 200 OK\n\nOK')

      false ->
        transport.send(socket, 'HTTP/1.0 503 Service Unavailable\n\nBOOTING')
    end

    transport.close(socket)

    {:noreply, transport}
  end

  def handle_info({:tcp_closed, _socket}, state) do
    {:stop, :normal, state}
  end

  def handle_info({:tcp_error, _socket, reason}, state) do
    Logger.error("HealthCheck Connection error", reason)
    {:stop, reason, state}
  end
end
