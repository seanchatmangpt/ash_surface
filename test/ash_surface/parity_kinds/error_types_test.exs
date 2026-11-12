defmodule AshSurface.ParityKinds.ErrorTypesTest do
  @moduledoc """
  Per-type courts for the 13 `error.type.*` parity ids: the REAL wire output of
  `AshSurface.Errors.to_errors/2` for a real Ash error struct (hand-written expected
  table, ref ~/ash_typescript Rpc.Error impls), and the ErrorSchema variant for that type
  parsing the wire output under real zod (valid accepted, wrong type literal rejected).
  """
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias AshSurface.Compiler.ErrorSchema

  @runner Path.expand("../../ts/kinds_runner.mjs", __DIR__)
  @uuid ~r/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/

  # type => {error struct, short_message, fields, vars}
  @cases %{
    "forbidden" => {%Ash.Error.Forbidden.Policy{}, "Forbidden", [], %{}},
    "forbidden_field" =>
      {%Ash.Error.Forbidden.ForbiddenField{field: :secret, resource: Foo.Bar}, "Forbidden field",
       ["secret"], %{"field" => "secret", "resource" => "Bar"}},
    "invalid_argument" =>
      {%Ash.Error.Changes.InvalidArgument{field: :a, message: "bad"}, "Invalid argument", ["a"],
       %{"field" => "a"}},
    "invalid_attribute" =>
      {%Ash.Error.Changes.InvalidAttribute{field: :name, message: "bad"}, "Invalid attribute",
       ["name"], %{"field" => "name"}},
    "invalid_changes" =>
      {%Ash.Error.Changes.InvalidChanges{fields: [:a], message: "x"}, "Invalid changes", ["a"],
       %{}},
    "invalid_keyset" =>
      {%Ash.Error.Page.InvalidKeyset{value: "zz"}, "Invalid keyset", [], %{"value" => "zz"}},
    "invalid_page" => {%Ash.Error.Query.InvalidPage{page: 1}, "Invalid pagination", [], %{}},
    "invalid_primary_key" =>
      {%Ash.Error.Invalid.InvalidPrimaryKey{resource: Foo.Bar, value: 1}, "Invalid primary key",
       [], %{"resource" => "Bar", "value" => 1}},
    "invalid_query" =>
      {%Ash.Error.Query.InvalidQuery{field: :x, message: "m"}, "Invalid query", ["x"],
       %{"field" => "x"}},
    "not_found" =>
      {%Ash.Error.Query.NotFound{resource: Foo.Bar, primary_key: %{id: 1}}, "Not found", [],
       %{"resource" => "Bar"}},
    "required" =>
      {%Ash.Error.Changes.Required{field: :x, type: :attribute}, "Required field", ["x"],
       %{"field" => "x"}},
    "tenant_required" =>
      {%Ash.Error.Invalid.TenantRequired{resource: Foo.Bar}, "Tenant required", [],
       %{"resource" => "Bar"}},
    "unknown_error" => {%Ash.Error.Unknown.UnknownError{error: "boom"}, "Unknown error", [], %{}}
  }

  defp wire(type) do
    {struct, _, _, _} = Map.fetch!(@cases, type)
    result = capture_log(fn -> send(self(), {:wire, AshSurface.Errors.to_errors([struct])}) end)
    assert is_binary(result)
    assert_received {:wire, [err]}
    err
  end

  defp wire_quiet(struct) do
    capture_log(fn -> send(self(), {:q, AshSurface.Errors.to_errors([struct])}) end)
    assert_received {:q, [err]}
    err
  end

  setup_all do
    wires =
      Map.new(@cases, fn {type, {struct, _, _, _}} ->
        {type, wire_quiet(struct)}
      end)

    specs =
      for {type, w} <- wires do
        %{
          kind: type,
          expression: ErrorSchema.variant(type),
          cases: [
            %{label: "valid wire output", expect: true, payload: w},
            %{
              label: "wrong type literal",
              expect: false,
              payload: Map.put(w, "type", "not_" <> type)
            }
          ]
        }
      end

    path = Path.join(System.tmp_dir!(), "errtypes_#{AshSurface.TestTmp.suffix()}.json")
    File.write!(path, Jason.encode!(%{specs: specs}))
    on_exit(fn -> File.rm(path) end)
    {out, 0} = System.cmd("node", [@runner, path], cd: Path.expand("../../..", __DIR__))
    {:ok, zod: Jason.decode!(out)}
  end

  defp court(type, zod) do
    {_, short, fields, vars} = Map.fetch!(@cases, type)
    err = wire(type)
    assert err["type"] == type
    assert err["shortMessage"] == short
    assert err["fields"] == fields
    assert err["path"] == []
    assert is_binary(err["message"])

    if type == "unknown_error" do
      # unclassified/unexposed errors are redacted to a generic UUID-tagged message
      assert err["vars"] == %{}
      assert err["details"]["errorId"] =~ @uuid

      assert err["message"] ==
               "Something went wrong. Unique error id: " <> err["details"]["errorId"]
    else
      assert err["vars"] == vars
      assert err["details"] == %{}
    end

    for r <- Map.fetch!(zod, type),
        do: assert(r["success"] == r["expect"], "#{type}: #{r["label"]}")

    :ok
  end

  test "error.type.forbidden wire output", %{zod: zod} do
    assert court("forbidden", zod) == :ok
  end

  test "error.type.forbidden_field wire output", %{zod: zod} do
    assert court("forbidden_field", zod) == :ok
  end

  test "error.type.invalid_argument wire output", %{zod: zod} do
    assert court("invalid_argument", zod) == :ok
  end

  test "error.type.invalid_attribute wire output", %{zod: zod} do
    assert court("invalid_attribute", zod) == :ok
  end

  test "error.type.invalid_changes wire output", %{zod: zod} do
    assert court("invalid_changes", zod) == :ok
  end

  test "error.type.invalid_keyset wire output", %{zod: zod} do
    assert court("invalid_keyset", zod) == :ok
  end

  test "error.type.invalid_page wire output", %{zod: zod} do
    assert court("invalid_page", zod) == :ok
  end

  test "error.type.invalid_primary_key wire output", %{zod: zod} do
    assert court("invalid_primary_key", zod) == :ok
  end

  test "error.type.invalid_query wire output", %{zod: zod} do
    assert court("invalid_query", zod) == :ok
  end

  test "error.type.not_found wire output", %{zod: zod} do
    assert court("not_found", zod) == :ok
  end

  test "error.type.required wire output", %{zod: zod} do
    assert court("required", zod) == :ok
  end

  test "error.type.tenant_required wire output", %{zod: zod} do
    assert court("tenant_required", zod) == :ok
  end

  test "error.type.unknown_error wire output", %{zod: zod} do
    assert court("unknown_error", zod) == :ok
  end

  test "error.type.forbidden is redacted to the generic message" do
    assert %{"message" => "forbidden", "vars" => %{}} = wire("forbidden")
  end
end
