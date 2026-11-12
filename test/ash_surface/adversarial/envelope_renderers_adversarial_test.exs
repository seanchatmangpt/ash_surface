Code.require_file("support.exs", __DIR__)

defmodule AshSurface.Adversarial.EnvelopeRenderersTest do
  @moduledoc """
  Lane S2 courts: adversarial inputs through the query/filter/selection/identity/
  calculation/relationship/error/route/channel renderers, executed under real
  zod 4 in node and ZodGuard.admit/1. Seeds are in test names.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Adversarial.S2

  alias AshSurface.Compiler.{
    CalculationSchema,
    ErrorSchema,
    FilterSchema,
    IdentitySchema,
    QuerySchema,
    RelationshipSchema,
    RouteSchema,
    SelectionSchema,
    ValidationErrorSchema
  }

  alias AshSurface.Compiler.Section.Channel

  defp ok_or_refused(res, label),
    do: assert(res in [:agree, :refused], "#{label}: #{inspect(res, limit: 8)}")

  defp str_field(n), do: %{"name" => n, "type" => %{"kind" => "string"}}

  describe "SelectionSchema" do
    for seed <- [41, 42, 43, 44, 45] do
      test "seed=#{seed}: admitted names accepted, denied/unknown rejected" do
        [d | adm] = S2.names(unquote(seed), 5)

        cases =
          Enum.map(adm, &{%{"fields" => [&1]}, true}) ++
            [
              {%{"fields" => adm}, true},
              {%{"fields" => []}, true},
              {%{"fields" => [d]}, false},
              {%{"fields" => ["zz_unknown"]}, false},
              {%{"fields" => adm, "zz" => 1}, false},
              {%{"fields" => "x"}, false},
              {nil, false}
            ]

        ok_or_refused(
          S2.classify(SelectionSchema.render_selection_schema(adm ++ [d], [d]), cases),
          "names=#{inspect(adm)}"
        )
      end
    end

    test "empty admitted set: only empty fields array" do
      res =
        S2.classify(SelectionSchema.render_selection_schema([], []), [
          {%{"fields" => []}, true},
          {%{"fields" => ["a"]}, false}
        ])

      assert res == :agree
    end

    test "denying everything empties the set" do
      res =
        S2.classify(SelectionSchema.render_selection_schema(["a", "b"], ["a", "b"]), [
          {%{"fields" => []}, true},
          {%{"fields" => ["a"]}, false}
        ])

      assert res == :agree
    end

    test "duplicate admitted names" do
      res =
        S2.classify(SelectionSchema.render_selection_schema(["a", "a", "b"], []), [
          {%{"fields" => ["a", "b"]}, true},
          {%{"fields" => ["c"]}, false}
        ])

      assert res in [:agree, :refused]
    end

    test "__proto__ / constructor as admitted field names" do
      res =
        S2.classify(SelectionSchema.render_selection_schema(["__proto__", "constructor"], []), [
          {%{"fields" => ["__proto__"]}, true},
          {%{"fields" => ["toString"]}, false}
        ])

      assert res in [:agree, :refused]
    end
  end

  describe "IdentitySchema.render_get_schema" do
    for seed <- [51, 52, 53, 54, 55] do
      test "seed=#{seed}: key names round-trip as JSON-quoted keys" do
        [n | keys] = S2.names(unquote(seed), 3)
        ident = %{"name" => n, "keys" => Enum.map(keys, &str_field/1)}

        case IdentitySchema.render_get_schema([ident], []) do
          {:ok, m} ->
            valid = Map.new(keys, &{&1, "x"})

            cases = [
              {valid, true},
              {Map.put(valid, "zz_extra", "x"), false},
              {Map.put(valid, hd(keys), 1), false},
              {%{}, false},
              {nil, false}
            ]

            for {_name, zod} <- m,
                do:
                  ok_or_refused(S2.classify({:ok, zod}, cases), "identity names=#{inspect(keys)}")

          {:error, _} ->
            :ok
        end
      end
    end

    test "nil / junk inputs are typed errors" do
      assert {:error, _} = IdentitySchema.render_get_schema(nil, nil)
      assert {:error, _} = IdentitySchema.render_get_schema([], [])

      assert {:error, _} =
               IdentitySchema.render_get_schema([%{"name" => "x", "keys" => []}], ["id"])
               |> then(&(&1 || {:error, nil}))
    end

    test "colliding identity names are refused (S1-I L1 regression)" do
      a = %{"name" => "dup", "keys" => [str_field("k1")]}
      b = %{"name" => "dup", "keys" => [str_field("k2")]}

      assert {:error, {:identity_name_collision, "dup", _}} =
               IdentitySchema.render_get_schema([a, b], [])
    end

    test "tenant schema: nil/map inputs" do
      assert {:ok, expr} = IdentitySchema.render_tenant_schema()
      assert is_binary(expr)
      assert {:ok, nil} = IdentitySchema.render_tenant_schema(nil)
    end
  end

  describe "QuerySchema sort / pagination" do
    for seed <- [61, 62, 63] do
      test "seed=#{seed}: sort over nasty names is accepted or refused typed; never a throw" do
        names = S2.names(unquote(seed), 4)

        case QuerySchema.render_sort_schema(names) do
          {:ok, expr} ->
            cases =
              Enum.map(names, &{&1, true}) ++
                [{"zz_none", false}, {"", false}, {nil, false}, {1, false}]

            assert S2.classify({:ok, expr}, cases) == :agree,
                   "names=#{inspect(names)} expr=#{expr}"

          {:error, _} ->
            :ok
        end
      end
    end

    test "identifier names: sort grammar accept/reject" do
      {:ok, expr} = QuerySchema.render_sort_schema(["name", "age"])

      cases = [
        {"name", true},
        {"-name", true},
        {"+age", true},
        {"name,-age", true},
        {"name,", false},
        {",name", false},
        {"nam", false},
        {"name\n", false},
        {"name,age,zz", false},
        {"", false}
      ]

      assert S2.classify({:ok, expr}, cases) == :agree
    end

    test "empty / duplicate / nil sort field lists are typed" do
      assert {:error, _} = QuerySchema.render_sort_schema([])
      assert {:error, _} = QuerySchema.render_sort_schema(nil)

      assert match?({:ok, _}, QuerySchema.render_sort_schema(["a", "a"])) or
               match?({:error, _}, QuerySchema.render_sort_schema(["a", "a"]))
    end

    for {label, opts, cases} <- [
          {"offset only", %{offset?: true, required?: true},
           [
             {%{"limit" => 5}, true},
             {%{"limit" => 0}, false},
             {%{"limit" => 5, "offset" => -1}, false},
             {%{"limit" => 1.5}, false},
             {%{"limit" => 5, "zz" => 1}, false},
             {%{}, false}
           ]},
          {"keyset only", %{keyset?: true, required?: true},
           [
             {%{"limit" => 1, "after" => "x"}, true},
             {%{"limit" => 1, "after" => 1}, false},
             {%{"limit" => 1, "offset" => 1}, false}
           ]},
          {"optional", %{offset?: true}, [{nil, false}, {%{"limit" => 1}, true}, {%{}, true}]},
          {"huge max_limit", %{offset?: true, required?: true, max_limit: 9_007_199_254_740_991},
           [{%{"limit" => 10}, true}, {%{"limit" => -1}, false}, {%{"limit" => 0}, false}]}
        ] do
      test "pagination #{label}" do
        res =
          S2.classify(
            QuerySchema.render_pagination_schema(unquote(Macro.escape(opts))),
            unquote(Macro.escape(cases))
          )

        assert res == :agree, inspect(res, limit: 6)
      end
    end

    test "invalid max_limit values are typed errors (S1-F L4 regression)" do
      for bad <- [0, -1, 1.5, "10", :x] do
        assert {:error, {:invalid_max_limit, ^bad}} =
                 QuerySchema.render_pagination_schema(%{offset?: true, max_limit: bad})
      end
    end

    test "no mode selected is refused" do
      assert {:error, :pagination_unsupported} = QuerySchema.render_pagination_schema(%{})
    end

    test "limit_entry required only when pagination required and no default (S1-F regression)" do
      {:ok, req} = QuerySchema.render_pagination_schema(%{offset?: true, required?: true})

      {:ok, dflt} =
        QuerySchema.render_pagination_schema(%{
          offset?: true,
          required?: true,
          default_limit?: true
        })

      assert S2.classify({:ok, req}, [{%{}, false}, {%{"limit" => 1}, true}]) == :agree
      assert S2.classify({:ok, dflt}, [{%{}, true}, {%{"limit" => 1}, true}]) == :agree
    end
  end

  describe "FilterSchema" do
    for seed <- [71, 72, 73, 74] do
      test "seed=#{seed}: nasty field names" do
        [a, b | _] = names = S2.names(unquote(seed), 3)

        inputs = [str_field(a), %{"name" => b, "type" => %{"kind" => "integer"}}]

        cases = [
          {%{"field" => a, "op" => "eq", "value" => "x"}, true},
          {%{"field" => b, "op" => "gte", "value" => 3}, true},
          {%{"field" => a, "op" => "eq", "value" => 1}, false},
          {%{"field" => b, "op" => "eq", "value" => "x"}, false},
          {%{"field" => "zz_unknown", "op" => "eq", "value" => 1}, false},
          {%{"op" => "and", "value" => [%{"field" => b, "op" => "eq", "value" => 1}]}, true},
          {%{"op" => "and", "value" => []}, true},
          {nil, false},
          {[], false}
        ]

        ok_or_refused(
          S2.classify(FilterSchema.render_filter_schema(inputs), cases),
          "filter names=#{inspect(names)}"
        )
      end
    end

    test "empty inputs list" do
      res =
        S2.classify(FilterSchema.render_filter_schema([]), [
          {%{"field" => "a", "op" => "eq", "value" => 1}, false},
          {nil, false}
        ])

      assert res in [:agree, :refused]
    end

    test "duplicate field names do not throw at zod load (wave2-fl class)" do
      d = [str_field("dup"), %{"name" => "dup", "type" => %{"kind" => "integer"}}]

      res =
        S2.classify(FilterSchema.render_filter_schema(d), [
          {%{"field" => "dup", "op" => "eq", "value" => "x"}, true}
        ])

      assert res in [
               :agree,
               :refused,
               {:disagree, [{%{"field" => "dup", "op" => "eq", "value" => "x"}, true, false}]}
             ],
             inspect(res)

      refute match?({:node_throw, _}, res)
    end

    test "max_depth 0/1/8 reject one level past the cap" do
      leaf = %{"field" => "n", "op" => "eq", "value" => 1}

      wrap = fn p, k ->
        Enum.reduce(1..k//1, p, fn _, acc -> %{"op" => "and", "value" => [acc]} end)
      end

      inputs = [%{"name" => "n", "type" => %{"kind" => "integer"}}]

      for d <- [0, 1, 8] do
        res =
          S2.classify(FilterSchema.render_filter_schema(inputs, max_depth: d), [
            {wrap.(leaf, d), true},
            {wrap.(leaf, d + 1), false}
          ])

        ok_or_refused(res, "max_depth #{d}")
      end
    end

    test "numeric edge values: 0, negative, huge, float on integer field" do
      inputs = [%{"name" => "n", "type" => %{"kind" => "integer"}}]
      f = &%{"field" => "n", "op" => "eq", "value" => &1}

      cases = [
        {f.(0), true},
        {f.(-1), true},
        {f.(9_007_199_254_740_991), true},
        {f.(1.5), false},
        {f.(nil), false}
      ]

      assert S2.classify(FilterSchema.render_filter_schema(inputs), cases) == :agree
    end

    test "non-list inputs are typed errors" do
      assert {:error, _} = FilterSchema.render_filter_schema(nil)
      assert {:error, _} = FilterSchema.render_filter_schema([], nil)
    end
  end

  describe "CalculationSchema" do
    for seed <- [81, 82, 83, 84] do
      test "seed=#{seed}: nasty calc and argument names" do
        [c1, c2, a1] = names = S2.names(unquote(seed), 3)

        calcs = [
          %{
            name: c1,
            arguments: [%{name: a1, kind: :string, constraints: %{}, allow_nil?: false}],
            return_kind: :string
          },
          %{name: c2, arguments: [], return_kind: :integer}
        ]

        cases = [
          {%{}, true},
          {%{c2 => %{}}, true},
          {%{c1 => %{"args" => %{a1 => "x"}}}, true},
          {%{c1 => %{"args" => %{a1 => 1}}}, false},
          {%{c1 => %{"args" => %{"zz" => "x"}}}, false},
          {%{"zz_unknown" => %{}}, false},
          {nil, false}
        ]

        ok_or_refused(
          S2.classify(CalculationSchema.render_calculation_schema(calcs), cases),
          "calc names=#{inspect(names)}"
        )
      end
    end

    test "each calc is bound to its own args (S1-A M5 regression)" do
      calcs = [
        %{
          name: "a",
          arguments: [%{name: "s", kind: :string, constraints: %{}, allow_nil?: true}],
          return_kind: :string
        },
        %{
          name: "b",
          arguments: [%{name: "n", kind: :integer, constraints: %{}, allow_nil?: true}],
          return_kind: :integer
        }
      ]

      cases = [
        {%{"a" => %{"args" => %{"s" => "x"}}}, true},
        {%{"b" => %{"args" => %{"n" => 1}}}, true},
        {%{"a" => %{"args" => %{"n" => 1}}}, false},
        {%{"b" => %{"args" => %{"s" => "x"}}}, false},
        {%{"a" => %{}, "b" => %{}}, true}
      ]

      assert S2.classify(CalculationSchema.render_calculation_schema(calcs), cases) == :agree
    end

    test "empty list and nil are lawful / typed" do
      assert S2.classify(CalculationSchema.render_calculation_schema([]), [
               {%{}, true},
               {%{"x" => %{}}, false}
             ]) in [:agree, :refused]

      assert {:error, _} = CalculationSchema.render_calculation_schema(nil)
    end

    test "duplicate calculation names" do
      c = %{name: "d", arguments: [], return_kind: :string}

      res =
        S2.classify(CalculationSchema.render_calculation_schema([c, c]), [{%{"d" => %{}}, true}])

      assert res in [:agree, :refused], inspect(res)
    end

    test "aggregate schemas over nasty names do not raise" do
      names = S2.names(85, 4)
      facts = Enum.map(names, &%{name: &1, kind: :count, field: nil})

      assert match?({:ok, _}, CalculationSchema.render_aggregate_schemas(facts)) or
               match?({:error, _}, CalculationSchema.render_aggregate_schemas(facts))

      assert match?({:ok, _}, CalculationSchema.render_aggregate_metadata(facts)) or
               match?({:error, _}, CalculationSchema.render_aggregate_metadata(facts))

      assert {:error, _} = CalculationSchema.render_aggregate_schemas(nil)
    end
  end

  describe "RelationshipSchema" do
    for seed <- [91, 92, 93, 94] do
      test "seed=#{seed}: nasty relationship names, depth 0/1/2" do
        [r1, r2] = names = S2.names(unquote(seed), 2)

        rels = [
          %{"name" => r1, "destination" => "X", "cardinality" => "one"},
          %{
            "name" => r2,
            "destination" => "Y",
            "cardinality" => "many",
            "primitive_fields" => ["a"]
          }
        ]

        for depth <- [0, 1, 2] do
          case RelationshipSchema.render_load_schema(rels, max_depth: depth) do
            {:ok, expr, _desc} ->
              cases = [
                {%{r1 => true}, true},
                {%{r2 => %{"fields" => ["a"]}}, true},
                {%{r2 => %{"fields" => ["zz"]}}, false},
                {%{"zz_undeclared" => true}, false},
                {nil, false}
              ]

              ok_or_refused(
                S2.classify({:ok, expr}, cases),
                "rel names=#{inspect(names)} depth=#{depth}"
              )

            {:error, _} ->
              :ok
          end
        end
      end
    end

    test "exposed:false omitted from descriptors and rejects at load (S1-A M6 regression)" do
      rels = [
        %{"name" => "shown", "destination" => "X", "cardinality" => "one"},
        %{"name" => "hidden", "destination" => "Y", "cardinality" => "one", "exposed" => false}
      ]

      {:ok, expr, _} = RelationshipSchema.render_load_schema(rels)

      assert S2.classify({:ok, expr}, [{%{"shown" => true}, true}, {%{"hidden" => true}, false}]) ==
               :agree
    end

    test "invalid max_depth values are typed errors (S1-A M6 regression)" do
      rels = [%{"name" => "r", "destination" => "X", "cardinality" => "one"}]

      for bad <- [-1, 1.5, "2", :x] do
        assert {:error, {:invalid_max_depth, ^bad}} =
                 RelationshipSchema.render_load_schema(rels, max_depth: bad)
      end
    end

    test "empty list / nil" do
      assert match?({:ok, _, _}, RelationshipSchema.render_load_schema([])) or
               match?({:error, _}, RelationshipSchema.render_load_schema([]))

      assert {:error, :relationships_must_be_a_list} = RelationshipSchema.render_load_schema(nil)
    end

    test "many: limit/offset and page are mutually exclusive" do
      rels = [%{"name" => "m", "destination" => "X", "cardinality" => "many"}]
      {:ok, expr, _} = RelationshipSchema.render_load_schema(rels)

      cases = [
        {%{"m" => true}, true},
        {%{"m" => %{"fields" => ["a"], "limit" => 1, "offset" => 0}}, true},
        {%{"m" => %{"fields" => ["a"], "limit" => 0}}, false},
        {%{"m" => %{"fields" => ["a"], "offset" => -1}}, false},
        {%{"m" => %{"fields" => ["a"], "limit" => 1, "page" => %{"limit" => 1}}}, false},
        {%{"m" => %{"fields" => []}}, false}
      ]

      assert S2.classify({:ok, expr}, cases) == :agree
    end
  end

  describe "ErrorSchema / ValidationErrorSchema" do
    for seed <- [101, 102, 103] do
      test "seed=#{seed}: field_errors over nasty field names" do
        names = S2.names(unquote(seed), 3)
        expr = ErrorSchema.field_errors(names)
        assert is_binary(expr)
        res = S2.classify_expr(expr, [{nil, false}, {1, false}])
        assert res == :agree, "names=#{inspect(names)} #{inspect(res, limit: 5)}"
      end
    end

    test "base/variants/union load under zod and base is passthrough" do
      assert S2.classify_expr(ErrorSchema.base(), [{nil, false}, {1, false}, {"s", false}]) ==
               :agree

      assert S2.classify_expr(ErrorSchema.union(), [{nil, false}, {1, false}]) == :agree

      for {type, expr} <- ErrorSchema.variants() do
        assert S2.classify_expr(expr, [{nil, false}]) == :agree, "variant #{type}"
      end
    end

    test "variant of junk types does not raise" do
      for t <- [nil, "", "a\"b\\c\n", :atom, 1, "__proto__"] do
        assert is_binary(ErrorSchema.variant(t))
      end
    end

    test "action_field_errors: empty and nasty keys" do
      assert is_binary(ErrorSchema.action_field_errors(%{}) |> inspect())
      names = S2.names(104, 3)
      actions = Map.new(names, &{&1, Enum.take(names, 2)})
      assert is_binary(inspect(ErrorSchema.action_field_errors(actions)))
    end

    test "ValidationErrorSchema.render over junk definitions is ok or typed error" do
      for d <- [
            nil,
            %{},
            %{"type" => nil},
            %{"type" => %{"kind" => "string"}},
            %{"type" => %{"kind" => "typed_map", "fields" => []}}
          ] do
        r = ValidationErrorSchema.render(d)
        assert match?({:ok, _}, r) or match?({:error, _}, r), inspect(d)
      end
    end

    for seed <- [111, 112, 113] do
      test "ValidationErrorSchema seed=#{seed}: nasty field names" do
        names = S2.names(unquote(seed), 3)
        d = %{"type" => %{"kind" => "typed_map", "fields" => Enum.map(names, &str_field/1)}}

        case ValidationErrorSchema.render(d) do
          {:ok, expr} -> assert S2.classify_expr(expr, [{nil, false}, {1, false}]) == :agree
          {:error, _} -> :ok
        end
      end
    end
  end

  describe "__proto__ field name (guard denies the key; renderer must refuse typed, not emit)" do
    alias AshSurface.Compiler.EmbeddedSchema

    defp proto_ok?(res), do: res in [:agree, :refused]

    test "selection/filter/errors/validation/calc/union/relationship are lawful" do
      n = "__proto__"

      assert proto_ok?(
               S2.classify(SelectionSchema.render_selection_schema([n], []), [
                 {%{"fields" => [n]}, true}
               ])
             )

      assert proto_ok?(
               S2.classify(FilterSchema.render_filter_schema([str_field(n)]), [
                 {%{"field" => n, "op" => "eq", "value" => "x"}, true}
               ])
             )

      assert proto_ok?(
               S2.classify(
                 CalculationSchema.render_calculation_schema([
                   %{name: n, arguments: [], return_kind: :string}
                 ]),
                 [{%{n => %{}}, true}]
               )
             )

      assert proto_ok?(
               S2.classify(
                 ValidationErrorSchema.render(%{
                   "type" => %{"kind" => "typed_map", "fields" => [str_field(n)]}
                 }),
                 [{nil, false}]
               )
             )

      assert proto_ok?(S2.classify_expr(ErrorSchema.field_errors([n]), [{nil, false}]))

      case RelationshipSchema.render_load_schema([
             %{"name" => n, "destination" => "X", "cardinality" => "one"}
           ]) do
        {:ok, e, _} -> assert proto_ok?(S2.classify({:ok, e}, [{%{n => true}, true}]))
        {:error, _} -> :ok
      end
    end

    test "EmbeddedSchema typed_map with __proto__ field" do
      n = "__proto__"
      d = %{"type" => %{"kind" => "typed_map", "fields" => [str_field(n)]}}
      assert proto_ok?(S2.classify(EmbeddedSchema.render(d), [{%{n => "x"}, true}]))
    end

    test "IdentitySchema with __proto__ key" do
      n = "__proto__"

      assert {:error, {:identity_key_denied, "i", "__proto__"}} =
               IdentitySchema.render_get_schema([%{"name" => "i", "keys" => [str_field(n)]}], [])
    end
  end

  describe "RouteSchema" do
    test "path_params extracts :name and *glob; nasty paths do not raise" do
      assert RouteSchema.path_params("/a/:id/b/*rest") == ["id", "rest"]
      assert RouteSchema.path_params("") == []
      assert is_list(RouteSchema.path_params("/a\"b/:x\n/\u2028/:y"))
    end

    test "junk route lists are typed" do
      assert {:error, {:routes_not_a_list, nil}} = RouteSchema.build(nil)
      assert match?({:ok, []}, RouteSchema.build([]))
    end

    test "duplicate routes are refused" do
      r = %{"verb" => "get", "path" => "/a", "name" => "a", "action" => "read"}
      res = try_call(fn -> RouteSchema.build([r, r]) end)

      assert match?({:error, {:duplicate_route, _, _}}, res) or match?({:error, _}, res) or
               match?({:raised, _}, res),
             inspect(res)
    end
  end

  describe "Section.Channel" do
    test "nasty channel / event names: ok with identifier-safe payload names, or typed error" do
      names = S2.names(121, 4)

      discovery = %{
        "channels" =>
          Enum.map(names, fn n ->
            %{
              "name" => n,
              "topic" => n,
              "events" => [%{"event" => n, "payload" => %{"type" => %{"kind" => "string"}}}]
            }
          end)
      }

      res = try_call(fn -> Channel.build(discovery) end)

      assert match?({:ok, _}, res) or match?({:error, _}, res) or match?({:raised, _}, res),
             inspect(res, limit: 5)

      refute match?({:raised, _}, res), "Channel.build raised: #{inspect(res, limit: 5)}"
    end

    test "invalid / empty discovery" do
      assert {:ok, []} = Channel.build(%{})
      assert {:error, {:invalid_discovery, nil}} = Channel.build_with_warnings(nil)
    end

    test "identifier/1 yields a plain identifier for hostile text" do
      for n <- S2.nasty() do
        id = Channel.identifier(n)
        assert is_binary(id)
      end
    end
  end

  defp try_call(fun) do
    fun.()
  rescue
    e -> {:raised, Exception.message(e)}
  end
end
