defmodule Edict.Redis.Protocol do
  alias __MODULE__.{Parser, Serializer}
  @type t() :: String.t() | atom | integer | nil | {:error, String.t(), String.t()} | [t()]

  defdelegate parse(input), to: Parser

  defdelegate serialize(response), to: Serializer
end
