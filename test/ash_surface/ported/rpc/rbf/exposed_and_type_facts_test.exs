defmodule AshSurface.Ported.Rpc.Rbf.Emb do
  @moduledoc "Own embedded resource fixture (RBO isolation: no cross-file dependency on rbb)."
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute(:a, :integer, public?: true)
  end
end

defmodule AshSurface.Ported.Rpc.Rbf.ExposedAndTypeFactsTest do
  @moduledoc "Lane RBF: pins `Errors.exposed/1` vars and TypeFacts `resource?` on struct types."
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.TypeFacts
  alias AshSurface.Errors

  defmodule FieldedError do
    defexception [:message, :field, :key, :count, :value]
  end

  describe "exposed (show_raised_errors: true) vars" do
    test "raw exception with known var keys exposes message, empty vars, empty details" do
      err = %FieldedError{message: "boom", field: :f, key: "k", count: 3, value: 1}
      [out] = Errors.to_errors(err, show_raised_errors: true)

      assert out == %{
               "message" => "** (AshSurface.Ported.Rpc.Rbf.ExposedAndTypeFactsTest.FieldedError) boom",
               "shortMessage" => "Unknown error",
               "type" => "unknown_error",
               "vars" => %{},
               "fields" => [],
               "path" => [],
               "details" => %{}
             }
    end

    test "plain RuntimeError exposes empty vars" do
      [out] = Errors.to_errors(RuntimeError.exception("secret"), show_raised_errors: true)
      assert out["vars"] == %{}
      assert out["message"] == "** (RuntimeError) secret"
      assert out["fields"] == []
    end

    test "UnknownError wrapping is exposed with empty vars" do
      err = Ash.Error.Unknown.UnknownError.exception(error: "kaboom")
      [out] = Errors.to_errors(err, show_raised_errors: true)
      assert out["vars"] == %{}
      assert out["type"] == "unknown_error"
      assert out["message"] == "kaboom"
    end
  end

  describe "known error vars (contrast)" do
    test "InvalidKeyset carries its key" do
      err = Ash.Error.Page.InvalidKeyset.exception(value: "zzz")
      [out] = Errors.to_errors(err)
      assert out["type"] == "invalid_keyset"
      assert out["vars"] == %{"value" => "zzz"}
    end

    test "ForbiddenField carries field and resource" do
      err = Ash.Error.Forbidden.ForbiddenField.exception(field: :secret, resource: Date)
      [out] = Errors.to_errors(err)
      assert out["type"] == "forbidden_field"
      assert out["vars"] == %{"field" => "secret", "resource" => "Date"}
      assert out["fields"] == ["secret"]
    end

    test "InvalidPage carries no vars when it has no scalar facts" do
      err = Ash.Error.Query.InvalidPage.exception(page: 1)
      [out] = Errors.to_errors(err)
      assert out["type"] == "invalid_page"
      assert out["vars"] == %{}
    end
  end

  describe "TypeFacts resource? on struct" do
    test "struct with non-resource instance_of is resource? false" do
      %{definition: %{"type" => t}} =
        TypeFacts.analyze(Ash.Type.Struct, instance_of: Date)

      assert t["kind"] == "struct"
      assert t["instance_of"] == "Date"
      assert t["resource?"] == false
    end

    test "struct without instance_of carries no resource? fact" do
      %{definition: %{"type" => t}} = TypeFacts.analyze(Ash.Type.Struct, [])
      assert t["kind"] == "struct"
      refute Map.has_key?(t, "resource?")
    end

    test "struct argument naming an undefined module stays kind struct, resource? false" do
      %{definition: %{"type" => t}} =
        TypeFacts.analyze(Ash.Type.Struct, instance_of: AshSurface.Ported.Rpc.Rbf.NotDefined)

      assert t["kind"] == "struct"
      assert t["instance_of"] == "AshSurface.Ported.Rpc.Rbf.NotDefined"
      assert t["resource?"] == false
    end

    test "struct argument naming a real embedded resource is classified embedded_resource" do
      %{definition: %{"type" => t}} =
        TypeFacts.analyze(Ash.Type.Struct, instance_of: AshSurface.Ported.Rpc.Rbf.Emb)

      assert t["kind"] == "embedded_resource"
      assert t["instance_of"] == "AshSurface.Ported.Rpc.Rbf.Emb"
    end
  end
end
