defmodule WebSocketDistTest do
  use ExUnit.Case
  doctest WebSocketDist

  test "greets the world" do
    assert WebSocketDist.hello() == :world
  end
end
