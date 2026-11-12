defmodule AshSurface.Ported.Rpc.E.ValibotConstraintsGapTest do
  @moduledoc """
  Loud-skip counterpart of ash_typescript `rpc/valibot_constraints_test.exs` (50 tests). Every reference
  test has a tagged skip carrying the row skip_tag; no silent skips.
  """
  use ExUnit.Case, async: true

  # describe "Integer constraints in Valibot schemas"

  @tag skip:
         "T12 gap: valibot_constraints (no Valibot schema generator in ash_surface; README names Zod as the executable boundary schema library but contains no Valibot non-goal sentence, so this is a gap pending operator decision; capabilities codegen.module.Codegen.ValibotSchemaGenerator)"
  test "001 generates min and max constraints for integer arguments via v.pipe" do
    :ok
  end

  @tag skip:
         "T12 gap: valibot_constraints (no Valibot schema generator in ash_surface; README names Zod as the executable boundary schema library but contains no Valibot non-goal sentence, so this is a gap pending operator decision; capabilities codegen.module.Codegen.ValibotSchemaGenerator)"
  test "002 integer without constraints generates plain v.pipe(v.number(), v.integer())" do
    :ok
  end

  # describe "String constraints in Valibot schemas"

  @tag skip:
         "T12 gap: valibot_constraints (no Valibot schema generator in ash_surface; README names Zod as the executable boundary schema library but contains no Valibot non-goal sentence, so this is a gap pending operator decision; capabilities codegen.module.Codegen.ValibotSchemaGenerator)"
  test "003 generates min and max length constraints via v.pipe" do
    :ok
  end

  @tag skip:
         "T12 gap: valibot_constraints (no Valibot schema generator in ash_surface; README names Zod as the executable boundary schema library but contains no Valibot non-goal sentence, so this is a gap pending operator decision; capabilities codegen.module.Codegen.ValibotSchemaGenerator)"
  test "004 required string without explicit min_length gets v.pipe(v.string(), v.minLength(1))" do
    :ok
  end

  @tag skip:
         "T12 gap: valibot_constraints (no Valibot schema generator in ash_surface; README names Zod as the executable boundary schema library but contains no Valibot non-goal sentence, so this is a gap pending operator decision; capabilities codegen.module.Codegen.ValibotSchemaGenerator)"
  test "005 nullable+omittable string enforces non-empty (allow_empty? false default)" do
    :ok
  end

  @tag skip:
         "T12 gap: valibot_constraints (no Valibot schema generator in ash_surface; README names Zod as the executable boundary schema library but contains no Valibot non-goal sentence, so this is a gap pending operator decision; capabilities codegen.module.Codegen.ValibotSchemaGenerator)"
  test "006 nullable string with allow_empty?: true stays unconstrained" do
    :ok
  end

  @tag skip:
         "T12 gap: valibot_constraints (no Valibot schema generator in ash_surface; README names Zod as the executable boundary schema library but contains no Valibot non-goal sentence, so this is a gap pending operator decision; capabilities codegen.module.Codegen.ValibotSchemaGenerator)"
  test "007 does NOT use method chaining for non-empty required string" do
    :ok
  end

  # describe "Array constraints in Valibot schemas"

  @tag skip:
         "T12 gap: valibot_constraints (no Valibot schema generator in ash_surface; README names Zod as the executable boundary schema library but contains no Valibot non-goal sentence, so this is a gap pending operator decision; capabilities codegen.module.Codegen.ValibotSchemaGenerator)"
  test "008 generates min_length constraint for array arguments" do
    :ok
  end

  @tag skip:
         "T12 gap: valibot_constraints (no Valibot schema generator in ash_surface; README names Zod as the executable boundary schema library but contains no Valibot non-goal sentence, so this is a gap pending operator decision; capabilities codegen.module.Codegen.ValibotSchemaGenerator)"
  test "009 generates max_length constraint for array arguments" do
    :ok
  end

  @tag skip:
         "T12 gap: valibot_constraints (no Valibot schema generator in ash_surface; README names Zod as the executable boundary schema library but contains no Valibot non-goal sentence, so this is a gap pending operator decision; capabilities codegen.module.Codegen.ValibotSchemaGenerator)"
  test "010 generates both array cardinality constraints" do
    :ok
  end

  @tag skip:
         "T12 gap: valibot_constraints (no Valibot schema generator in ash_surface; README names Zod as the executable boundary schema library but contains no Valibot non-goal sentence, so this is a gap pending operator decision; capabilities codegen.module.Codegen.ValibotSchemaGenerator)"
  test "011 preserves item constraints alongside array cardinality constraints" do
    :ok
  end

  @tag skip:
         "T12 gap: valibot_constraints (no Valibot schema generator in ash_surface; README names Zod as the executable boundary schema library but contains no Valibot non-goal sentence, so this is a gap pending operator decision; capabilities codegen.module.Codegen.ValibotSchemaGenerator)"
  test "012 applies nested array cardinality constraints at the correct level" do
    :ok
  end

  @tag skip:
         "T12 gap: valibot_constraints (no Valibot schema generator in ash_surface; README names Zod as the executable boundary schema library but contains no Valibot non-goal sentence, so this is a gap pending operator decision; capabilities codegen.module.Codegen.ValibotSchemaGenerator)"
  test "013 applies array constraints before optional and nullable wrappers" do
    :ok
  end

  # describe "Float constraints in Valibot schemas"

  @tag skip:
         "T12 gap: valibot_constraints (no Valibot schema generator in ash_surface; README names Zod as the executable boundary schema library but contains no Valibot non-goal sentence, so this is a gap pending operator decision; capabilities codegen.module.Codegen.ValibotSchemaGenerator)"
  test "014 generates min and max constraints for float arguments via v.pipe" do
    :ok
  end

  @tag skip:
         "T12 gap: valibot_constraints (no Valibot schema generator in ash_surface; README names Zod as the executable boundary schema library but contains no Valibot non-goal sentence, so this is a gap pending operator decision; capabilities codegen.module.Codegen.ValibotSchemaGenerator)"
  test "015 generates gt/lt constraints for float arguments via v.pipe" do
    :ok
  end

  @tag skip:
         "T12 gap: valibot_constraints (no Valibot schema generator in ash_surface; README names Zod as the executable boundary schema library but contains no Valibot non-goal sentence, so this is a gap pending operator decision; capabilities codegen.module.Codegen.ValibotSchemaGenerator)"
  test "016 generates min and max constraints for percentage" do
    :ok
  end

  @tag skip:
         "T12 gap: valibot_constraints (no Valibot schema generator in ash_surface; README names Zod as the executable boundary schema library but contains no Valibot non-goal sentence, so this is a gap pending operator decision; capabilities codegen.module.Codegen.ValibotSchemaGenerator)"
  test "017 float without constraints generates plain v.number()" do
    :ok
  end

  # describe "Optional fields in Valibot schemas"

  @tag skip:
         "T12 gap: valibot_constraints (no Valibot schema generator in ash_surface; README names Zod as the executable boundary schema library but contains no Valibot non-goal sentence, so this is a gap pending operator decision; capabilities codegen.module.Codegen.ValibotSchemaGenerator)"
  test "018 optional fields wrap with v.optional(schema), not schema.optional()" do
    :ok
  end

  # describe "UUID type in Valibot schemas"

  @tag skip:
         "T12 gap: valibot_constraints (no Valibot schema generator in ash_surface; README names Zod as the executable boundary schema library but contains no Valibot non-goal sentence, so this is a gap pending operator decision; capabilities codegen.module.Codegen.ValibotSchemaGenerator)"
  test "019 UUID uses v.pipe(v.string(), v.uuid())" do
    :ok
  end

  # describe "Constraint priority and ordering"

  @tag skip:
         "T12 gap: valibot_constraints (no Valibot schema generator in ash_surface; README names Zod as the executable boundary schema library but contains no Valibot non-goal sentence, so this is a gap pending operator decision; capabilities codegen.module.Codegen.ValibotSchemaGenerator)"
  test "020 integer: integer() validator comes before min/max in the pipe" do
    :ok
  end

  @tag skip:
         "T12 gap: valibot_constraints (no Valibot schema generator in ash_surface; README names Zod as the executable boundary schema library but contains no Valibot non-goal sentence, so this is a gap pending operator decision; capabilities codegen.module.Codegen.ValibotSchemaGenerator)"
  test "021 string: min length appears before max length in the pipe" do
    :ok
  end

  @tag skip:
         "T12 gap: valibot_constraints (no Valibot schema generator in ash_surface; README names Zod as the executable boundary schema library but contains no Valibot non-goal sentence, so this is a gap pending operator decision; capabilities codegen.module.Codegen.ValibotSchemaGenerator)"
  test "022 each argument gets its own independent pipe chain" do
    :ok
  end

  # describe "Schema structure"

  @tag skip:
         "T12 gap: valibot_constraints (no Valibot schema generator in ash_surface; README names Zod as the executable boundary schema library but contains no Valibot non-goal sentence, so this is a gap pending operator decision; capabilities codegen.module.Codegen.ValibotSchemaGenerator)"
  test "023 schema declaration uses v.object()" do
    :ok
  end

  @tag skip:
         "T12 gap: valibot_constraints (no Valibot schema generator in ash_surface; README names Zod as the executable boundary schema library but contains no Valibot non-goal sentence, so this is a gap pending operator decision; capabilities codegen.module.Codegen.ValibotSchemaGenerator)"
  test "024 field names are camelCase" do
    :ok
  end

  @tag skip:
         "T12 gap: valibot_constraints (no Valibot schema generator in ash_surface; README names Zod as the executable boundary schema library but contains no Valibot non-goal sentence, so this is a gap pending operator decision; capabilities codegen.module.Codegen.ValibotSchemaGenerator)"
  test "025 each field line ends with a comma" do
    :ok
  end

  # describe "Regex constraints in Valibot schemas"

  @tag skip:
         "T12 gap: valibot_constraints (no Valibot schema generator in ash_surface; README names Zod as the executable boundary schema library but contains no Valibot non-goal sentence, so this is a gap pending operator decision; capabilities codegen.module.Codegen.ValibotSchemaGenerator)"
  test "026 regex constraints are emitted as v.regex(...) inside a pipe" do
    :ok
  end

  @tag skip:
         "T12 gap: valibot_constraints (no Valibot schema generator in ash_surface; README names Zod as the executable boundary schema library but contains no Valibot non-goal sentence, so this is a gap pending operator decision; capabilities codegen.module.Codegen.ValibotSchemaGenerator)"
  test "027 no method chaining is used anywhere in the schema" do
    :ok
  end

  # describe "Edge cases and error handling"

  @tag skip:
         "T12 gap: valibot_constraints (no Valibot schema generator in ash_surface; README names Zod as the executable boundary schema library but contains no Valibot non-goal sentence, so this is a gap pending operator decision; capabilities codegen.module.Codegen.ValibotSchemaGenerator)"
  test "028 nil constraints are handled gracefully" do
    :ok
  end

  @tag skip:
         "T12 gap: valibot_constraints (no Valibot schema generator in ash_surface; README names Zod as the executable boundary schema library but contains no Valibot non-goal sentence, so this is a gap pending operator decision; capabilities codegen.module.Codegen.ValibotSchemaGenerator)"
  test "029 empty constraints list is handled gracefully" do
    :ok
  end

  # describe "Nullable+omittable float constraints in Valibot schemas"

  @tag skip:
         "T12 gap: valibot_constraints (no Valibot schema generator in ash_surface; README names Zod as the executable boundary schema library but contains no Valibot non-goal sentence, so this is a gap pending operator decision; capabilities codegen.module.Codegen.ValibotSchemaGenerator)"
  test "030 nullable+omittable float with constraints wraps v.pipe in v.optional(v.nullable(...))" do
    :ok
  end

  # describe "Float vs integer distinction in Valibot schemas"

  @tag skip:
         "T12 gap: valibot_constraints (no Valibot schema generator in ash_surface; README names Zod as the executable boundary schema library but contains no Valibot non-goal sentence, so this is a gap pending operator decision; capabilities codegen.module.Codegen.ValibotSchemaGenerator)"
  test "031 floats do not get v.integer() in their pipe" do
    :ok
  end

  # describe "CiString constraints in Valibot schemas"

  @tag skip:
         "T12 gap: valibot_constraints (no Valibot schema generator in ash_surface; README names Zod as the executable boundary schema library but contains no Valibot non-goal sentence, so this is a gap pending operator decision; capabilities codegen.module.Codegen.ValibotSchemaGenerator)"
  test "032 generates min_length and max_length constraints for ci_string arguments" do
    :ok
  end

  @tag skip:
         "T12 gap: valibot_constraints (no Valibot schema generator in ash_surface; README names Zod as the executable boundary schema library but contains no Valibot non-goal sentence, so this is a gap pending operator decision; capabilities codegen.module.Codegen.ValibotSchemaGenerator)"
  test "033 generates regex constraint for ci_string arguments via v.pipe" do
    :ok
  end

  @tag skip:
         "T12 gap: valibot_constraints (no Valibot schema generator in ash_surface; README names Zod as the executable boundary schema library but contains no Valibot non-goal sentence, so this is a gap pending operator decision; capabilities codegen.module.Codegen.ValibotSchemaGenerator)"
  test "034 ci_string with only regex constraint gets v.minLength(1) for required field" do
    :ok
  end

  @tag skip:
         "T12 gap: valibot_constraints (no Valibot schema generator in ash_surface; README names Zod as the executable boundary schema library but contains no Valibot non-goal sentence, so this is a gap pending operator decision; capabilities codegen.module.Codegen.ValibotSchemaGenerator)"
  test "035 nullable+omittable ci_string with constraints wraps v.pipe in v.optional(v.nullable(...))" do
    :ok
  end

  @tag skip:
         "T12 gap: valibot_constraints (no Valibot schema generator in ash_surface; README names Zod as the executable boundary schema library but contains no Valibot non-goal sentence, so this is a gap pending operator decision; capabilities codegen.module.Codegen.ValibotSchemaGenerator)"
  test "036 ci_string with case-insensitive regex includes i flag" do
    :ok
  end

  @tag skip:
         "T12 gap: valibot_constraints (no Valibot schema generator in ash_surface; README names Zod as the executable boundary schema library but contains no Valibot non-goal sentence, so this is a gap pending operator decision; capabilities codegen.module.Codegen.ValibotSchemaGenerator)"
  test "037 ci_string constraints work same as regular string" do
    :ok
  end

  # describe "Regex constraint handling (safe conversion only)"

  @tag skip:
         "T12 gap: valibot_constraints (no Valibot schema generator in ash_surface; README names Zod as the executable boundary schema library but contains no Valibot non-goal sentence, so this is a gap pending operator decision; capabilities codegen.module.Codegen.ValibotSchemaGenerator)"
  test "038 simple regex patterns are converted to JavaScript" do
    :ok
  end

  @tag skip:
         "T12 gap: valibot_constraints (no Valibot schema generator in ash_surface; README names Zod as the executable boundary schema library but contains no Valibot non-goal sentence, so this is a gap pending operator decision; capabilities codegen.module.Codegen.ValibotSchemaGenerator)"
  test "039 email regex pattern is properly converted" do
    :ok
  end

  @tag skip:
         "T12 gap: valibot_constraints (no Valibot schema generator in ash_surface; README names Zod as the executable boundary schema library but contains no Valibot non-goal sentence, so this is a gap pending operator decision; capabilities codegen.module.Codegen.ValibotSchemaGenerator)"
  test "040 phone number regex pattern is properly converted" do
    :ok
  end

  @tag skip:
         "T12 gap: valibot_constraints (no Valibot schema generator in ash_surface; README names Zod as the executable boundary schema library but contains no Valibot non-goal sentence, so this is a gap pending operator decision; capabilities codegen.module.Codegen.ValibotSchemaGenerator)"
  test "041 hex color regex pattern is properly converted" do
    :ok
  end

  @tag skip:
         "T12 gap: valibot_constraints (no Valibot schema generator in ash_surface; README names Zod as the executable boundary schema library but contains no Valibot non-goal sentence, so this is a gap pending operator decision; capabilities codegen.module.Codegen.ValibotSchemaGenerator)"
  test "042 slug regex pattern is properly converted" do
    :ok
  end

  @tag skip:
         "T12 gap: valibot_constraints (no Valibot schema generator in ash_surface; README names Zod as the executable boundary schema library but contains no Valibot non-goal sentence, so this is a gap pending operator decision; capabilities codegen.module.Codegen.ValibotSchemaGenerator)"
  test "043 semantic version regex pattern is properly converted" do
    :ok
  end

  @tag skip:
         "T12 gap: valibot_constraints (no Valibot schema generator in ash_surface; README names Zod as the executable boundary schema library but contains no Valibot non-goal sentence, so this is a gap pending operator decision; capabilities codegen.module.Codegen.ValibotSchemaGenerator)"
  test "044 case-insensitive regex includes i flag" do
    :ok
  end

  @tag skip:
         "T12 gap: valibot_constraints (no Valibot schema generator in ash_surface; README names Zod as the executable boundary schema library but contains no Valibot non-goal sentence, so this is a gap pending operator decision; capabilities codegen.module.Codegen.ValibotSchemaGenerator)"
  test "045 nullable+omittable field with regex constraint wraps in v.optional(v.nullable(...))" do
    :ok
  end

  @tag skip:
         "T12 gap: valibot_constraints (no Valibot schema generator in ash_surface; README names Zod as the executable boundary schema library but contains no Valibot non-goal sentence, so this is a gap pending operator decision; capabilities codegen.module.Codegen.ValibotSchemaGenerator)"
  test "046 regex constraints are properly escaped for JavaScript" do
    :ok
  end

  @tag skip:
         "T12 gap: valibot_constraints (no Valibot schema generator in ash_surface; README names Zod as the executable boundary schema library but contains no Valibot non-goal sentence, so this is a gap pending operator decision; capabilities codegen.module.Codegen.ValibotSchemaGenerator)"
  test "047 complex PCRE patterns are skipped to avoid incorrect validation" do
    :ok
  end

  # describe "Constraint definitions match Ash resource"

  @tag skip:
         "T12 gap: valibot_constraints (no Valibot schema generator in ash_surface; README names Zod as the executable boundary schema library but contains no Valibot non-goal sentence, so this is a gap pending operator decision; capabilities codegen.module.Codegen.ValibotSchemaGenerator)"
  test "048 generated constraints exactly match the Ash attribute definitions" do
    :ok
  end

  # describe "third-party type schemas"

  @tag skip:
         "T12 gap: valibot_constraints (no Valibot schema generator in ash_surface; README names Zod as the executable boundary schema library but contains no Valibot non-goal sentence, so this is a gap pending operator decision; capabilities codegen.module.Codegen.ValibotSchemaGenerator)"
  test "049 AshMoney.Types.Money maps to object matching the TS Money alias" do
    :ok
  end

  # describe "Ash.Type.Vector in valibot schemas"

  @tag skip:
         "T12 gap: valibot_constraints (no Valibot schema generator in ash_surface; README names Zod as the executable boundary schema library but contains no Valibot non-goal sentence, so this is a gap pending operator decision; capabilities codegen.module.Codegen.ValibotSchemaGenerator)"
  test "050 resolves a vector by module rather than its :term kind" do
    :ok
  end
end
