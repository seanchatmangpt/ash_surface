defmodule AshSurface.ZodTypeCoreTest do
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.ZodType
  alias AshSurface.Projectors.JS.ZodGuard

  defp frag(kind, extra \\ %{}),
    do: ZodType.fragment(Map.merge(%{"type" => %{"kind" => kind}}, extra))

  test "one_of renders standalone sorted z.enum" do
    out = frag("string", %{"constraints" => %{"one_of" => ["b", "a"]}})
    assert out == ~s|z.enum(["a", "b"])|
    refute out =~ "z.string().enum"
  end

  test "regex escapes only unescaped slash, never doubles backslashes" do
    out = frag("string", %{"constraints" => %{"match" => "^a/b\\d$"}})
    assert out == ~S|z.string().regex(/^a\/b\d(?=\n?$)/)|
    out2 = frag("string", %{"constraints" => %{"match" => ~S"^a\/b$"}})
    assert out2 == ~S|z.string().regex(/^a\/b(?=\n?$)/)|
  end

  test "table fixes" do
    assert frag("uuid") == "z.guid()"
    assert frag("decimal") == "z.string()"
    assert frag("date") == "z.iso.date()"
    assert frag("utc_datetime") == "z.iso.datetime()"
    assert frag("duration") == "z.iso.duration()"
    assert frag("term") == "z.any()"
    assert frag("vector") == "z.array(z.number())"
    assert frag("binary") == "z.string()"
    assert frag("atom") == "z.string()"
    assert frag("time") == "z.iso.time()"
  end

  test "array item recursion" do
    assert frag("array", %{"type" => %{"kind" => "array", "items" => %{"kind" => "uuid"}}}) ==
             "z.array(z.guid())"
  end

  test "nullable and optional are split" do
    assert frag("string", %{"allow_nil?" => true}) == "z.string().nullable()"
    assert frag("string", %{"optional" => true}) == "z.string().optional()"

    assert frag("string", %{"allow_nil?" => true, "default" => "x"}) ==
             "z.string().nullable().optional()"
  end

  test "overrides and unmappable verifier" do
    assert ZodType.fragment(%{"type" => %{"kind" => "money"}},
             overrides: %{"money" => "z.string()"}
           ) ==
             "z.string()"

    defs = [%{"type" => %{"kind" => "money"}}, %{"type" => %{"kind" => "string"}}]
    assert ZodType.unmappable_kinds(defs, overrides: %{}) == ["money"]
    assert ZodType.unmappable_kinds(defs, overrides: %{"money" => "z.string()"}) == []
  end

  test "every emitted fragment passes ZodGuard" do
    for kind <- ZodType.kinds() do
      assert {:ok, _, _} = ZodGuard.admit(frag(kind)), kind
      assert {:ok, _, _} = ZodGuard.admit(frag(kind, %{"allow_nil?" => true, "optional" => true}))
    end

    assert {:ok, _, _} = ZodGuard.admit(frag("string", %{"constraints" => %{"one_of" => ["a"]}}))

    assert {:ok, _, _} =
             ZodGuard.admit(
               frag("integer", %{"constraints" => %{"one_of" => [1, 2], "min" => 0}})
             )

    assert {:ok, _, _} =
             ZodGuard.admit(
               frag("string", %{"constraints" => %{"match" => "^a/b$", "min_length" => 1}})
             )
  end
end
