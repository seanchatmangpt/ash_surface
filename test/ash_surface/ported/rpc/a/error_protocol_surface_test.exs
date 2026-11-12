defmodule AshSurface.Ported.Rpc.A.ErrorProtocolSurfaceTest do
  @moduledoc """
  Non-actuating counterpart of `error_protocol_test.exs`. ash_surface has no `Error` protocol:
  the same raw Ash error structs are classified by `AshSurface.Errors` (private table) and
  rendered with `formatter: :snake_case` so keys compare 1:1 with the reference.

  Divergences (lawful ash_surface behaviour asserted): `vars` are derived from the error's
  `field/resource/...` slots (not a raw `vars` keyword), policy breakdown is the explicit
  `:show_policy_breakdowns` opt (the reference reads `Application.get_env(:ash_typescript,
  :policies)`), and the default handler is `AshSurface.ErrorHandler.handle_error/2`.
  """
  use ExUnit.Case, async: false

  alias AshSurface.{ErrorHandler, Errors}
  alias AshSurface.Ported, as: P
  alias AshSurface.RuntimeParity.Rpc.ErrorBuilder

  defp one(error, opts \\ []) do
    assert [result] = Errors.to_errors(error, Keyword.put_new(opts, :formatter, :snake_case))
    sym(result)
  end

  defp sym(%{} = m) when not is_struct(m),
    do: Map.new(m, fn {k, v} -> {if(is_binary(k), do: String.to_atom(k), else: k), sym(v)} end)

  defp sym(l) when is_list(l), do: Enum.map(l, &sym/1)
  defp sym(v), do: v

  defp build(error), do: error |> ErrorBuilder.build_error_response() |> sym()

  defp policy_error(policies, facts) do
    Ash.Error.Forbidden.Policy.exception(
      resource: P.Todo,
      action: :read,
      policies: policies,
      facts: facts,
      must_pass_strict_check?: false
    )
  end

  defp admin_policy do
    [
      %Ash.Policy.Policy{
        description: "Only admins can read",
        condition: [{Ash.Policy.Check.Expression, [expr: true]}],
        policies: [
          %Ash.Policy.Check{
            check: {Ash.Policy.Check.Expression, [expr: {:_actor, :role}]},
            check_module: Ash.Policy.Check.Expression,
            check_opts: [expr: {:_actor, :role}],
            type: :authorize_if
          }
        ],
        bypass?: false,
        access_type: :strict
      }
    ]
  end

  defp admin_facts do
    %{
      {Ash.Policy.Check.Expression, [expr: true]} => true,
      {Ash.Policy.Check.Expression, [expr: {:_actor, :role}]} => false
    }
  end

  describe "Error protocol implementation" do
    test "InvalidChanges error is properly transformed" do
      result =
        one(%Ash.Error.Changes.InvalidChanges{
          fields: [:field1, :field2],
          vars: [key: "value"],
          path: [:data, :attributes]
        })

      assert is_binary(result.message)
      assert result.short_message == "Invalid changes"
      assert result.type == "invalid_changes"
      assert result.fields == ["field1", "field2"]
      assert result.path == ["data", "attributes"]
    end

    test "NotFound error is properly transformed" do
      result = one(%Ash.Error.Query.NotFound{vars: [], resource: "MyResource"})

      assert is_binary(result.message)
      assert result.short_message == "Not found"
      assert result.type == "not_found"
      assert result.fields == []
    end

    test "Required field error includes field information" do
      result = one(%Ash.Error.Changes.Required{field: :email, vars: []})

      assert is_binary(result.message)
      assert result.short_message == "Required field"
      assert result.type == "required"
      assert result.vars == %{field: "email"}
      assert result.fields == ["email"]
    end

    test "Forbidden policy error returns static message by default" do
      result = one(%Ash.Error.Forbidden.Policy{vars: []})

      assert result.message == "forbidden"
      assert result.short_message == "Forbidden"
      assert result.type == "forbidden"
      assert result.fields == []
    end

    test "Forbidden policy error includes breakdown in message when breakdowns enabled" do
      result =
        one(policy_error(admin_policy(), admin_facts()), show_policy_breakdowns: true)

      assert result.message =~ "Only admins can read"
      assert result.message =~ "Policy Breakdown"
      assert result.short_message == "Forbidden"
    end

    test "Forbidden policy error does not leak breakdown when config disabled" do
      error =
        policy_error(
          [
            %Ash.Policy.Policy{
              description: "secret policy",
              condition: [{Ash.Policy.Check.Expression, [expr: true]}],
              policies: [],
              bypass?: false,
              access_type: :strict
            }
          ],
          %{{Ash.Policy.Check.Expression, [expr: true]} => true}
        )

      result = one(error, show_policy_breakdowns: false)

      assert result.message == "forbidden"
      refute result.message =~ "secret policy"
    end

    test "InvalidAttribute error includes field details" do
      result = one(%Ash.Error.Changes.InvalidAttribute{field: :age, vars: []})

      assert is_binary(result.message)
      assert result.short_message == "Invalid attribute"
      assert result.type == "invalid_attribute"
      assert result.fields == ["age"]
    end

    test "errors without path default to empty list" do
      assert one(%Ash.Error.Query.Required{field: :name, vars: []}).path == []
    end

    test "errors with path preserve it" do
      result =
        one(%Ash.Error.Changes.Required{field: :email, vars: [], path: [:user, :profile]})

      assert result.path == ["user", "profile"]
      assert result.fields == ["email"]
    end
  end

  describe "Error unwrapping" do
    test "unwraps nested Ash.Error.Invalid errors" do
      inner_error = %Ash.Error.Changes.Required{field: :title}

      assert Errors.unwrap_errors(%Ash.Error.Invalid{errors: [inner_error]}) == [inner_error]
    end

    test "unwraps deeply nested errors" do
      innermost = %Ash.Error.Changes.Required{field: :title}
      middle = %Ash.Error.Invalid{errors: [innermost]}
      outer = %Ash.Error.Forbidden{errors: [middle]}

      assert Errors.unwrap_errors(outer) == [innermost]
    end

    test "handles mixed error lists" do
      error1 = %Ash.Error.Changes.Required{field: :title}
      error2 = %Ash.Error.Changes.InvalidAttribute{field: :age}

      result = Errors.unwrap_errors([%Ash.Error.Invalid{errors: [error1, error2]}])

      assert length(result) == 2
      assert error1 in result
      assert error2 in result
    end
  end

  describe "Error processing pipeline" do
    test "processes single error through full pipeline" do
      assert [result] = %Ash.Error.Changes.Required{field: :email} |> Errors.to_errors() |> sym()

      assert is_binary(result.message)
      assert result.type == "required"
      assert result.fields == ["email"]
    end

    test "processes multiple errors" do
      results =
        [
          %Ash.Error.Changes.Required{field: :email},
          %Ash.Error.Changes.InvalidAttribute{field: :age}
        ]
        |> Errors.to_errors()
        |> sym()

      assert length(results) == 2
      codes = Enum.map(results, & &1.type)
      assert "required" in codes
      assert "invalid_attribute" in codes
    end

    @tag capture_log: true
    test "converts non-Ash errors to Ash error classes" do
      results = Errors.to_errors(%RuntimeError{message: "Something went wrong"}) |> sym()

      assert is_list(results)
      assert results != []
      assert Enum.all?(results, &(&1.type == "unknown_error"))
    end
  end

  describe "Default error handler" do
    test "returns error as-is without interpolating variables" do
      error = %{
        message: "Field %{field} must be at least %{min} characters",
        short_message: "Too short",
        vars: %{field: "password", min: 8},
        type: "validation_error"
      }

      result = ErrorHandler.handle_error(error, %{})

      assert result.message == "Field %{field} must be at least %{min} characters"
      assert result.short_message == "Too short"
      assert result.vars == %{field: "password", min: 8}
    end

    test "handles errors without variables" do
      error = %{message: "Field %{field} is invalid", short_message: "Invalid", vars: %{}}

      assert ErrorHandler.handle_error(error, %{}).message == "Field %{field} is invalid"
    end

    test "preserves error structure when no vars" do
      error = %{message: "Simple error message", short_message: "Error", code: "error"}

      assert ErrorHandler.handle_error(error, %{}) == error
    end
  end

  describe "Integration with ErrorBuilder" do
    test "ErrorBuilder uses the error table for Ash errors" do
      assert [error] = build(%Ash.Error.Query.NotFound{})

      assert error.type == "not_found"
      assert is_binary(error.message)
    end

    test "ErrorBuilder handles wrapped Ash errors" do
      wrapped = %Ash.Error.Invalid{
        class: :invalid,
        errors: [%Ash.Error.Changes.Required{field: :title}]
      }

      assert [error] = build(wrapped)
      assert error.type == "required"
      assert is_binary(error.message)
    end

    test "ErrorBuilder handles multiple errors" do
      errors = %Ash.Error.Invalid{
        class: :invalid,
        errors: [
          %Ash.Error.Changes.Required{field: :title},
          %Ash.Error.Changes.InvalidAttribute{field: :age}
        ]
      }

      result = build(errors)

      assert length(result) == 2
      assert Enum.all?(result, &is_map/1)
    end
  end

  describe "Policy breakdown in message (via show_policy_breakdowns)" do
    test "message is static when not enabled" do
      assert one(%Ash.Error.Forbidden.Policy{vars: []}).message == "forbidden"
    end

    test "message contains formatted breakdown when enabled" do
      result =
        one(policy_error(admin_policy(), admin_facts()), show_policy_breakdowns: true)

      assert result.message =~ "Only admins can read"
      assert result.message =~ "Policy Breakdown"
    end

    test "policy error with breakdown can be encoded to JSON" do
      result = one(policy_error([], %{}), show_policy_breakdowns: true)

      assert {:ok, _json} = Jason.encode(result)
    end
  end

  describe "per-error-type exact shapes (mutation-killing)" do
    test "each error struct maps to exact type, short_message, vars, fields and path" do
      cases = [
        {%Ash.Error.Changes.InvalidChanges{fields: [:a], vars: [], path: [:p]}, "invalid_changes",
         "Invalid changes", ["a"], ["p"]},
        {%Ash.Error.Query.InvalidQuery{field: :q, vars: []}, "invalid_query", "Invalid query",
         ["q"], []},
        {%Ash.Error.Query.NotFound{vars: []}, "not_found", "Not found", [], []},
        {%Ash.Error.Changes.Required{field: :email, vars: []}, "required", "Required field",
         ["email"], []},
        {%Ash.Error.Query.Required{field: :name, vars: []}, "required", "Required field",
         ["name"], []},
        {%Ash.Error.Forbidden.Policy{vars: []}, "forbidden", "Forbidden", [], []},
        {%Ash.Error.Changes.InvalidAttribute{field: :age, vars: []}, "invalid_attribute",
         "Invalid attribute", ["age"], []},
        {%Ash.Error.Changes.InvalidArgument{field: :arg, vars: []}, "invalid_argument",
         "Invalid argument", ["arg"], []},
        {%Ash.Error.Query.InvalidArgument{field: :arg, vars: []}, "invalid_argument",
         "Invalid argument", ["arg"], []},
        {%Ash.Error.Action.InvalidArgument{field: :arg, vars: []}, "invalid_argument",
         "Invalid argument", ["arg"], []}
      ]

      for {error, type, short, fields, path} <- cases do
        r = one(error)
        label = inspect(error.__struct__)
        assert {label, r.type} == {label, type}
        assert {label, r.short_message} == {label, short}
        assert {label, r.fields} == {label, fields}
        assert {label, r.path} == {label, path}
        assert is_map(r.vars)
        assert is_binary(r.message)
      end
    end

    test "vars are derived from the error's field slot" do
      assert one(%Ash.Error.Changes.Required{field: :email, vars: []}).vars == %{field: "email"}
      assert one(%Ash.Error.Changes.InvalidAttribute{field: :age, vars: []}).vars.field == "age"
      assert one(%Ash.Error.Query.NotFound{vars: []}).vars == %{}
    end
  end

  describe "classify table and bare-message path (RAX)" do
    test "exact type/short_message for each survivor-class error" do
      for {mod, type, short} <- [
            {Ash.Error.Forbidden.ForbiddenField, "forbidden_field", "Forbidden field"},
            {Ash.Error.Page.InvalidKeyset, "invalid_keyset", "Invalid keyset"},
            {Ash.Error.Query.InvalidPage, "invalid_page", "Invalid pagination"},
            {Ash.Error.Invalid.TenantRequired, "tenant_required", "Tenant required"},
            {Ash.Error.Invalid.InvalidPrimaryKey, "invalid_primary_key", "Invalid primary key"},
            {Ash.Error.Query.ReadActionRequiresActor, "forbidden", "Authentication required"}
          ] do
        assert {mod, Errors.classify(struct(mod))} == {mod, {type, short}}
        r = one(struct(mod, vars: []))
        assert {mod, r.type, r.short_message} == {mod, type, short}
      end
    end

    test "InvalidChanges with a message takes the bare-template path with merged vars" do
      r =
        one(%Ash.Error.Changes.InvalidChanges{
          message: "Bad %{key}",
          vars: [key: "v", mod: Foo.Bar.Baz]
        })

      assert r.message == "Bad %{key}"
      assert r.vars == %{key: "v", mod: "Baz"}
    end

    test "module-atom vars are scrubbed to the last segment, other atoms to strings" do
      r =
        one(%Ash.Error.Changes.InvalidAttribute{
          field: :age,
          message: "x",
          vars: [mod: Foo.Bar.Baz, plain: :sym]
        })

      assert r.vars.mod == "Baz"
      assert r.vars.plain == "sym"
    end
  end
end
