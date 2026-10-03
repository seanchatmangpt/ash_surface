defmodule AshSurface.IRCodecCoverageTest do
  @moduledoc """
  Pins two edges of the `AshSurface.IR.Codec` canon against the real module:

    * `digest/1` is defined only over maps: any other term is refused with
      an `ArgumentError` naming the offending term, never hashed;
    * staging stringifies non-atom, non-binary map keys (e.g. integer keys)
      to their `to_string/1` form, so the canonical map is JSON-isomorphic,
      round-trips through `from_map/1`, and the recomputed digest is stable.
  """

  use ExUnit.Case, async: true

  alias AshSurface.IR
  alias AshSurface.IR.Codec

  test "digest/1 refuses non-map terms with a message naming the term" do
    assert_raise ArgumentError, "digest/1 requires a map, got: [1, 2]", fn ->
      Codec.digest([1, 2])
    end

    assert_raise ArgumentError, ~s(digest/1 requires a map, got: "surface"), fn ->
      Codec.digest("surface")
    end
  end

  test "integer map keys in a section field stage to their string form and round-trip" do
    ir = %IR{
      version: "26.10.1",
      schema: %IR.Schema{zod: %{1 => "first", 2 => %{3 => :three}}}
    }

    staged = Codec.to_map(ir)

    assert staged["schema"]["zod"] == %{"1" => "first", "2" => %{"3" => "three"}}
    assert staged["ash"] == nil

    assert {:ok, decoded} = Codec.from_map(staged)
    assert Codec.to_map(decoded) == staged
    assert decoded.digest == Codec.digest(staged)
    assert byte_size(decoded.digest) == 64
  end
end
