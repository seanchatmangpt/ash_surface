defmodule AshSurface.ZodTypeWave2Test do
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.ZodType
  alias AshSurface.Projectors.JS.ZodGuard

  defp frag(kind, extra \\ %{}),
    do: ZodType.fragment(Map.merge(%{"type" => %{"kind" => kind}}, extra))

  defp c(map), do: %{"constraints" => map}
  defp admit!(s), do: assert({:ok, _, _} = ZodGuard.admit(s), s)

  test "regex: PCRE-only omitted, flags emitted" do
    assert frag("string", c(%{"match" => "(?<=a)b"})) == "z.string()"
    assert frag("string", c(%{"match" => "a++"})) == "z.string()"
    assert frag("string", c(%{"match" => "(?i)abc"})) == "z.string()"

    assert frag("string", c(%{"match" => "^a$", "match_flags" => "msi"})) ==
             "z.string().regex(/^a$/ims)"

    assert frag("string", c(%{"match" => "^a$", "match_flags" => "gx"})) ==
             "z.string().regex(/^a(?=\\n?$)/)"

    admit!(frag("string", c(%{"match" => "^a$", "match_flags" => "i"})))
  end

  test "float gt/lt and array lengths" do
    assert frag("float", c(%{"min" => 1, "max" => 9, "greater_than" => 0, "less_than" => 10})) ==
             "z.number().min(1).max(9).gt(0).lt(10)"

    arr = %{"type" => %{"kind" => "array", "items" => %{"kind" => "uuid"}}}
    out = ZodType.fragment(Map.put(arr, "constraints", %{"min_length" => 1, "max_length" => 3}))
    assert out == "z.array(z.guid()).min(1).max(3)"
    admit!(out)
  end

  test "allow_empty? false floors min at 1 only when explicit" do
    assert frag("string", c(%{"allow_empty?" => false})) == "z.string().min(1)"
    assert frag("string", c(%{"allow_empty?" => false, "min_length" => 0})) == "z.string().min(1)"
    assert frag("string", c(%{"allow_empty?" => false, "min_length" => 5})) == "z.string().min(5)"
    assert frag("string", c(%{})) == "z.string()"
    assert frag("string", c(%{"min_length" => 0})) == "z.string().min(0)"
  end

  test "new kinds and enum" do
    for k <-
          ~w(uuid_v7 time_usec duration_name url_encoded_binary module file function any keyword tuple struct) do
      admit!(frag(k))
    end

    # Matches ash_typescript (UUIDv7 => z.uuid()); real-zod court in zod_type_s3b_test.
    assert frag("uuid_v7") == "z.uuid()"

    assert frag("enum", %{"type" => %{"kind" => "enum", "values" => ["b", "a"]}}) ==
             ~s|z.enum(["a", "b"])|

    assert frag("enum", %{"type" => %{"kind" => "enum", "values" => []}}) == "z.string()"
    assert frag("enum") == "z.string()"
  end

  test "manifest keys allow_nil / has_default" do
    assert frag("string", %{"allow_nil" => true, "has_default" => true}) ==
             "z.string().nullable().optional()"
  end

  test "overrides are crash-proof" do
    d = %{"type" => %{"kind" => "money"}}
    assert ZodType.fragment(d, overrides: [money: "z.string()"]) == "z.string()"
    assert ZodType.fragment(d, overrides: %{money: :not_binary}) == "z.unknown()"
    assert ZodType.fragment(d, overrides: :garbage) == "z.unknown()"

    assert ZodType.fragment(%{"type" => %{"kind" => "Foo"}}, overrides: %{Foo => "z.string()"}) ==
             "z.string()"
  end

  test "unmappable_kinds walks items/fields/members" do
    defs = [
      %{"type" => %{"kind" => "array", "items" => %{"kind" => "money"}}},
      %{"type" => %{"kind" => "map"}, "fields" => %{"a" => %{"type" => %{"kind" => "gizmo"}}}},
      %{"type" => %{"kind" => "x", "members" => [%{"type" => %{"kind" => "widget"}}]}}
    ]

    assert ZodType.unmappable_kinds(defs, overrides: %{}) == ["gizmo", "money", "widget", "x"]
  end

  test "fallbacks are consistent" do
    assert ZodType.fragment(%{}) == "z.unknown()"
    assert frag("nope") == "z.unknown()"
  end
end
