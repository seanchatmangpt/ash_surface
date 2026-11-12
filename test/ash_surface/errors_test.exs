defmodule AshSurface.ErrorsTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias AshSurface.Compiler.ErrorSchema
  alias AshSurface.Errors
  alias AshSurface.IR.ErrorShape
  alias AshSurface.Projectors.JS.ZodGuard

  defmodule Handler do
    def handle_error(error, _ctx), do: Map.put(error, :handled, true)
  end

  defmodule Boom do
    def handle_error(_error, _ctx), do: raise("boom")
  end

  defmodule Tagging do
    def tag(error, _ctx, a, b, c), do: Map.put(error, :extra, [a, b, c])
  end

  alias Ash.Error.{Action, Changes, Forbidden, Invalid, Page, Query, Unknown}

  # {exception, expected type, expected short_message}
  defp rows do
    r = AshSurface.ZodFixtures.Todo

    [
      {Changes.InvalidChanges.exception(fields: [:a], message: "m"), "invalid_changes",
       "Invalid changes"},
      {Query.InvalidQuery.exception(field: :a, message: "m"), "invalid_query", "Invalid query"},
      {Query.NotFound.exception(primary_key: %{id: 1}, resource: r), "not_found", "Not found"},
      {Changes.Required.exception(field: :a, type: :attribute), "required", "Required field"},
      {Query.Required.exception(field: :a, type: :argument), "required", "Required field"},
      {Forbidden.ForbiddenField.exception(field: :a, resource: r), "forbidden_field",
       "Forbidden field"},
      {Changes.InvalidAttribute.exception(field: :a, message: "m"), "invalid_attribute",
       "Invalid attribute"},
      {Changes.InvalidArgument.exception(field: :a, message: "m"), "invalid_argument",
       "Invalid argument"},
      {Query.InvalidArgument.exception(field: :a, message: "m"), "invalid_argument",
       "Invalid argument"},
      {Action.InvalidArgument.exception(field: :a, message: "m"), "invalid_argument",
       "Invalid argument"},
      {Page.InvalidKeyset.exception(value: "x"), "invalid_keyset", "Invalid keyset"},
      {Query.InvalidPage.exception(page: 1), "invalid_page", "Invalid pagination"},
      {Invalid.TenantRequired.exception(resource: r), "tenant_required", "Tenant required"},
      {Invalid.InvalidPrimaryKey.exception(resource: r, value: 1), "invalid_primary_key",
       "Invalid primary key"},
      {Query.ReadActionRequiresActor.exception([]), "forbidden", "Authentication required"},
      {Query.NoSuchField.exception(field: :zz, resource: r), "unknown_error", "Unknown error"}
    ]
  end

  for {i, _} <- Enum.with_index(1..16) do
    test "type table row #{i}" do
      {exception, type, short} = Enum.at(rows(), unquote(i) - 1)
      [e] = Errors.to_errors(exception, formatter: :snake_case)
      assert e["type"] == type
      assert e["short_message"] == short
      assert ErrorShape.valid_type?(e["type"])
      assert is_map(e["details"])
    end
  end

  test "UnknownError and non-Ash terms emit unknown_error with the id under details" do
    log =
      capture_log(fn ->
        [a] = Errors.to_errors(Unknown.UnknownError.exception(error: "x"), formatter: :snake_case)
        [b] = Errors.to_errors(:weird, formatter: :snake_case)
        for e <- [a, b], do: assert(e["type"] == "unknown_error")
        for e <- [a, b], do: assert(e["details"]["error_id"] =~ ~r/\A[0-9a-f-]{36}\z/)
        refute Map.has_key?(a, "error_id")
        send(self(), :done)
      end)

    assert_received :done
    assert log =~ "Unhandled error"
  end

  test "Query.Required classifies as required with the field and argument type" do
    assert Errors.classify(Query.Required.exception(field: :a, type: :argument)) ==
             {"required", "Required field"}
  end

  test "classify/1 is total over structs and non-structs" do
    assert Errors.classify(Changes.Required.exception(field: :a, type: :attribute)) ==
             {"required", "Required field"}

    assert {"unknown_error", _} = Errors.classify(%{})

    assert {"unknown_error", _} =
             Errors.classify(
               Query.NoSuchField.exception(field: :z, resource: AshSurface.ZodFixtures.Todo)
             )
  end

  # Real Ash.Policy.Authorizer flows need a SAT solver (picosat_elixir/simple_sat), absent from
  # this repo's deps ("No SAT solver available"); the Policy exception is built directly.
  defp policy_error do
    Forbidden.Policy.exception(
      facts: %{},
      scenarios: [],
      policies: [],
      resource: AshSurface.ZodFixtures.Todo,
      action: :read,
      actor: nil,
      vars: [secret: "s3cr3t"]
    )
  end

  test "Policy is forbidden with redacted message; breakdown only when opted in" do
    raw = Exception.message(policy_error())

    # recorded: installed Ash 3.33.11 Exception.message/1 for a Policy error carries no policy text
    assert raw == "forbidden"

    [hidden] = Errors.to_errors(policy_error(), formatter: :snake_case)
    assert hidden["type"] == "forbidden"
    assert hidden["message"] == "forbidden"
    assert hidden["vars"] == %{}
    refute inspect(hidden) =~ "s3cr3t"

    [shown] =
      Errors.to_errors(policy_error(), formatter: :snake_case, show_policy_breakdowns: true)

    assert shown["type"] == "forbidden"
    assert shown["message"] == Forbidden.Policy.report(policy_error(), help_text?: false)
  end

  test "ReadActionRequiresActor is forbidden" do
    [e] = Errors.to_errors(Query.ReadActionRequiresActor.exception([]), formatter: :snake_case)
    assert e["type"] == "forbidden"
  end

  test "unwrap_errors flattens classes, nested lists and single-error wrappers" do
    a = Changes.Required.exception(field: :a, type: :attribute)
    b = Changes.Required.exception(field: :b, type: :attribute)
    assert Errors.unwrap_errors(%{errors: [a, %{errors: [b]}]}) == [a, b]
    assert Errors.unwrap_errors([[a], b]) == [a, b]
    assert Errors.unwrap_errors(%{errors: a}) == [a]
    assert Errors.unwrap_errors(:x) == [:x]

    assert Enum.map(Errors.unwrap_errors(Ash.Error.to_error_class([a, b])), & &1.field) == [
             :a,
             :b
           ]
  end

  test "unhandled_error/1 logs under a UUID the client receives; term never leaks" do
    log =
      capture_log(fn ->
        e = Errors.unhandled_error(%{secret: "s3cr3t"})
        assert e.type == "unknown_error"
        refute inspect(e) =~ "s3cr3t"
        assert e.message =~ e.details.error_id
        send(self(), {:id, e.details.error_id})
      end)

    assert_received {:id, id}
    assert log =~ id
    assert log =~ "s3cr3t"
  end

  test "fail-closed handler: raising handler yields generic error carrying a UUID that is logged" do
    log =
      capture_log(fn ->
        [e] =
          Errors.to_errors(Changes.Required.exception(field: :x, type: :attribute),
            domain_handler: Boom,
            formatter: :snake_case
          )

        assert e["type"] == "unknown_error"
        assert e["message"] =~ e["details"]["error_id"]
        refute inspect(e) =~ "required"
        send(self(), {:id, e["details"]["error_id"]})
      end)

    assert_received {:id, id}
    assert log =~ id
  end

  test "{m, f, args} handler runs via the no-apply path with extra args" do
    [e] =
      Errors.to_errors(Changes.Required.exception(field: :x, type: :attribute),
        resource_handler: {Tagging, :tag, [1, 2, 3]},
        formatter: :snake_case
      )

    assert e["extra"] == [1, 2, 3]

    [e2] =
      Errors.to_errors(Changes.Required.exception(field: :x, type: :attribute),
        domain_handler: Handler,
        formatter: :snake_case
      )

    assert e2["handled"] == true
  end

  # ------------------------------------------------------------ node round trip

  defp node_validate(schema_expr, payloads) do
    zod = Path.join(File.cwd!(), "node_modules/zod")
    File.dir?(zod) || raise "REQUIRED PACKAGE MISSING: zod at #{zod}"
    node = System.find_executable("node") || raise "REQUIRED TOOL MISSING: node"
    dir = Path.join(System.tmp_dir!(), "ash_surface_er_#{AshSurface.TestTmp.suffix()}")
    File.mkdir_p!(dir)
    File.ln_s!(Path.join(File.cwd!(), "node_modules"), Path.join(dir, "node_modules"))

    File.write!(Path.join(dir, "run.mjs"), """
    import { z } from "zod";
    import { readFileSync } from "node:fs";
    const E = #{schema_expr};
    const payloads = JSON.parse(readFileSync(new URL("./p.json", import.meta.url), "utf8"));
    process.stdout.write(JSON.stringify(payloads.map((p) => {
      const r = E.safeParse(p);
      return { success: r.success, issues: r.success ? [] : r.error.issues.map((i) => i.path.join(".") + ":" + i.code) };
    })));
    """)

    File.write!(Path.join(dir, "p.json"), Jason.encode!(payloads))
    {out, 0} = System.cmd(node, ["run.mjs"], cd: dir, stderr_to_stdout: true)
    File.rm_rf!(dir)
    Jason.decode!(out)
  end

  test "round trip: every to_errors output parses under the rendered ErrorSchema in node/zod" do
    {:ok, r} = ErrorSchema.render()
    assert :ok = ZodGuard.expression(r.union)

    {out, log} =
      with_log(fn ->
        generic = Errors.to_errors(:weird)

        handler_fail =
          Errors.to_errors(Changes.Required.exception(field: :x, type: :attribute),
            domain_handler: Boom
          )

        known = rows() |> Enum.flat_map(fn {ex, _, _} -> Errors.to_errors(ex) end)
        known ++ generic ++ handler_fail ++ Errors.to_errors(policy_error())
      end)

    assert log =~ "Error ID"
    assert length(out) >= 19

    results = node_validate(r.union, out)

    assert Enum.all?(results, & &1["success"]),
           inspect(Enum.zip(out, results) |> Enum.reject(fn {_, r} -> r["success"] end))

    # negative control: error objects are .passthrough() (handler-added keys survive), so an
    # extra key is lawful; the old shape (internal_error type) and a dropped required key are refused
    bad = [
      Map.delete(hd(out), "message"),
      Map.put(hd(out), "type", "internal_error")
    ]

    assert Enum.all?(node_validate(r.union, bad), &(not &1["success"]))
  end

  test "round trip under snake_case and pascal_case formatters with matching schema opts" do
    for formatter <- [:snake_case, :pascal_case] do
      {:ok, r} = ErrorSchema.render(%{}, formatter: formatter)

      out =
        Errors.to_errors(Changes.Required.exception(field: :x_y, type: :attribute),
          formatter: formatter
        )

      assert Enum.all?(node_validate(r.union, out), & &1["success"])
      # default camel schema refuses a non-camel wire
      if formatter == :snake_case do
        {:ok, camel} = ErrorSchema.render()
        refute Enum.all?(node_validate(camel.union, out), & &1["success"])
      end
    end
  end
end
