defmodule AshSurface.Ported.Rpc.C.NamespaceGapTest do
  use ExUnit.Case, async: true

  @tag skip:
         "T10 gap: namespace (TS-SYNTAX-ONLY: asserts JSDoc comment text or generated multi-file .ts layout with no ash_surface counterpart: ash_surface emits no JSDoc blocks, namespace files or re-export modules; README.md:29 'no generated .ts, no .d.ts, no tsc build step'; capabilities codegen.module.Rpc.Codegen.FunctionGenerators.JsdocGenerator, config.key.enable_namespace_files)"
  test "012 generate_jsdoc uses correct description for action types" do
    :ok
  end

  @tag skip:
         "T10 gap: namespace (TS-SYNTAX-ONLY: asserts JSDoc comment text or generated multi-file .ts layout with no ash_surface counterpart: ash_surface emits no JSDoc blocks, namespace files or re-export modules; README.md:29 'no generated .ts, no .d.ts, no tsc build step'; capabilities codegen.module.Rpc.Codegen.FunctionGenerators.JsdocGenerator, config.key.enable_namespace_files)"
  test "013 generate_validation_jsdoc includes validation marker" do
    :ok
  end

  @tag skip:
         "T10 gap: namespace (TS-SYNTAX-ONLY: asserts JSDoc comment text or generated multi-file .ts layout with no ash_surface counterpart: ash_surface emits no JSDoc blocks, namespace files or re-export modules; README.md:29 'no generated .ts, no .d.ts, no tsc build step'; capabilities codegen.module.Rpc.Codegen.FunctionGenerators.JsdocGenerator, config.key.enable_namespace_files)"
  test "014 generate_jsdoc excludes internals when add_ash_internals_to_jsdoc is false" do
    :ok
  end

  @tag skip:
         "T10 gap: namespace (TS-SYNTAX-ONLY: asserts JSDoc comment text or generated multi-file .ts layout with no ash_surface counterpart: ash_surface emits no JSDoc blocks, namespace files or re-export modules; README.md:29 'no generated .ts, no .d.ts, no tsc build step'; capabilities codegen.module.Rpc.Codegen.FunctionGenerators.JsdocGenerator, config.key.enable_namespace_files)"
  test "015 generate_validation_jsdoc excludes internals when add_ash_internals_to_jsdoc is false" do
    :ok
  end

  @tag skip:
         "T10 gap: namespace (TS-SYNTAX-ONLY: asserts JSDoc comment text or generated multi-file .ts layout with no ash_surface counterpart: ash_surface emits no JSDoc blocks, namespace files or re-export modules; README.md:29 'no generated .ts, no .d.ts, no tsc build step'; capabilities codegen.module.Rpc.Codegen.FunctionGenerators.JsdocGenerator, config.key.enable_namespace_files)"
  test "016 generate_jsdoc includes the action's source location when exposing internals" do
    :ok
  end

  @tag skip:
         "T10 gap: namespace (TS-SYNTAX-ONLY: asserts JSDoc comment text or generated multi-file .ts layout with no ash_surface counterpart: ash_surface emits no JSDoc blocks, namespace files or re-export modules; README.md:29 'no generated .ts, no .d.ts, no tsc build step'; capabilities codegen.module.Rpc.Codegen.FunctionGenerators.JsdocGenerator, config.key.enable_namespace_files)"
  test "017 generate_jsdoc includes the rpc action's source location for charlist and binary anno files" do
    :ok
  end

  @tag skip:
         "T10 gap: namespace (TS-SYNTAX-ONLY: asserts JSDoc comment text or generated multi-file .ts layout with no ash_surface counterpart: ash_surface emits no JSDoc blocks, namespace files or re-export modules; README.md:29 'no generated .ts, no .d.ts, no tsc build step'; capabilities codegen.module.Rpc.Codegen.FunctionGenerators.JsdocGenerator, config.key.enable_namespace_files)"
  test "021 generate_jsdoc ignores action description when internals disabled" do
    :ok
  end

  @tag skip:
         "T10 gap: namespace (TS-SYNTAX-ONLY: asserts JSDoc comment text or generated multi-file .ts layout with no ash_surface counterpart: ash_surface emits no JSDoc blocks, namespace files or re-export modules; README.md:29 'no generated .ts, no .d.ts, no tsc build step'; capabilities codegen.module.Rpc.Codegen.FunctionGenerators.JsdocGenerator, config.key.enable_namespace_files)"
  test "031 generate_validation_jsdoc includes @deprecated but not @see" do
    :ok
  end

  @tag skip:
         "T10 gap: namespace (TS-SYNTAX-ONLY: asserts JSDoc comment text or generated multi-file .ts layout with no ash_surface counterpart: ash_surface emits no JSDoc blocks, namespace files or re-export modules; README.md:29 'no generated .ts, no .d.ts, no tsc build step'; capabilities codegen.module.Rpc.Codegen.FunctionGenerators.JsdocGenerator, config.key.enable_namespace_files)"
  test "035 generated functions include JSDoc comments" do
    :ok
  end

  @tag skip:
         "T10 gap: namespace (TS-SYNTAX-ONLY: asserts JSDoc comment text or generated multi-file .ts layout with no ash_surface counterpart: ash_surface emits no JSDoc blocks, namespace files or re-export modules; README.md:29 'no generated .ts, no .d.ts, no tsc build step'; capabilities codegen.module.Rpc.Codegen.FunctionGenerators.JsdocGenerator, config.key.enable_namespace_files)"
  test "036 JSDoc appears before function declaration" do
    :ok
  end

  @tag skip:
         "T10 gap: namespace (TS-SYNTAX-ONLY: asserts JSDoc comment text or generated multi-file .ts layout with no ash_surface counterpart: ash_surface emits no JSDoc blocks, namespace files or re-export modules; README.md:29 'no generated .ts, no .d.ts, no tsc build step'; capabilities codegen.module.Rpc.Codegen.FunctionGenerators.JsdocGenerator, config.key.enable_namespace_files)"
  test "038 orchestrator returns map of file paths to content" do
    :ok
  end

  @tag skip:
         "T10 gap: namespace (TS-SYNTAX-ONLY: asserts JSDoc comment text or generated multi-file .ts layout with no ash_surface counterpart: ash_surface emits no JSDoc blocks, namespace files or re-export modules; README.md:29 'no generated .ts, no .d.ts, no tsc build step'; capabilities codegen.module.Rpc.Codegen.FunctionGenerators.JsdocGenerator, config.key.enable_namespace_files)"
  test "039 utility types are exported from types file" do
    :ok
  end

  @tag skip:
         "T10 gap: namespace (TS-SYNTAX-ONLY: asserts JSDoc comment text or generated multi-file .ts layout with no ash_surface counterpart: ash_surface emits no JSDoc blocks, namespace files or re-export modules; README.md:29 'no generated .ts, no .d.ts, no tsc build step'; capabilities codegen.module.Rpc.Codegen.FunctionGenerators.JsdocGenerator, config.key.enable_namespace_files)"
  test "040 namespace files re-export functions from RPC file" do
    :ok
  end

  @tag skip:
         "T10 gap: namespace (TS-SYNTAX-ONLY: asserts JSDoc comment text or generated multi-file .ts layout with no ash_surface counterpart: ash_surface emits no JSDoc blocks, namespace files or re-export modules; README.md:29 'no generated .ts, no .d.ts, no tsc build step'; capabilities codegen.module.Rpc.Codegen.FunctionGenerators.JsdocGenerator, config.key.enable_namespace_files)"
  test "041 namespace files re-export types from RPC file" do
    :ok
  end

  @tag skip:
         "T10 gap: namespace (TS-SYNTAX-ONLY: asserts JSDoc comment text or generated multi-file .ts layout with no ash_surface counterpart: ash_surface emits no JSDoc blocks, namespace files or re-export modules; README.md:29 'no generated .ts, no .d.ts, no tsc build step'; capabilities codegen.module.Rpc.Codegen.FunctionGenerators.JsdocGenerator, config.key.enable_namespace_files)"
  test "042 namespace files re-export only their namespaced actions" do
    :ok
  end

  @tag skip:
         "T10 gap: namespace (TS-SYNTAX-ONLY: asserts JSDoc comment text or generated multi-file .ts layout with no ash_surface counterpart: ash_surface emits no JSDoc blocks, namespace files or re-export modules; README.md:29 'no generated .ts, no .d.ts, no tsc build step'; capabilities codegen.module.Rpc.Codegen.FunctionGenerators.JsdocGenerator, config.key.enable_namespace_files)"
  test "043 RPC file contains ALL functions including namespaced ones" do
    :ok
  end

  @tag skip:
         "T10 gap: namespace (TS-SYNTAX-ONLY: asserts JSDoc comment text or generated multi-file .ts layout with no ash_surface counterpart: ash_surface emits no JSDoc blocks, namespace files or re-export modules; README.md:29 'no generated .ts, no .d.ts, no tsc build step'; capabilities codegen.module.Rpc.Codegen.FunctionGenerators.JsdocGenerator, config.key.enable_namespace_files)"
  test "044 RPC file contains JSDoc with @namespace for namespaced functions" do
    :ok
  end

  @tag skip:
         "T10 gap: namespace (TS-SYNTAX-ONLY: asserts JSDoc comment text or generated multi-file .ts layout with no ash_surface counterpart: ash_surface emits no JSDoc blocks, namespace files or re-export modules; README.md:29 'no generated .ts, no .d.ts, no tsc build step'; capabilities codegen.module.Rpc.Codegen.FunctionGenerators.JsdocGenerator, config.key.enable_namespace_files)"
  test "045 namespace files have correct header comment" do
    :ok
  end

  @tag skip:
         "T10 gap: namespace (TS-SYNTAX-ONLY: asserts JSDoc comment text or generated multi-file .ts layout with no ash_surface counterpart: ash_surface emits no JSDoc blocks, namespace files or re-export modules; README.md:29 'no generated .ts, no .d.ts, no tsc build step'; capabilities codegen.module.Rpc.Codegen.FunctionGenerators.JsdocGenerator, config.key.enable_namespace_files)"
  test "046 namespace files include custom code preservation marker" do
    :ok
  end

  @tag skip:
         "T10 gap: namespace (TS-SYNTAX-ONLY: asserts JSDoc comment text or generated multi-file .ts layout with no ash_surface counterpart: ash_surface emits no JSDoc blocks, namespace files or re-export modules; README.md:29 'no generated .ts, no .d.ts, no tsc build step'; capabilities codegen.module.Rpc.Codegen.FunctionGenerators.JsdocGenerator, config.key.enable_namespace_files)"
  test "047 preserves custom code below marker on regeneration" do
    :ok
  end

  @tag skip:
         "T10 gap: namespace (TS-SYNTAX-ONLY: asserts JSDoc comment text or generated multi-file .ts layout with no ash_surface counterpart: ash_surface emits no JSDoc blocks, namespace files or re-export modules; README.md:29 'no generated .ts, no .d.ts, no tsc build step'; capabilities codegen.module.Rpc.Codegen.FunctionGenerators.JsdocGenerator, config.key.enable_namespace_files)"
  test "048 does not duplicate custom code on multiple regenerations" do
    :ok
  end
end
