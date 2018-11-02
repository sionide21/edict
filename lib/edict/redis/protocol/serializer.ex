defmodule Edict.Redis.Protocol.Serializer do
  def serialize(nil) do
    {:ok, "$-1\r\n"}
  end

  def serialize({:error, error, ""}) do
    {:ok, "-#{error}\r\n"}
  end

  def serialize({:error, error, message}) do
    {:ok, "-#{error} #{message}\r\n"}
  end

  def serialize(int) when is_integer(int) do
    {:ok, ":#{int}\r\n"}
  end

  def serialize(atom) when is_atom(atom) do
    {:ok, "+#{atom}\r\n"}
  end

  def serialize(str) when is_binary(str) do
    length = byte_size(str)
    {:ok, "$#{length}\r\n#{str}\r\n"}
  end

  def serialize(list) when is_list(list) do
    length = Enum.count(list)

    list
    |> Enum.map(&serialize/1)
    |> Enum.reduce({:ok, ["*#{length}\r\n"]}, fn
      {:ok, value}, {:ok, acc} -> {:ok, [value | acc]}
      other, {:ok, _acc} -> other
      _, other -> other
    end)
    |> case do
      {:ok, iodata} ->
        {:ok, iodata |> Enum.reverse() |> IO.iodata_to_binary()}

      other ->
        other
    end
  end

  def serialize(_) do
    :error
  end
end
