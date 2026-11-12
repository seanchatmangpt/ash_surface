Code.require_file("support/tc_support.exs", __DIR__)

defmodule AshSurface.Ported.TypedController.VerifyTypedControllerTest do
  @moduledoc """
  Port of ash_typescript typed_controller/verify_typed_controller_test.exs onto the
  descriptor-level `RouteSchema.Verifier` (typed refusals instead of Spark DslErrors).
  Per-test notes: DSL-module tests (Session compiles, module_name, generated controller
  module, fn/2 handlers) and 'missing route handler' have no counterpart: descriptors carry
  no handler (running handlers is actuation, README).
  """
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.RouteSchema
  alias AshSurface.Compiler.RouteSchema.Verifier
  alias AshSurface.Ported.TypedController.Support, as: S

  test "valid descriptors verify and build with verify: true" do
    routes = [
      S.route("login", "post", "/login", [S.arg("code"), S.arg("remember_me", "boolean")])
    ]

    assert :ok = Verifier.verify(routes)
    assert {:ok, [_]} = RouteSchema.build(routes, verify: true)
  end

  test "duplicate route names" do
    routes = [S.route("login", "post", "/a"), S.route("login", "get", "/b")]
    assert {:error, {:duplicate_route_names, ["login"]}} = Verifier.verify(routes)
    assert {:error, {:duplicate_route_names, ["login"]}} = RouteSchema.build(routes, verify: true)
  end

  test "argument with nil type" do
    routes = [S.route("test", "post", "/t", [%{"name" => "foo", "type" => nil}])]
    assert {:error, {:invalid_argument_types, [{"test", "foo"}]}} = Verifier.verify(routes)
  end

  describe "names for client generation" do
    test "underscore-number argument name, with suggestion" do
      assert {:error, {:invalid_names, [{_, "address_line_1", "address_line1"}]}} =
               Verifier.verify([S.route("t", "post", "/t", [S.arg("address_line_1")])])
    end

    test "underscore-number route name" do
      assert {:error, {:invalid_names, [{"route step_1", "step_1", "step1"}]}} =
               Verifier.verify([S.route("step_1", "get", "/s")])
    end

    test "question-mark argument name" do
      assert {:error, {:invalid_names, [{_, "is_active?", "is_active"}]}} =
               Verifier.verify([S.route("t", "post", "/t", [S.arg("is_active?", "boolean")])])
    end

    test "non-identifier name" do
      assert {:error, {:invalid_names, [{_, "foo-bar", :not_identifier}]}} =
               Verifier.verify([S.route("t", "post", "/t", [S.arg("foo-bar")])])
    end

    test "returns field names with question marks (clean field not reported)" do
      ret = %{
        "type" => %{
          "kind" => "map",
          "fields" => %{"is_active?" => %{"kind" => "boolean"}, "label" => %{"kind" => "string"}}
        }
      }

      assert {:error,
              {:invalid_field_names, [{"route status, returns field", "is_active?", "is_active"}]}} =
               Verifier.verify([S.route("status", "get", "/s", [], %{"returns" => ret})])
    end

    test "nested field names report their path" do
      ret = %{
        "type" => %{
          "kind" => "array",
          "items" => %{
            "kind" => "map",
            "fields" => %{
              "address" => %{
                "kind" => "map",
                "fields" => %{"line_1" => %{"kind" => "string"}}
              }
            }
          }
        }
      }

      assert {:error, {:invalid_field_names, [{_, "[].address.line_1", "line1"}]}} =
               Verifier.verify([S.route("items", "get", "/i", [], %{"returns" => ret})])
    end

    test "invalid field names in argument types" do
      arg =
        S.arg("opts", "map") |> put_in(["type", "fields"], %{"is_on?" => %{"kind" => "boolean"}})

      assert {:error,
              {:invalid_field_names, [{"route save, argument opts field", "is_on?", "is_on"}]}} =
               Verifier.verify([S.route("save", "post", "/s", [arg])])
    end
  end
end
