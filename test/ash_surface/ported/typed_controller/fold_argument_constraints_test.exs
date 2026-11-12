Code.require_file("support/tc_support.exs", __DIR__)

defmodule AshSurface.Ported.TypedController.FoldArgumentConstraintsTest do
  @moduledoc """
  Port of ash_typescript typed_controller/fold_argument_constraints_test.exs onto the
  descriptor-only `RouteSchema` / `RouteSchema.Fold` (string-keyed route maps; no Spark
  `typed_controller` DSL, so compile-time `DslError` raises become typed `{:error, _}`).
  """
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.RouteSchema
  alias AshSurface.Compiler.RouteSchema.Fold
  alias AshSurface.Ported.TypedController.Support, as: S

  test "invalid argument constraints are refused (typed, naming the offending key)" do
    r =
      S.route("login", "post", "/login", [
        S.arg("code", "string", %{"constraints" => %{"min_length" => "x"}})
      ])

    assert {:error, {:invalid_argument_constraints, "login", "code", "min_length", _}} =
             RouteSchema.build([r])
  end

  test "valid constraints are folded with the string allow_empty? default made explicit" do
    {:ok, [arg]} =
      Fold.fold_arguments("rename", [
        S.arg("name", "string", %{"constraints" => %{"min_length" => 3}})
      ])

    assert arg["constraints"]["min_length"] == 3
    assert arg["constraints"]["allow_empty?"] == false

    # explicit allow_empty?: true is kept
    {:ok, [kept]} =
      Fold.fold_arguments("rename", [
        S.arg("name", "string", %{"constraints" => %{"allow_empty?" => true}})
      ])

    assert kept["constraints"]["allow_empty?"] == true
  end

  test "folded constraints are enforced by real zod (min_length + non-empty default)" do
    [r] =
      S.build!([
        S.route("rename", "post", "/rename", [
          S.arg("name", "string", %{"constraints" => %{"min_length" => 3}})
        ])
      ])

    assert [true, false, false, false] =
             S.node_parse(r["body"], [%{name: "abc"}, %{name: "ab"}, %{name: ""}, %{}])
  end

  test "ci_string arguments get the same explicit allow_empty?/trim? defaults as string" do
    {:ok, [arg]} =
      Fold.fold_arguments("rename", [
        S.arg("name", "ci_string", %{"constraints" => %{"min_length" => 2}})
      ])

    assert arg["constraints"]["allow_empty?"] == false
    assert arg["constraints"]["trim?"] == true
    assert arg["constraints"]["min_length"] == 2
  end

  test "a forbidden kind under a top-level item_type (no type map) is refused" do
    returns = %{"kind" => "array", "item_type" => %{"kind" => "resource"}}

    assert {:error, {:unsupported_return, "list", "resource"}} =
             Fold.check_returns(%{"name" => "list"}, %{"returns" => returns})

    assert :ok =
             Fold.check_returns(%{"name" => "list"}, %{
               "returns" => %{"kind" => "array", "item_type" => %{"kind" => "string"}}
             })
  end

  test "array arguments are admitted and element types are enforced under zod" do
    arr =
      S.arg("tags", "array", %{"type" => %{"kind" => "array", "items" => %{"kind" => "string"}}})

    [r] = S.build!([S.route("search", "post", "/search", [arr])])

    assert [true, true, false, false] =
             S.node_parse(r["body"], [
               %{tags: ["elixir", "ash"]},
               %{tags: []},
               %{tags: [1]},
               %{tags: "x"}
             ])
  end

  test "unknown constraint keys are refused with a typed error" do
    r =
      S.route("login", "post", "/login", [
        S.arg("code", "string", %{"constraints" => %{"bogus_key" => 1}})
      ])

    assert {:error,
            {:invalid_argument_constraints, "login", "code", "bogus_key", :unknown_constraint}} =
             RouteSchema.build([r])
  end

  test "multiple arguments keep declaration order in Fold.fold_arguments" do
    args = [S.arg("zeta", "string"), S.arg("alpha", "integer"), S.arg("mid", "string")]

    {:ok, folded} = Fold.fold_arguments("r", args)
    assert Enum.map(folded, & &1["name"]) == ["zeta", "alpha", "mid"]

    # route facts / zod body are key-sorted by RouteSchema, so declaration order is only
    # observable on the fold output; assert the built body still carries every argument.
    [r] = S.build!([S.route("ord", "post", "/ord", args)])
    assert r["body"] =~ "alpha" and r["body"] =~ "mid" and r["body"] =~ "zeta"
  end

  test "string constraints fold trim? default and keep explicit trim?" do
    {:ok, [a]} = Fold.fold_arguments("r", [S.arg("n", "string", %{"constraints" => %{}})])
    assert a["constraints"]["trim?"] == true

    {:ok, [b]} =
      Fold.fold_arguments("r", [S.arg("n", "string", %{"constraints" => %{"trim?" => false}})])

    assert b["constraints"]["trim?"] == false
  end

  test "array item constraints are validated and folded, enforced by zod" do
    items = %{"kind" => "string", "constraints" => %{"min_length" => 2}}
    arr = S.arg("tags", "array", %{"type" => %{"kind" => "array", "items" => items}})

    {:ok, [folded]} = Fold.fold_arguments("s", [arr])
    ic = folded["type"]["items"]["constraints"]
    assert folded["type"]["items"]["type"]["kind"] == "string"
    assert ic["min_length"] == 2 and ic["allow_empty?"] == false

    [r] = S.build!([S.route("search", "post", "/search", [arr])])
    assert [true, false] = S.node_parse(r["body"], [%{tags: ["ab"]}, %{tags: ["a"]}])

    bad = %{"kind" => "string", "constraints" => %{"nope" => 1}}
    barr = S.arg("tags", "array", %{"type" => %{"kind" => "array", "items" => bad}})

    assert {:error, {:invalid_argument_constraints, "s", "tags", "nope", :unknown_constraint}} =
             Fold.fold_arguments("s", [barr])
  end

  test "an argument type that is not a known kind is refused, never z.unknown()" do
    assert {:error, {:invalid_argument_type, "login", "code", "not_a_real_type"}} =
             RouteSchema.build([
               S.route("login", "post", "/login", [S.arg("code", "not_a_real_type")])
             ])
  end

  describe "returns type restrictions" do
    test "rejects a resource" do
      r =
        S.route("todo", "get", "/todo", [], %{"returns" => %{"type" => %{"kind" => "resource"}}})

      assert {:error, {:unsupported_return, "todo", "resource"}} = RouteSchema.build([r])
    end

    test "rejects an embedded resource nested inside an array" do
      ret = %{"type" => %{"kind" => "array", "items" => %{"kind" => "embedded_resource"}}}
      r = S.route("tasks", "get", "/tasks", [], %{"returns" => ret})

      assert {:error, {:unsupported_return, "tasks", "embedded_resource"}} =
               RouteSchema.build([r])
    end

    test "rejects a union" do
      r = S.route("value", "get", "/value", [], %{"returns" => %{"type" => %{"kind" => "union"}}})
      assert {:error, {:unsupported_return, "value", "union"}} = RouteSchema.build([r])
    end

    test "plain data returns are admitted" do
      r = S.route("ok", "get", "/ok", [], %{"returns" => "string"})
      assert {:ok, [_]} = RouteSchema.build([r])
    end
  end

  test "returns array of maps renders a response schema that real zod enforces" do
    ret = %{"type" => %{"kind" => "array", "items" => %{"kind" => "string"}}}
    [r] = S.build!([S.route("names", "get", "/names", [], %{"returns" => ret})])
    assert [true, true, false] = S.node_parse(r["response"], [["a"], [], [1]])
  end

  test "routes without returns keep an unconstrained response and no constraints key" do
    [r] = S.build!([S.route("logout", "post", "/logout")])
    assert r["response"] == "z.unknown()"
  end

  describe "per-kind constraint keys derived from Ash.Type.constraints/1 (wave3 CW)" do
    defp fold(kind, constraints, extra \\ %{}) do
      Fold.fold_arguments("r", [
        S.arg("a", kind, Map.merge(%{"constraints" => constraints}, extra))
      ])
    end

    defp refused?(kind, constraints, key, extra \\ %{}) do
      match?(
        {:error, {:invalid_argument_constraints, "r", "a", ^key, _}},
        fold(kind, constraints, extra)
      )
    end

    test "lawful Ash keys CT saw falsely refused are admitted" do
      for {kind, c} <- [
            {"string", %{"length_count" => "graphemes"}},
            {"ci_string", %{"length_count" => "bytes", "casing" => "upper"}},
            {"atom", %{"unsafe_to_atom?" => true}},
            {"map", %{"preserve_nil_values?" => true}},
            {"struct", %{"preserve_nil_values?" => false}},
            {"utc_datetime", %{"cast_dates_as" => "start_of_day", "timezone" => "Etc/UTC"}},
            {"duration", %{"signs" => ["positive", "zero"], "units" => ["day", "hour"]}},
            {"decimal", %{"min" => 0, "max" => "10.5", "precision" => 5, "scale" => 2}},
            {"float", %{"greater_than" => 0.5, "less_than" => 9}}
          ] do
        assert {:ok, [_]} = fold(kind, c), "#{kind} #{inspect(c)} must be admitted"
      end
    end

    test "known key on the wrong kind is refused (integer / boolean / decimal / float)" do
      assert refused?("integer", %{"match" => "x"}, "match")
      assert refused?("integer", %{"casing" => "upper"}, "casing")
      assert refused?("integer", %{"one_of" => 5}, "one_of")
      assert refused?("integer", %{"items" => "junk"}, "items")
      assert refused?("integer", %{"storage_type" => 1}, "storage_type")
      assert refused?("boolean", %{"min_items" => "z"}, "min_items")
      assert refused?("boolean", %{"precision" => []}, "precision")
      assert refused?("decimal", %{"min_length" => 1}, "min_length")
      assert refused?("float", %{"scale" => 2}, "scale")
      assert refused?("float", %{"precision" => 2}, "precision")
    end

    test "known key with a wrong value shape is refused" do
      assert refused?("integer", %{"min" => "5"}, "min")
      assert refused?("decimal", %{"max" => "abc"}, "max")
      assert refused?("decimal", %{"scale" => -1}, "scale")
      assert refused?("float", %{"max" => [1]}, "max")
      assert refused?("string", %{"length_count" => "words"}, "length_count")
      assert refused?("ci_string", %{"casing" => "title"}, "casing")
      assert refused?("atom", %{"unsafe_to_atom?" => "yes"}, "unsafe_to_atom?")
      assert refused?("atom", %{"one_of" => 5}, "one_of")
      assert refused?("map", %{"preserve_nil_values?" => 1}, "preserve_nil_values?")
    end

    test "array keys: kind and value shape" do
      t = %{"type" => %{"kind" => "array", "items" => %{"kind" => "string"}}}
      assert refused?("array", %{"min_items" => -5}, "min_items", t)
      assert refused?("array", %{"max_items" => "x"}, "max_items", t)
      assert refused?("array", %{"unique_items?" => "no"}, "unique_items?", t)
      assert refused?("array", %{"min_length" => 1.5}, "min_length", t)
      assert refused?("array", %{"match" => "x"}, "match", t)

      assert {:ok, [_]} =
               fold("array", %{"min_items" => 1, "max_items" => 3, "unique_items?" => true}, t)
    end

    test "array item constraints are checked against the item kind" do
      mk = fn item ->
        S.arg("a", "array", %{"type" => %{"kind" => "array", "items" => item}})
      end

      assert {:error, {:invalid_argument_constraints, "r", "a", "min", :not_applicable}} =
               Fold.fold_arguments("r", [
                 mk.(%{"kind" => "string", "constraints" => %{"min" => 1}})
               ])

      assert {:error, {:invalid_argument_constraints, "r", "a", "max", :not_a_number}} =
               Fold.fold_arguments("r", [
                 mk.(%{"kind" => "integer", "constraints" => %{"max" => "x"}})
               ])

      assert {:ok, [_]} =
               Fold.fold_arguments("r", [
                 mk.(%{"kind" => "decimal", "constraints" => %{"min" => "0.1"}})
               ])
    end

    test "hostile keys are refused as unknown on every kind" do
      for kind <- ~w(string integer boolean decimal float array atom map duration) do
        assert {:error,
                {:invalid_argument_constraints, "r", "a", "__proto__", :unknown_constraint}} =
                 fold(kind, %{"__proto__" => %{"polluted" => true}})

        assert {:error,
                {:invalid_argument_constraints, "r", "a", "constructor", :unknown_constraint}} =
                 fold(kind, %{"constructor" => 1})
      end
    end
  end
end
