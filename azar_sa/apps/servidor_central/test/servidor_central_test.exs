defmodule ServidorCentralTest do
  use ExUnit.Case
  doctest ServidorCentral

  test "greets the world" do
    assert ServidorCentral.hello() == :world
  end
end
