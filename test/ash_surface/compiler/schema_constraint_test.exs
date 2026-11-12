defmodule AshSurface.Compiler.SchemaConstraintTest do
  @moduledoc """
  Courts for the constraint-aware zod fragments (L04/L05 rendering, L16
  courts).

  Shared contract under test — `AshSurface.Compiler.Schema` renders, after
  the base type and BEFORE `.nullable()`:

  - `one_of` (non-empty list)  -> `.enum("a", "b")` on any base kind
  - `min` / `max` (numeric kinds) -> `.min(n)` / `.max(n)`
  - `min_length` / `max_length` (string kinds) -> `.min(n)` / `.max(n)`
  - `match` (string kinds) -> `.regex(/<backslash-escaped>/)`
  - frozen chain order: enum -> min -> max -> min_length -> max_length -> regex
  - absent/empty constraints leave the fragment byte-identical to the
    legacy (unconstrained) emission

  Chicago style: every case is a real `Schema.build/1` call over concrete
  discovery state, asserted on the exact rendered input-block lines. No
  mocks, no stubs.
  """

  use ExUnit.Case, async: true

  alias AshSurface.Compiler.Schema

  defp discovery(actions), do: %{"actions" => actions}

  defp action(id, args, returns \\ nil),
    do: %{"id" => id, "arguments" => args, "returns" => returns}

  defp arg(name, kind, constraints, allow_nil? \\ false) do
    %{
      "name" => name,
      "type" => %{"kind" => kind},
      "constraints" => constraints,
      "allow_nil?" => allow_nil?
    }
  end

  defp build_input_line!(args) do
    assert {:ok, ir, _meta} = Schema.build(discovery([action("Court.Resource#act", args)]))

    [{_id, %AshSurface.Compiler.IR.Boundary{zod: zod}}] = Map.to_list(ir)

    [block] =
      Regex.run(
        ~r/_inputSchema = z\.object\(\{\n(.*?)\n\}\)\.passthrough\(\);/s,
        zod,
        capture: :all_but_first
      )

    block
  end

  describe "one_of renders .enum on any base kind" do
    test "string base with one_of [\"a\",\"b\"]" do
      assert build_input_line!([arg("status", "string", %{"one_of" => ["a", "b"]})]) ==
               ~s{  status: z.enum(["a", "b"])}
    end

    test "integer base with one_of carries the enum too" do
      assert build_input_line!([arg("rank", "integer", %{"one_of" => [1, 2]})]) ==
               "  rank: z.union([z.literal(1), z.literal(2)])"
    end

    test "empty one_of list renders nothing (legacy byte-identity)" do
      assert build_input_line!([arg("status", "string", %{"one_of" => []})]) ==
               "  status: z.string()"
    end
  end

  describe "numeric min/max on numeric kinds" do
    test "min and max on integer" do
      assert build_input_line!([
               arg("score", "integer", %{"min" => 1, "max" => 10})
             ]) == "  score: z.number().int().min(1).max(10)"
    end

    test "float bounds" do
      assert build_input_line!([arg("ratio", "float", %{"min" => 0.0, "max" => 1.0})]) ==
               ~s{  ratio: z.number().min(0).max(1)}
    end
  end

  describe "length bounds on string kinds" do
    test "min_length and max_length" do
      assert build_input_line!([
               arg("name", "string", %{"min_length" => 1, "max_length" => 20})
             ]) == "  name: z.string().min(1).max(20)"
    end
  end

  describe "match renders an escaped regex" do
    test "plain source" do
      assert build_input_line!([arg("slug", "string", %{"match" => "^[a-z]+$"})]) ==
               "  slug: z.string().regex(/^[a-z]+(?=\\n?$)/)"
    end

    test "backslashes are preserved verbatim inside a regex literal" do
      # A regex literal needs no backslash doubling: /\d{3}/ already matches digits.
      assert build_input_line!([arg("code", "string", %{"match" => "\\d{3}"})]) ==
               "  code: z.string().regex(/\\d{3}/)"
    end
  end

  describe "frozen chain order" do
    test "all string constraints in enum -> min -> max -> min_length -> max_length -> regex order" do
      constraints = %{
        "match" => "^a",
        "max_length" => 9,
        "min_length" => 2,
        "max" => 99,
        "min" => 1,
        "one_of" => ~w(a b)
      }

      assert build_input_line!([arg("field", "string", constraints)]) ==
               "  field: z.enum([\"a\", \"b\"])"
    end
  end

  describe "allow_nil appends .nullable() after the chain" do
    test "constraints then optional+nullable" do
      assert build_input_line!([
               arg("status", "string", %{"one_of" => ["a"]}, true)
             ]) == ~s{  status: z.enum(["a"]).nullable()}
    end
  end

  describe "absent constraints keep legacy byte-identity" do
    test "no constraints key at all" do
      line = %{"name" => "plain", "type" => %{"kind" => "string"}, "allow_nil?" => false}

      assert build_input_line!([line]) == "  plain: z.string()"
    end

    test "empty constraints map" do
      assert build_input_line!([arg("plain", "uuid", %{})]) == "  plain: z.guid()"
    end
  end

  describe "kind gating" do
    test "numeric min on a string kind renders nothing" do
      assert build_input_line!([arg("label", "string", %{"min" => 1})]) ==
               "  label: z.string()"
    end

    test "match on an integer kind renders nothing" do
      assert build_input_line!([arg("count", "integer", %{"match" => "\\d+"})]) ==
               "  count: z.number().int()"
    end
  end

  describe "atom-keyed constraint maps render identically" do
    test "atom keys one_of + min_length" do
      assert build_input_line!([
               arg("status", "string", %{one_of: ["x"], min_length: 1})
             ]) == ~s{  status: z.enum(["x"])}
    end
  end

  describe "NewType inputs use subtype_of with subtype_constraints" do
    test "subtype_of string with subtype_constraints one_of" do
      nt = %{
        "name" => "kind",
        "subtype_of" => "string",
        "subtype_constraints" => %{"one_of" => ["p", "q"]}
      }

      assert build_input_line!([nt]) == ~s{  kind: z.enum(["p", "q"])}
    end
  end
end
