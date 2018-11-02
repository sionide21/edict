defmodule Edict.Redis.Connection do
  alias __MODULE__.Server

  defdelegate start_link(ref, socket, transport, opts), to: Server
end
