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
    string
    |> next_line(fn value, rest ->
      ok(value, rest)
    end)
  end

  def parse("$" <> string) do
    string
    |> extract_count(fn length, rest ->
      case rest do
        <<value::binary-size(length)>> <> "\r\n" <> rest ->
          ok(value, rest)

        value ->
          {:read, length - byte_size(value) + 2}
      end
    end)
  end

  def parse("-" <> string) do
    string
    |> next_line(fn line, rest ->
      {error, message} =
        line
        |> String.split(" ", parts: 2)
        |> case do
          [error, message] -> {error, message}
          [error] -> {error, ""}
        end

      ok({:error, error, message}, rest)
    end)
  end

  def parse(":" <> string) do
    string
    |> next_line(fn line, rest ->
      ok(String.to_integer(line), rest)
    end)
  end

  def parse("*" <> string) do
    string
    |> extract_count(fn count, rest ->
      parse_array(rest, count, [])
    end)
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

  defp extract_count(string, fun) do
    string
    |> next_line(fn count, rest ->
      count = String.to_integer(count)
      fun.(count, rest)
    end)
  end

  defp next_line(string, fun) do
    string
    |> String.split("\r\n", parts: 2)
    |> case do
      [line, rest] ->
        fun.(line, rest)
      _ ->
        :readline
    end
  end

  defp ok(value, rest) do
    {:ok, value, rest}
  end
end
