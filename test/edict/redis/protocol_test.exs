defmodule Edict.Redis.ProtocolTest do
  use ExUnit.Case, async: true
  alias Edict.Redis.Protocol
  doctest Protocol

  describe "parse" do
    test "empty input" do
      assert Protocol.parse("") == :readline
    end

    test "simple strings" do
      assert Protocol.parse("+OK\r\n") == {:ok, "OK", ""}
    end

    test "simple strings pass remainder" do
      assert Protocol.parse("+OK\r\nrem") == {:ok, "OK", "rem"}
    end

    test "errors" do
      assert Protocol.parse("-Error error message\r\n") ==
               {:ok, {:error, "Error", "error message"}, ""}

      assert Protocol.parse("-Error\r\n") == {:ok, {:error, "Error", ""}, ""}
    end

    test "errors pass remainder" do
      assert Protocol.parse("-Error error message\r\nrem") ==
               {:ok, {:error, "Error", "error message"}, "rem"}

      assert Protocol.parse("-Error\r\nrem") == {:ok, {:error, "Error", ""}, "rem"}
    end

    test "integers" do
      assert Protocol.parse(":1000\r\n") == {:ok, 1000, ""}
    end

    test "integers pass remainder" do
      assert Protocol.parse(":1000\r\nrem") == {:ok, 1000, "rem"}
    end

    test "bulk strings" do
      assert Protocol.parse("$6\r\nfoobar\r\n") == {:ok, "foobar", ""}
      assert Protocol.parse("$0\r\n\r\n") == {:ok, "", ""}
    end

    test "bulk strings pass remainder" do
      assert Protocol.parse("$6\r\nfoobar\r\nrem") == {:ok, "foobar", "rem"}
      assert Protocol.parse("$0\r\n\r\nrem") == {:ok, "", "rem"}
    end

    test "partial bulk strings" do
      assert Protocol.parse("$6\r\n") == {:read, 8}
      assert Protocol.parse("$12\r\nfoobar\r\n") == {:read, 6}
    end

    test "partial counts on bulk strings" do
      assert Protocol.parse("$6") == :readline
    end

    test "bulk strings are binary safe" do
      assert Protocol.parse(<<"$4\r\n", 197, 130, 0, 255, "\r\n">>) ==
               {:ok, <<197, 130, 0, 255>>, ""}

      assert Protocol.parse(<<"$6\r\n", 197, 130, "\r\n">>) == {:read, 4}
    end

    test "arrays" do
      assert Protocol.parse("*0\r\n") == {:ok, [], ""}
      assert Protocol.parse("*2\r\n$3\r\nfoo\r\n$3\r\nbar\r\n") == {:ok, ["foo", "bar"], ""}
      assert Protocol.parse("*3\r\n:1\r\n:2\r\n:3\r\n") == {:ok, [1, 2, 3], ""}

      assert Protocol.parse("*5\r\n:1\r\n:2\r\n:3\r\n:4\r\n$6\r\nfoobar\r\n") ==
               {:ok, [1, 2, 3, 4, "foobar"], ""}
    end

    test "partial arrays" do
      assert Protocol.parse("*2\r\n") == :readline
      assert Protocol.parse("*2\r\n$3\r\nfoo\r\n") == :readline

      assert Protocol.parse("*5\r\n:1\r\n:2\r\n:3\r\n:4\r\n$6\r\n") == {:read, 8}
    end

    test "arrays pass remainder" do
      assert Protocol.parse("*0\r\nrem") == {:ok, [], "rem"}
      assert Protocol.parse("*2\r\n$3\r\nfoo\r\n$3\r\nbar\r\nrem") == {:ok, ["foo", "bar"], "rem"}
    end

    test "arrays can hold errors" do
      assert Protocol.parse("*2\r\n-Error that broke!\r\n-INVALID it's wrong\r\n") ==
               {:ok, [{:error, "Error", "that broke!"}, {:error, "INVALID", "it's wrong"}], ""}
    end

    test "arrays can hold nil" do
      assert Protocol.parse("*3\r\n$3\r\nfoo\r\n$-1\r\n$3\r\nbar\r\n") ==
               {:ok, ["foo", nil, "bar"], ""}
    end

    test "arrays handle nested arrays" do
      assert Protocol.parse("*2\r\n*3\r\n:1\r\n:2\r\n:3\r\n*2\r\n+Foo\r\n-Bar\r\n") ==
               {:ok, [[1, 2, 3], ["Foo", {:error, "Bar", ""}]], ""}
    end

    test "nil" do
      assert Protocol.parse("$-1\r\n") == {:ok, nil, ""}
      assert Protocol.parse("*-1\r\n") == {:ok, nil, ""}
    end

    test "nil passes remainder" do
      assert Protocol.parse("$-1\r\nrem") == {:ok, nil, "rem"}
      assert Protocol.parse("*-1\r\nrem") == {:ok, nil, "rem"}
    end
  end

  describe "serialize" do
    test "nil" do
      assert Protocol.serialize(nil) == {:ok, "$-1\r\n"}
    end

    test "atoms" do
      assert Protocol.serialize(:OK) == {:ok, "+OK\r\n"}
    end

    test "strings" do
      assert Protocol.serialize("foobar") == {:ok, "$6\r\nfoobar\r\n"}
      assert Protocol.serialize("") == {:ok, "$0\r\n\r\n"}
    end

    test "strings are binary safe" do
      assert Protocol.serialize(<<197, 130, 0, 255>>) ==
               {:ok, <<"$4\r\n", 197, 130, 0, 255, "\r\n">>}
    end

    test "errors" do
      assert Protocol.serialize({:error, "Error", "error message"}) ==
               {:ok, "-Error error message\r\n"}

      assert Protocol.serialize({:error, "INVALID", ""}) == {:ok, "-INVALID\r\n"}
    end

    test "integers" do
      assert Protocol.serialize(1000) == {:ok, ":1000\r\n"}
    end

    test "arrays" do
      assert Protocol.serialize([]) == {:ok, "*0\r\n"}
      assert Protocol.serialize(["foo", "bar"]) == {:ok, "*2\r\n$3\r\nfoo\r\n$3\r\nbar\r\n"}
      assert Protocol.serialize([1, 2, 3]) == {:ok, "*3\r\n:1\r\n:2\r\n:3\r\n"}

      assert Protocol.serialize([1, 2, 3, 4, "foobar"]) ==
               {:ok, "*5\r\n:1\r\n:2\r\n:3\r\n:4\r\n$6\r\nfoobar\r\n"}
    end

    test "arrays can hold errors" do
      assert Protocol.serialize([
               {:error, "Error", "that broke!"},
               {:error, "INVALID", "it's wrong"}
             ]) == {:ok, "*2\r\n-Error that broke!\r\n-INVALID it's wrong\r\n"}
    end

    test "arrays can hold nil" do
      assert Protocol.serialize(["foo", nil, "bar"]) ==
               {:ok, "*3\r\n$3\r\nfoo\r\n$-1\r\n$3\r\nbar\r\n"}
    end

    test "arrays handle nested arrays" do
      assert Protocol.serialize([[1, 2, 3], ["Foo", {:error, "Bar", ""}]]) ==
               {:ok, "*2\r\n*3\r\n:1\r\n:2\r\n:3\r\n*2\r\n$3\r\nFoo\r\n-Bar\r\n"}
    end

    test "bad input" do
      assert Protocol.serialize({"some", "unsupported", "type"}) == :error
      assert Protocol.serialize([3.14]) == :error
      assert Protocol.serialize([[3.14], "hello"]) == :error
    end
  end
end
