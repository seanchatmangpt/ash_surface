defmodule AshSurface.F1eErrCfgTest.Person do
  @moduledoc false
  use Ash.Resource,
    domain: nil,
    data_layer: Ash.DataLayer.Simple,
    extensions: [AshSurface.Resource]

  attributes do
    uuid_primary_key(:id, public?: true)
    attribute(:active?, :boolean, public?: true)
    attribute(:last_name, :string, public?: true)
  end

  actions do
    defaults([:read])
  end

  surface do
    projection(:read)
    field_names(active?: "isActive")
  end
end

defmodule AshSurface.F1eErrCfgTest do
  use ExUnit.Case, async: false

  alias AshSurface.Compiler.{ErrorSchema, IdentitySchema, ObjectMode}
  alias AshSurface.Errors
  alias AshSurface.F1eErrCfgTest.Person
  alias AshSurface.ZodFixtures.HarnessExt

  defp invalid(field),
    do: Ash.Error.Changes.InvalidAttribute.exception(field: field, message: "bad")

  describe "field_names in Errors" do
    test "resource field_names map fields/path/vars.field; unmapped use the formatter" do
      err =
        Ash.Error.Invalid.exception(
          errors: [
            Map.put(invalid(:active?), :path, [:active?]),
            Map.put(invalid(:last_name), :path, [:last_name])
          ]
        )

      [a, b] = Errors.to_errors(err, resource: Person)
      assert a["fields"] == ["isActive"]
      assert a["path"] == ["isActive"]
      assert a["vars"]["field"] == "isActive"
      assert b["fields"] == ["lastName"]
      assert b["vars"]["field"] == "lastName"
    end

    test "explicit :field_names opt wins and no mapping leaves output untouched" do
      [m] = Errors.to_errors(invalid(:last_name), field_names: %{last_name: "surname"})
      assert m["fields"] == ["surname"]
      [u] = Errors.to_errors(invalid(:active?))
      assert u["fields"] == ["active?"]
    end
  end

  describe "ash_error? passthrough guard" do
    test "non-table Ash error structs yield the generic UUID error, never their content" do
      for err <- [
            Ash.Error.Framework.AssumptionFailed.exception(message: "secret internals"),
            Ash.Error.Unknown.UnknownError.exception(error: "secret internals")
          ] do
        [out] = Errors.to_errors(err, show_raised_errors: false)
        assert out["type"] == "unknown_error"
        assert out["details"]["errorId"] =~ ~r/^[0-9a-f-]{36}$/
        refute inspect(out) =~ "secret internals"
      end
    end
  end

  describe "ObjectMode" do
    test "suffix per mode" do
      assert ObjectMode.suffix(:strict) == ".strict()"
      assert ObjectMode.suffix(:passthrough) == ".passthrough()"
      assert ObjectMode.suffix(:strip) == ""
      assert ObjectMode.suffix() == ""
    end

    test "default ErrorSchema output unchanged; explicit mode applies and executes" do
      assert ErrorSchema.base() =~ ").passthrough()"
      assert ErrorSchema.field_errors(["a"]) =~ ").strict()"

      payload = %{
        "message" => "m",
        "shortMessage" => "s",
        "vars" => %{},
        "fields" => [],
        "path" => [],
        "extra" => 1
      }

      for {mode, expect} <- [strict: false, passthrough: true, strip: true] do
        res =
          HarnessExt.run_fragment!(ErrorSchema.base(object_mode: mode), [
            %{label: "extra", expect: expect, payload: payload}
          ])

        assert [%{"success" => ^expect}] = res
      end
    end

    test "identity get schema honors explicit object mode under node+zod" do
      ids = [%{"name" => "e", "keys" => [%{"name" => "e-mail", "type" => %{"kind" => "string"}}]}]
      pl = %{"e-mail" => "a", "x" => 1}

      for {mode, expect} <- [strict: false, passthrough: true, strip: true] do
        {:ok, %{"e" => zod}} = IdentitySchema.render_get_schema(ids, [], object_mode: mode)

        assert [%{"success" => ^expect}] =
                 HarnessExt.run_fragment!(zod, [%{label: "x", expect: expect, payload: pl}])
      end
    end
  end

  describe "tenant require_tenant_parameters" do
    test "default (Config false) optional; true required; executes under node+zod" do
      mt = %{"strategy" => "attribute"}
      {:ok, opt} = IdentitySchema.render_tenant_schema(mt)
      {:ok, req} = IdentitySchema.render_tenant_schema(mt, true)
      assert opt == "z.string().min(1).optional()"
      assert req == "z.string().min(1)"

      [o] =
        HarnessExt.run_fragment!("z.object({tenant: #{opt}})", [
          %{label: "undef", expect: true, payload: %{}}
        ])

      [r] =
        HarnessExt.run_fragment!("z.object({tenant: #{req}})", [
          %{label: "undef", expect: false, payload: %{}}
        ])

      assert o["success"] == true
      assert r["success"] == false
    end
  end
end
