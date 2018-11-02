defmodule Edict.Redis.Protocol.Parser do
  def parse("") do
    :readline
  end

  def parse("$-1\r\n" <> rest) do
    ok(nil, rest)
  end

  def parse("*-1\r\n" <> rest) do
    ok(nil, rest)
  end

  def parse("+" <> string) do
    [value, rest] = next_line(string)
    ok(value, rest)
  end

  def parse("$" <> string) do
    {length, rest} = extract_count(string)

    case rest do
      <<value::binary-size(length)>> <> "\r\n" <> rest ->
        ok(value, rest)

      value ->
        {:read, length - byte_size(value)}
    end
  end

  def parse("-" <> string) do
    [line, rest] = next_line(string)

    {error, message} =
      line
      |> String.split(" ", parts: 2)
      |> case do
        [error, message] -> {error, message}
        [error] -> {error, ""}
      end

    ok({:error, error, message}, rest)
  end

  def parse(":" <> string) do
    [line, rest] = next_line(string)
    ok(String.to_integer(line), rest)
  end

  def parse("*" <> string) do
    {count, rest} = extract_count(string)
    parse_array(rest, count, [])
  end

  defp parse_array(rest, 0, acc) do
    acc
    |> Enum.reverse()
    |> ok(rest)
  end

  defp parse_array("", n, _acc) when n > 0 do
    :readline
  end

  defp parse_array(input, n, acc) do
    input
    |> parse()
    |> case do
      {:ok, value, rest} ->
        parse_array(rest, n - 1, [value | acc])

      other ->
        other
    end
  end

  defp extract_count(string) do
    [count, rest] = next_line(string)
    count = String.to_integer(count)
    {count, rest}
  end

  defp next_line(string) do
    String.split(string, "\r\n", parts: 2)
  end

  defp ok(value, rest) do
    {:ok, value, rest}
  end
end
