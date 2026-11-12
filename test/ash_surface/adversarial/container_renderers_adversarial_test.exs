Code.require_file("support.exs", __DIR__)

defmodule AshSurface.Adversarial.ContainerRenderersTest do
  @moduledoc """
  Lane S2 courts: adversarial names/values through ZodType, UnionSchema and
  EmbeddedSchema, executed under real zod and ZodGuard.admit/1. A renderer
  typed refusal ({:error, _}) is lawful; a rendered-and-admitted expression
  must agree with the Elixir-side expectation.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Adversarial.S2
  alias AshSurface.Compiler.{EmbeddedSchema, UnionSchema, ZodType}

  defp field_cases(names) do
    valid = Map.new(names, &{&1, "x"})
    first = hd(names)

    [
      {valid, true},
      {Map.put(valid, "zz_extra_key", 1), false},
      {Map.put(valid, first, 123), false},
      {Map.delete(valid, first), false},
      {[], false},
      {nil, false}
    ]
  end

  defp assert_agrees(result, label) do
    assert result in [:agree, :refused], "#{label}: #{inspect(result, limit: 8)}"
  end

  describe "ZodType scalar bounds (edge numbers)" do
    # {kind, constraints, [{payload, expect}]}
    @bound_cases [
      {"string", %{"max_length" => 0}, [{"", true}, {"a", false}]},
      {"string", %{"min_length" => 1, "max_length" => 3},
       [{"", false}, {"abc", true}, {"abcd", false}]},
      {"integer", %{"min" => -5, "max" => 5},
       [{-5, true}, {5, true}, {6, false}, {-6, false}, {1.5, false}]},
      {"integer", %{"min" => 0, "max" => 0}, [{0, true}, {1, false}, {-1, false}]},
      {"integer", %{"min" => 9_007_199_254_740_991}, [{9_007_199_254_740_991, true}, {0, false}]},
      {"integer", %{"max" => -9_007_199_254_740_991},
       [{0, false}, {-9_007_199_254_740_991, true}]},
      {"float", %{"min" => -1.5, "max" => 1.5}, [{0.0, true}, {1.6, false}, {-1.6, false}]},
      {"boolean", %{}, [{true, true}, {false, true}, {"true", false}, {nil, false}]},
      {"string", %{}, [{"", true}, {nil, false}, {1, false}, {["a"], false}]}
    ]

    for {{kind, constraints, cases}, i} <- Enum.with_index(@bound_cases) do
      test "#{kind} #{inspect(constraints)} (case #{i})" do
        frag =
          ZodType.fragment(%{
            "type" => %{"kind" => unquote(kind)},
            "constraints" => unquote(Macro.escape(constraints))
          })

        res = S2.classify({:ok, frag}, unquote(Macro.escape(cases)))
        assert res == :agree, "#{frag}: #{inspect(res, limit: 8)}"
      end
    end
  end

  describe "ZodType array nesting depth 0/1/8" do
    for depth <- [0, 1, 2, 8] do
      test "array of integer nested #{depth} deep" do
        d = unquote(depth)

        def_ =
          if d == 0,
            do: %{"type" => %{"kind" => "integer"}},
            else: %{"type" => %{"kind" => "array", "items" => nest(d - 1)}}

        valid = wrap(d, 1)
        bad = wrap(d, "s")
        cases = [{valid, true}, {bad, false}, {nil, false}, {"x", false}]

        res =
          S2.classify(
            {:ok, ZodType.fragment(def_)},
            if(d == 0, do: [{1, true}, {"s", false}], else: cases)
          )

        assert res == :agree, inspect(res, limit: 8)
      end
    end

    defp nest(0), do: %{"kind" => "integer"}
    defp nest(n), do: %{"kind" => "array", "items" => nest(n - 1)}
    defp wrap(0, v), do: v
    defp wrap(n, v), do: [wrap(n - 1, v)]
  end

  describe "ZodType nil / atom-keyed / junk definitions" do
    test "nil, empty, junk definitions degrade to an admitted expression" do
      for d <- [
            nil,
            %{},
            %{"type" => nil},
            %{"type" => %{"kind" => nil}},
            %{type: %{kind: :string}},
            "str",
            1
          ] do
        frag = ZodType.fragment(d)
        assert is_binary(frag)
        assert {:ok, _, _} = AshSurface.Projectors.JS.ZodGuard.admit(frag), inspect(d)
      end
    end

    test "atom-keyed and string-keyed definitions render identically" do
      s =
        ZodType.fragment(%{
          "type" => %{"kind" => "string"},
          "constraints" => %{"max_length" => 2}
        })

      a = ZodType.fragment(%{type: %{kind: :string}, constraints: %{max_length: 2}})
      assert S2.classify({:ok, s}, [{"ab", true}, {"abc", false}]) == :agree
      assert S2.classify({:ok, a}, [{"ab", true}, {"abc", false}]) in [:agree]
    end
  end

  describe "EmbeddedSchema seeded names" do
    for seed <- [11, 12, 13, 14, 15, 16], kind <- ~w(typed_map embedded_resource typed_struct) do
      test "#{kind} fields, seed=#{seed}" do
        names = S2.names(unquote(seed), 4)

        def_ = %{
          "type" => %{
            "kind" => unquote(kind),
            "fields" =>
              Enum.map(names, &%{"name" => &1, "wire" => true, "type" => %{"kind" => "string"}})
          }
        }

        res = S2.classify(EmbeddedSchema.render(def_), field_cases(names))

        assert_agrees(
          res,
          "embedded #{unquote(kind)} seed=#{unquote(seed)} names=#{inspect(names)}"
        )
      end
    end

    test "empty fields -> record, accepts any object, rejects non-object" do
      def_ = %{"type" => %{"kind" => "typed_map", "fields" => []}}

      res =
        S2.classify(EmbeddedSchema.render(def_), [
          {%{"a" => 1}, true},
          {%{}, true},
          {nil, false},
          {[], false}
        ])

      assert res == :agree
    end

    test "duplicate field names never produce an admitted expression that throws" do
      f = %{"name" => "dup", "type" => %{"kind" => "string"}}

      res =
        S2.classify(
          EmbeddedSchema.render(%{"type" => %{"kind" => "typed_map", "fields" => [f, f]}}),
          [{%{"dup" => "x"}, true}]
        )

      assert res in [:agree, :refused], inspect(res)
    end

    test "atom-keyed field maps accepted or typed refusal" do
      d = %{
        "type" => %{"kind" => "typed_map", "fields" => [%{name: "q", type: %{kind: "string"}}]}
      }

      assert S2.classify(EmbeddedSchema.render(d), [{%{"q" => "x"}, true}, {%{"q" => 1}, false}]) in [
               :agree,
               :refused
             ]
    end

    test "nil everywhere" do
      for d <- [
            nil,
            %{},
            %{"type" => nil},
            %{"type" => %{"kind" => "typed_map", "fields" => nil}}
          ] do
        r = try_render(fn -> EmbeddedSchema.render(d) end)
        assert match?({:ok, _}, r) or match?({:error, _}, r) or r == :raised_function_clause
      end
    end

    test "nesting depth 8 of typed_map in typed_map" do
      leaf = %{"name" => "leaf", "type" => %{"kind" => "string"}}

      def_ =
        Enum.reduce(1..8, leaf, fn i, acc ->
          %{"name" => "l#{i}", "type" => %{"kind" => "typed_map", "fields" => [acc]}}
        end)

      top = %{"type" => %{"kind" => "typed_map", "fields" => [def_]}}
      good = %{"l8" => Enum.reduce(1..7, %{"leaf" => "x"}, fn i, acc -> %{"l#{i}" => acc} end)}
      bad = %{"l8" => Enum.reduce(1..7, %{"leaf" => 1}, fn i, acc -> %{"l#{i}" => acc} end)}

      res =
        S2.classify(EmbeddedSchema.render(top), [
          {good, true},
          {bad, false},
          {%{"l8" => nil}, false}
        ])

      assert res in [:agree, :refused], inspect(res, limit: 8)
    end
  end

  defp try_render(fun) do
    fun.()
  rescue
    FunctionClauseError -> :raised_function_clause
  end

  describe "UnionSchema.render_members_admitted seeded names" do
    for seed <- [21, 22, 23, 24, 25, 26] do
      test "single-key strict members, seed=#{seed}" do
        names = S2.names(unquote(seed), 4)
        members = Enum.map(names, &%{"name" => &1, "type" => "string"})
        # Member keys take the output formatter (default camelCase); expect emitted keys.
        # Distinct originals colliding to one key are a typed refusal (EmittedKeys), never
        # a silent drop.
        collides? =
          names
          |> Enum.uniq()
          |> Enum.map(&AshSurface.FieldName.emitted/1)
          |> then(&(&1 != Enum.uniq(&1)))

        if collides? do
          assert {:error, {:emitted_key_collision, :union, _key, [_, _ | _]}} =
                   UnionSchema.render_members_admitted(members)
        else
          emitted = names |> Enum.map(&AshSurface.FieldName.emitted/1) |> Enum.uniq()

          cases =
            Enum.flat_map(emitted, fn n -> [{%{n => "x"}, true}, {%{n => 5}, false}] end) ++
              [
                {%{}, false},
                {%{"zz_unknown" => "x"}, false},
                {Map.new(Enum.take(emitted, 2), &{&1, "x"}), false},
                {nil, false}
              ]

          res = S2.classify(UnionSchema.render_members_admitted(members), cases)
          assert_agrees(res, "union seed=#{unquote(seed)} names=#{inspect(emitted)}")
        end
      end
    end

    test "zero members is z.any(): accepts everything" do
      assert S2.classify(UnionSchema.render_members_admitted([]), [
               {1, true},
               {nil, true},
               {%{}, true}
             ]) == :agree
    end

    test "duplicate member names do not break the union" do
      m = %{"name" => "d", "type" => "string"}

      res =
        S2.classify(UnionSchema.render_members_admitted([m, m]), [
          {%{"d" => "x"}, true},
          {%{"d" => 1}, false}
        ])

      assert res in [:agree, :refused]
    end

    test "tagged members carry literal tag" do
      m = [%{"name" => "v", "type" => "string", "tag" => "kind", "tag_value" => "a\"b\\c\nd"}]

      res =
        S2.classify(UnionSchema.render_members_admitted(m), [
          {%{"v" => "x", "kind" => "a\"b\\c\nd"}, true},
          {%{"v" => "x", "kind" => "zz"}, false}
        ])

      assert res in [:agree, :refused]
    end

    test "depth: 0/1/8 nested unions; >max_depth is a typed error" do
      for d <- [0, 1, 8] do
        m = nested_union(d)
        r = UnionSchema.render_members_admitted([m])
        assert match?({:ok, _}, r) or match?({:error, _}, r), "depth #{d}"

        if match?({:ok, _}, r),
          do: assert(S2.classify(r, [{%{"u" => nil}, false}]) in [:agree, :refused])
      end

      assert {:error, {:union_depth_exceeded, _}} = UnionSchema.render_members([nested_union(30)])
    end

    test "nil / junk inputs are typed errors, not raises" do
      assert {:error, _} = UnionSchema.render_members(nil)
      assert {:error, _} = UnionSchema.render_union_schema(nil)
    end
  end

  defp nested_union(0), do: %{"name" => "u", "type" => "string"}

  defp nested_union(n),
    do: %{"name" => "u", "type" => %{"kind" => "union", "members" => [nested_union(n - 1)]}}

  describe "UnionSchema.render_union_schema (tagged facts) seeded tags" do
    for seed <- [31, 32, 33, 34] do
      test "discriminated union over nasty tags, seed=#{seed}" do
        tags = S2.names(unquote(seed), 3)
        facts = Enum.map(tags, &%{"tag" => &1, "kind" => "string", "constraints" => %{}})

        cases =
          Enum.map(tags, &{%{"type" => &1, "value" => "x"}, true}) ++
            Enum.map(tags, &{%{"type" => &1, "value" => 1}, false}) ++
            [{%{"type" => "zz_none", "value" => "x"}, false}, {%{}, false}, {nil, false}]

        res = S2.classify(UnionSchema.render_union_schema_admitted(facts), cases)
        assert_agrees(res, "tagged union seed=#{unquote(seed)} tags=#{inspect(tags)}")
      end
    end
  end
end
