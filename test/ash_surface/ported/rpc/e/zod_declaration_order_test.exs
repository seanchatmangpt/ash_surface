Code.require_file("support/e.exs", __DIR__)

defmodule AshSurface.Ported.Rpc.E.ZodDeclarationOrderTest do
  @moduledoc """
  Adaptation of ash_typescript `rpc/zod_declaration_order_test.exs` (9 tests).

  Reference law: JS `const` is not hoisted, so a resource schema must be declared before it is
  referenced; `generate_zod_schemas_for_resources/1` topologically sorts. ash_surface hoists
  shared embedded schemas as top-level consts and breaks dependency edges with lazy getters
  (`get detail() { return ... }`), so declaration order cannot cause a TDZ error at all (a
  better law, witnessed here by real node evaluation). Each test therefore asserts (1) no eager
  forward reference in the generated text and (2) the artifact loads and parses nested payloads
  under real node + real zod, over the ZodOrder diamond (A->B,C->D->E, D also `{:array, E}`)
  projected through `AshSurface.Ported.E.Fixtures.*Holder` resources (the reference calls the
  generator on bare embedded resources; ash_surface projects embedded resources through the
  action input that embeds them).
  """
  use ExUnit.Case, async: true

  alias AshSurface.Ported.E

  @domain AshSurface.Ported.E.Fixtures.Domain

  @payload %{
    "root" => %{
      "left" => %{
        "title" => "b",
        "settings" => %{
          "label" => "d",
          "detail" => %{"value" => "e"},
          "items" => [%{"value" => "e1"}, %{"value" => "e2"}]
        }
      },
      "right" => %{"name" => "c", "config" => %{"label" => "d2"}}
    },
    "leaf" => %{"value" => "x"}
  }

  # Declared consts (`const X = ...` at column 0) in file order.
  defp declarations(art) do
    ~r/^(?:export )?const (\w+ZodSchema) = /m
    |> Regex.scan(art, return: :index)
    |> Enum.map(fn [_, {s, l}] -> {binary_part(art, s, l), s} end)
  end

  # Positions of references to `name` that are EAGER: not inside a `get x() { return ... }`.
  defp eager_reference_positions(art, name) do
    Regex.scan(~r/\b#{name}\b/, art, return: :index)
    |> Enum.map(fn [{s, _}] -> s end)
    |> Enum.reject(fn pos ->
      before = binary_part(art, max(pos - 60, 0), min(60, pos))
      Regex.match?(~r/get \w+\(\)\s*\{\s*return [^\n]*$/, before)
    end)
  end

  defp assert_no_eager_forward_references(art) do
    decls = declarations(art)
    assert decls != [], "expected hoisted ZodSchema consts"

    for {name, decl_pos} <- decls, pos <- eager_reference_positions(art, name), pos != decl_pos do
      # the declaration line itself defines the name; every other eager use must follow it
      assert decl_pos < pos,
             "#{name} is referenced eagerly at #{pos} but declared at #{decl_pos}"
    end

    :ok
  end

  defp node_ok(art, payload) do
    assert [true] == E.node_accepts(art, [{"OrderHolder_create_schema", payload}])
  end

  describe "diamond dependency graph (A->B->D->E, A->C->D->E)" do
    test "leaf nodes are declared before nodes that reference them (or referenced lazily)" do
      art = E.artifact!([@domain])
      names = Enum.map(declarations(art), &elem(&1, 0))

      assert "AshSurface_Ported_ZodOrder_NodeEZodSchema" in names
      assert "AshSurface_Ported_ZodOrder_NodeDZodSchema" in names

      # NodeD references NodeE only through lazy getters: no eager edge exists
      assert eager_reference_positions(art, "AshSurface_Ported_ZodOrder_NodeEZodSchema")
             |> Enum.all?(fn pos ->
               {_, e_decl} =
                 Enum.find(
                   declarations(art),
                   &(elem(&1, 0) == "AshSurface_Ported_ZodOrder_NodeEZodSchema")
                 )

               pos == e_decl
             end)

      node_ok(art, @payload)
    end

    test "all references appear after their declarations (no eager forward reference)" do
      art = E.artifact!([@domain])
      assert_no_eager_forward_references(art)
      node_ok(art, @payload)
    end

    test "order is correct regardless of input order" do
      irs = E.irs([@domain])

      for ir_order <- [irs, Enum.reverse(irs), Enum.shuffle(irs), Enum.shuffle(irs)] do
        art = E.artifact_from_irs!(ir_order)
        assert_no_eager_forward_references(art)
        node_ok(art, @payload)
      end
    end

    test "array-wrapped dependencies are detected" do
      art = E.artifact!([@domain])

      assert art =~
               ~r/get items\(\) \{ return z\.array\(AshSurface_Ported_ZodOrder_NodeEZodSchema\)/

      node_ok(art, @payload)

      bad = put_in(@payload, ["root", "left", "settings", "items"], [%{"value" => ""}])
      assert [false] == E.node_accepts(art, [{"OrderHolder_create_schema", bad}])
    end
  end

  describe "simple dependency (NestedProfile -> Profile)" do
    test "dependency parses nested payloads regardless of declaration order" do
      art = E.artifact!([@domain])
      block = AshSurface.Ported.E.Zod.block!(art, "OrderMixedHolder_create_schema")
      assert block =~ "nested_profile:"
      assert block =~ "detail_profile"

      assert [true, false] ==
               E.node_accepts(art, [
                 {"OrderMixedHolder_create_schema",
                  %{
                    "nested_profile" => %{
                      "section_name" => "s",
                      "detail_profile" => %{"display_name" => "n"}
                    }
                  }},
                 {"OrderMixedHolder_create_schema",
                  %{
                    "nested_profile" => %{
                      "section_name" => "s",
                      "detail_profile" => %{"display_name" => ""}
                    }
                  }}
               ])
    end
  end

  describe "independent resources" do
    test "all schemas are generated" do
      art = E.artifact!([@domain])
      block = AshSurface.Ported.E.Zod.block!(art, "OrderMixedHolder_create_schema")
      assert block =~ "task_metadata:"
      assert block =~ "todo_metadata:"

      assert [true] ==
               E.node_accepts(art, [
                 {"OrderMixedHolder_create_schema",
                  %{
                    "task_metadata" => %{"createdBy" => "me"},
                    "todo_metadata" => %{"category" => "c"}
                  }}
               ])
    end
  end

  describe "mixed dependent and independent resources" do
    test "all references appear after declarations in a large mixed set" do
      art = E.artifact!([@domain])
      assert_no_eager_forward_references(art)

      assert [true, true] ==
               E.node_accepts(art, [
                 {"OrderHolder_create_schema", @payload},
                 {"OrderMixedHolder_create_schema",
                  %{
                    "link" => %{"url" => "https://x.io"},
                    "task_metadata" => %{"createdBy" => "me"}
                  }}
               ])
    end
  end

  describe "subset of dependency chain" do
    test "partial chain still orders correctly" do
      art = E.artifact!([@domain])
      assert_no_eager_forward_references(art)

      # NodeD (and NodeE) used alone beneath B: a payload carrying only settings parses
      only_d = %{"root" => %{"left" => %{"title" => "b", "settings" => %{"label" => "d"}}}}
      node_ok(art, only_d)
    end

    test "missing dependencies in the payload do not break parsing" do
      art = E.artifact!([@domain])
      node_ok(art, %{"leaf" => %{"value" => "e"}})
      node_ok(art, %{})
    end
  end
end
