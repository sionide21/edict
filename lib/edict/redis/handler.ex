defmodule Edict.Redis.Handler do
  @callback init() :: {:ok, any}
  @callback handle_command(command :: [String.t()], any) :: {:ok, Edit.Redis.Protocol.t()}

  defmacro __using__(_opts) do
    quote do
      @behaviour Edict.Redis.Handler
    end
  end
end
