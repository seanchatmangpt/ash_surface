defmodule AshSurface.DigestApiTest do
  use ExUnit.Case, async: true

  test "digest/1 equals the internal canon and the codec digest" do
    c = %{"a" => 1, "b" => [%{x: 1}]}
    assert AshSurface.digest(c) == AshSurface.Digest.content_digest(c)
    assert AshSurface.digest(c) == AshSurface.IR.Codec.digest(c)
    assert AshSurface.digest(c) == AshSurface.contract_digest(c)
    assert byte_size(AshSurface.digest(c)) == 64
    assert AshSurface.digest(%{a: 1}) == AshSurface.digest(%{"a" => 1})
  end

  test "digest/1 matches the surface_contract_digest conformance vectors" do
    %{"vectors" => vs} =
      "conformance/vectors/surface_contract_digest.json" |> File.read!() |> Jason.decode!()

    checked =
      for %{"input" => %{"contract" => c}, "expected" => %{"digest" => d}} <- vs do
        assert AshSurface.digest(c) == d
      end

    assert checked != []
  end
end
