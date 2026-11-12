Code.require_file("support/t1.exs", __DIR__)
Code.require_file("support/t2.exs", __DIR__)

defmodule AshSurface.Ported.Top.FormatterArtifactGapTest do
  @moduledoc """
  Loud skips (lane T1): reference tests that need per-embedded-resource filter types, RPC
  function config options (`.ts` signature text), or that the reference skips itself. The tests
  that assert the generated artifact's spelling follows `:output_field_formatter` / resource
  `field_names` are real since lane F1-fieldwire (`formatter_artifact_test.exs`). The runnable halves of the same reference files are
  in the sibling `*_test.exs` files (FieldName spelling + real node+zod acceptance).
  """
  use ExUnit.Case, async: true

  @moduletag timeout: 900_000

  alias AshSurface.Compiler.FilterSchema
  alias AshSurface.FieldName
  alias AshSurface.Ported.{T1, T2, TaskMetadata}

  defmodule Formatters do
    @moduledoc "Hand-written real custom formatter."
    def custom_format(field_name), do: "custom_#{field_name}"
  end

  @ref_skipped "T1 gap: skipped in the reference as well (@tag :skip); custom output formatters are not applied to the artifact (capability config.key.output_field_formatter)"

  defp filter(resource) do
    {:ok, zod} = FilterSchema.render_embedded(resource)
    zod
  end

  defp f(field, op, value), do: %{field: field, op: op, value: value}

  # filter_mapped_fields
  test "filter mapped: embedded resource generates its own filter type" do
    zod = filter(TaskMetadata)

    assert {:ok, [true, true, true, true, false]} ==
             T2.node_eval(zod, [
               f("notes", "eq", "n"),
               %{op: "and", value: [f("notes", "eq", "n")]},
               %{op: "or", value: [f("notes", "eq", "n")]},
               %{op: "not", value: f("notes", "eq", "n")},
               f("nope", "eq", "n")
             ])
  end

  test "filter mapped: embedded resource mapped fields have correct filter operations" do
    zod = filter(TaskMetadata)

    assert zod =~ "\"createdBy\""
    assert zod =~ "\"isPublic\""
    refute zod =~ "created_by"
    refute zod =~ "is_public"

    assert {:ok, [true, true, true, true, false, true, true, true, false, false]} ==
             T2.node_eval(zod, [
               f("createdBy", "eq", "a"),
               f("createdBy", "neq", "a"),
               f("createdBy", "in", ["a"]),
               f("createdBy", "gt", "a"),
               f("created_by", "eq", "a"),
               f("isPublic", "eq", true),
               f("isPublic", "neq", true),
               f("isPublic", "in", [true]),
               f("isPublic", "gt", true),
               f("isPublic", "lt", true)
             ])
  end

  test "filter mapped: embedded resource integer field has comparison operations" do
    zod = filter(TaskMetadata)

    assert {:ok, [true, true, true, true, true, true, true, false]} ==
             T2.node_eval(zod, [
               f("priorityLevel", "eq", 1),
               f("priorityLevel", "neq", 1),
               f("priorityLevel", "gt", 1),
               f("priorityLevel", "gte", 1),
               f("priorityLevel", "lt", 1),
               f("priorityLevel", "lte", 1),
               f("priorityLevel", "in", [1, 2]),
               f("priorityLevel", "eq", "one")
             ])
  end

  # codegen config options
  test "codegen config: formats RPC config option names with :snake_case formatter" do
    assert %{
             fetch_options: "fetch_options",
             custom_fetch: "custom_fetch",
             headers: "headers",
             hook_ctx: "hook_ctx"
           } == FieldName.config_options(:snake_case)

    assert %{fetch_options: "fetchOptions", hook_ctx: "hookCtx"} =
             FieldName.config_options(:camel_case)

    T1.with_env(:output_field_formatter, :snake_case, fn ->
      assert "fetch_options" == FieldName.config_options().fetch_options
    end)
  end

  test "codegen config: formats RPC config option names with a custom formatter" do
    opts = FieldName.config_options({Formatters, :custom_format})

    assert %{
             fetch_options: "custom_fetch_options",
             custom_fetch: "custom_custom_fetch",
             headers: "custom_headers",
             hook_ctx: "custom_hook_ctx"
           } == opts

    refute "fetchOptions" in Map.values(opts)
  end

  @tag skip: @ref_skipped
  test "RPC runtime: formats output fields with custom formatters", do: :ok
end
