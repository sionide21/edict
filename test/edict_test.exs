defmodule EdictTest do
  use ExUnit.Case
  doctest Edict

  test "greets the world" do
    assert Edict.hello() == :world
  end
end
