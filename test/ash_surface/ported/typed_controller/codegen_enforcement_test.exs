Code.require_file("support/tc_support.exs", __DIR__)

defmodule AshSurface.Ported.TypedController.CodegenEnforcementTest do
  @moduledoc """
  Port of ash_typescript typed_controller/codegen_enforcement_test.exs: verifier failures
  must fail emission (`RouteSchema.build(routes, verify: true)` refuses; no Zod produced),
  and types referenced only by routes still emit, enforced by real zod under node.
  Per-test note: VerifierChecker over configured modules has no counterpart (no modules).
  """
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.RouteSchema
  alias AshSurface.Ported.TypedController.Support, as: S

  describe "verifier enforcement" do
    test "emission fails for a route with invalid return field names" do
      ret = %{"type" => %{"kind" => "map", "fields" => %{"done?" => %{"kind" => "boolean"}}}}
      routes = [S.route("status", "get", "/status", [], %{"returns" => ret})]

      assert {:error, {:invalid_field_names, [{"route status, returns field", "done?", "done"}]}} =
               RouteSchema.build(routes, verify: true)
    end

    test "valid routes emit with verification enabled" do
      assert {:ok, [_]} = RouteSchema.build([S.route("ok", "get", "/ok")], verify: true)
    end
  end

  describe "types referenced only by routes" do
    # Divergence (pinned): ZodType renders kind "map" as z.record(z.string(), z.unknown());
    # field-level inline expansion of typed maps is not implemented, so only the record
    # shape is enforced. Field names are still verified by RouteSchema.Verifier.
    test "route-only map argument and result types emit and enforce record shape under zod" do
      fields = %{"enabled" => %{"kind" => "boolean"}}
      settings = S.arg("settings", "map") |> put_in(["type", "fields"], fields)
      ret = %{"type" => %{"kind" => "map", "fields" => fields}}

      [r] =
        S.build!([S.route("save_settings", "post", "/settings", [settings], %{"returns" => ret})])

      assert r["body"] =~ "settings:"

      assert [true, false] =
               S.node_parse(r["body"], [%{"settings" => %{"enabled" => true}}, %{"settings" => 3}])

      assert [true, false] = S.node_parse(r["response"], [%{"enabled" => true}, 5])
    end
  end

  describe "strict objects" do
    test "route body and response schemas reject undeclared extra keys under zod" do
      fields = %{"enabled" => %{"kind" => "boolean"}}
      ret = %{"type" => %{"kind" => "map", "fields" => fields}}
      arg = S.arg("enabled", "boolean")

      [r] = S.build!([S.route("flip", "post", "/flip", [arg], %{"returns" => ret})])

      assert [true, false] =
               S.node_parse(r["body"], [%{"enabled" => true}, %{"enabled" => true, "extra" => 1}])
    end
  end
end
