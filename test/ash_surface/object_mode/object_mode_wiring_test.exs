defmodule AshSurface.ObjectMode.WiringTest do
  use ExUnit.Case, async: false

  alias AshSurface.Compiler.{CalculationSchema, EmbeddedSchema, RelationshipSchema}
  alias AshSurface.Projectors.JS.ZodGuard
  alias AshSurface.ZodFixtures.HarnessExt

  # strict rejects the unknown key; passthrough keeps it; strip drops it.
  @modes [strict: {false, false}, passthrough: {true, true}, strip: {true, false}]

  defp assert_modes!(render, payload) do
    for {mode, {accepts, keeps}} <- @modes do
      zod = render.(mode)
      assert {:ok, _, _} = ZodGuard.admit(zod)

      keep = "(#{zod}).refine((v) => \"zzz\" in v)"

      assert [%{"success" => ^accepts}] =
               HarnessExt.run_fragment!(zod, [
                 %{label: "accept", expect: accepts, payload: payload}
               ]),
             "#{mode} accept"

      assert [%{"success" => ^keeps}] =
               HarnessExt.run_fragment!(keep, [%{label: "keep", expect: keeps, payload: payload}]),
             "#{mode} keep"
    end
  end

  defp rel do
    %{
      "name" => "c",
      "destination" => "C",
      "cardinality" => "many",
      "pagination" => "offset",
      "primitive_fields" => ["id"]
    }
  end

  test "default (unset) output is byte-identical: .strict() at every wired site" do
    assert {:ok, e} = EmbeddedSchema.render(embedded())
    assert String.ends_with?(e, "}).strict()")
    assert {:ok, r} = RelationshipSchema.render_load_object([rel()])
    assert String.ends_with?(r, "}).strict()")
    assert {:ok, c} = CalculationSchema.render_calculation_schema([calc()])
    assert String.ends_with?(c, "}).strict()")
    refute r =~ ".passthrough()"
    assert r == elem(RelationshipSchema.render_load_object([rel()], object_mode: nil), 1)
  end

  defp embedded do
    %{
      "type" => %{
        "kind" => "typed_map",
        "fields" => [%{"name" => "a", "type" => %{"kind" => "string"}}]
      }
    }
  end

  defp calc,
    do: %{
      name: "full",
      arguments: [%{name: "sep", kind: :string, constraints: %{}}],
      return_kind: :string,
      fields: ["a"]
    }

  test "embedded_schema container honors object_mode under node+zod" do
    assert_modes!(
      fn m -> elem(EmbeddedSchema.render(embedded(), object_mode: m), 1) end,
      %{"a" => "x", "zzz" => 1}
    )
  end

  test "relationship load object honors object_mode (top level) under node+zod" do
    assert_modes!(
      fn m -> elem(RelationshipSchema.render_load_object([rel()], object_mode: m), 1) end,
      %{"c" => true, "zzz" => 1}
    )
  end

  test "relationship per-relationship envelope honors object_mode under node+zod" do
    for {mode, {accepts, _}} <- @modes do
      {:ok, zod} = RelationshipSchema.render_load_object([rel()], object_mode: mode)

      assert [%{"success" => ^accepts}] =
               HarnessExt.run_fragment!(zod, [
                 %{
                   label: "env",
                   expect: accepts,
                   payload: %{"c" => %{"fields" => ["id"], "zzz" => 1}}
                 }
               ])
    end
  end

  test "calculation schema honors object_mode (outer, per-calc, args) under node+zod" do
    render = fn m ->
      elem(CalculationSchema.render_calculation_schema([calc()], object_mode: m), 1)
    end

    assert_modes!(render, %{"full" => %{"args" => %{"sep" => "x"}}, "zzz" => 1})

    for {mode, {accepts, _}} <- @modes do
      zod = render.(mode)

      for payload <- [
            %{"full" => %{"args" => %{"sep" => "x"}, "zzz" => 1}},
            %{"full" => %{"args" => %{"sep" => "x", "zzz" => 1}}}
          ] do
        assert [%{"success" => ^accepts}] =
                 HarnessExt.run_fragment!(zod, [%{label: "n", expect: accepts, payload: payload}])
      end
    end
  end
end
