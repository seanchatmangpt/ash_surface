defmodule AshSurface.Ported.Rpc.B.ManifestGeneratorGapTest do
  use ExUnit.Case, async: true

  describe "RpcConfigCollector.get_rpc_config_by_domain/1" do
    @tag skip:
           "GU-T9 gap: ash_surface has no domain rpc config registry (RpcConfigCollector); the entry table is installed explicitly via Support.install/2, so domain-grouped collection has no counterpart"
    test "returns domain-grouped config" do
      :ok
    end

    @tag skip:
           "GU-T9 gap: ash_surface has no domain rpc config registry (RpcConfigCollector); the entry table is installed explicitly via Support.install/2, so domain-grouped collection has no counterpart"
    test "excludes domains with no RPC config" do
      :ok
    end

    @tag skip:
           "GU-T9 gap: ash_surface has no domain rpc config registry (RpcConfigCollector); the entry table is installed explicitly via Support.install/2, so domain-grouped collection has no counterpart"
    test "includes both test domains" do
      :ok
    end
  end

  describe "ManifestGenerator.generate_manifest/1 - basic structure" do
    @tag skip:
           "GU-T9 gap (operator decision D24): the reference renders a markdown document (headers, tables with TS Zod/Valibot/Channel/Validation columns, typed queries, typed-controller routes); ash_surface has no markdown manifest renderer and README has no sentence declaring markdown docs a non-goal. The facts those tables carry are asserted on the KD-07 machine-readable manifest in manifest_generator_surface_test.exs and json_manifest_generator_surface_test.exs"
    test "includes header with date" do
      :ok
    end

    @tag skip:
           "GU-T9 gap (operator decision D24): the reference renders a markdown document (headers, tables with TS Zod/Valibot/Channel/Validation columns, typed queries, typed-controller routes); ash_surface has no markdown manifest renderer and README has no sentence declaring markdown docs a non-goal. The facts those tables carry are asserted on the KD-07 machine-readable manifest in manifest_generator_surface_test.exs and json_manifest_generator_surface_test.exs"
    test "includes namespace sections when namespaces are configured" do
      :ok
    end

    @tag skip:
           "GU-T9 gap (operator decision D24): the reference renders a markdown document (headers, tables with TS Zod/Valibot/Channel/Validation columns, typed queries, typed-controller routes); ash_surface has no markdown manifest renderer and README has no sentence declaring markdown docs a non-goal. The facts those tables carry are asserted on the KD-07 machine-readable manifest in manifest_generator_surface_test.exs and json_manifest_generator_surface_test.exs"
    test "includes resource subsections" do
      :ok
    end

    @tag skip:
           "GU-T9 gap (operator decision D24): the reference renders a markdown document (headers, tables with TS Zod/Valibot/Channel/Validation columns, typed queries, typed-controller routes); ash_surface has no markdown manifest renderer and README has no sentence declaring markdown docs a non-goal. The facts those tables carry are asserted on the KD-07 machine-readable manifest in manifest_generator_surface_test.exs and json_manifest_generator_surface_test.exs"
    test "ends with single newline" do
      :ok
    end
  end

  describe "ManifestGenerator.generate_manifest/1 - sorting" do
    @tag skip:
           "GU-T9 gap (operator decision D24): the reference renders a markdown document (headers, tables with TS Zod/Valibot/Channel/Validation columns, typed queries, typed-controller routes); ash_surface has no markdown manifest renderer and README has no sentence declaring markdown docs a non-goal. The facts those tables carry are asserted on the KD-07 machine-readable manifest in manifest_generator_surface_test.exs and json_manifest_generator_surface_test.exs"
    test "namespace sections are sorted (default first, then alphabetically)" do
      :ok
    end
  end

  describe "ManifestGenerator.generate_manifest/1 - table columns" do
    @tag skip:
           "GU-T9 gap (operator decision D24): the reference renders a markdown document (headers, tables with TS Zod/Valibot/Channel/Validation columns, typed queries, typed-controller routes); ash_surface has no markdown manifest renderer and README has no sentence declaring markdown docs a non-goal. The facts those tables carry are asserted on the KD-07 machine-readable manifest in manifest_generator_surface_test.exs and json_manifest_generator_surface_test.exs"
    test "includes Function column" do
      :ok
    end

    @tag skip:
           "GU-T9 gap (operator decision D24): the reference renders a markdown document (headers, tables with TS Zod/Valibot/Channel/Validation columns, typed queries, typed-controller routes); ash_surface has no markdown manifest renderer and README has no sentence declaring markdown docs a non-goal. The facts those tables carry are asserted on the KD-07 machine-readable manifest in manifest_generator_surface_test.exs and json_manifest_generator_surface_test.exs"
    test "includes Action Type column" do
      :ok
    end

    @tag skip:
           "GU-T9 gap (operator decision D24): the reference renders a markdown document (headers, tables with TS Zod/Valibot/Channel/Validation columns, typed queries, typed-controller routes); ash_surface has no markdown manifest renderer and README has no sentence declaring markdown docs a non-goal. The facts those tables carry are asserted on the KD-07 machine-readable manifest in manifest_generator_surface_test.exs and json_manifest_generator_surface_test.exs"
    test "includes Ash Action column when internals enabled" do
      :ok
    end

    @tag skip:
           "GU-T9 gap (operator decision D24): the reference renders a markdown document (headers, tables with TS Zod/Valibot/Channel/Validation columns, typed queries, typed-controller routes); ash_surface has no markdown manifest renderer and README has no sentence declaring markdown docs a non-goal. The facts those tables carry are asserted on the KD-07 machine-readable manifest in manifest_generator_surface_test.exs and json_manifest_generator_surface_test.exs"
    test "includes Resource column when internals enabled" do
      :ok
    end

    @tag skip:
           "GU-T9 gap (operator decision D24): the reference renders a markdown document (headers, tables with TS Zod/Valibot/Channel/Validation columns, typed queries, typed-controller routes); ash_surface has no markdown manifest renderer and README has no sentence declaring markdown docs a non-goal. The facts those tables carry are asserted on the KD-07 machine-readable manifest in manifest_generator_surface_test.exs and json_manifest_generator_surface_test.exs"
    test "includes Validation column when validation functions enabled" do
      :ok
    end

    @tag skip:
           "GU-T9 gap (operator decision D24): the reference renders a markdown document (headers, tables with TS Zod/Valibot/Channel/Validation columns, typed queries, typed-controller routes); ash_surface has no markdown manifest renderer and README has no sentence declaring markdown docs a non-goal. The facts those tables carry are asserted on the KD-07 machine-readable manifest in manifest_generator_surface_test.exs and json_manifest_generator_surface_test.exs"
    test "includes Zod Schema column when zod schemas enabled" do
      :ok
    end

    @tag skip:
           "GU-T9 gap (operator decision D24): the reference renders a markdown document (headers, tables with TS Zod/Valibot/Channel/Validation columns, typed queries, typed-controller routes); ash_surface has no markdown manifest renderer and README has no sentence declaring markdown docs a non-goal. The facts those tables carry are asserted on the KD-07 machine-readable manifest in manifest_generator_surface_test.exs and json_manifest_generator_surface_test.exs"
    test "includes Valibot Schema column when valibot schemas enabled" do
      :ok
    end

    @tag skip:
           "GU-T9 gap (operator decision D24): the reference renders a markdown document (headers, tables with TS Zod/Valibot/Channel/Validation columns, typed queries, typed-controller routes); ash_surface has no markdown manifest renderer and README has no sentence declaring markdown docs a non-goal. The facts those tables carry are asserted on the KD-07 machine-readable manifest in manifest_generator_surface_test.exs and json_manifest_generator_surface_test.exs"
    test "schema names honor the configured suffixes" do
      :ok
    end

    @tag skip:
           "GU-T9 gap (operator decision D24): the reference renders a markdown document (headers, tables with TS Zod/Valibot/Channel/Validation columns, typed queries, typed-controller routes); ash_surface has no markdown manifest renderer and README has no sentence declaring markdown docs a non-goal. The facts those tables carry are asserted on the KD-07 machine-readable manifest in manifest_generator_surface_test.exs and json_manifest_generator_surface_test.exs"
    test "input-less actions show a dash instead of a schema name" do
      :ok
    end

    @tag skip:
           "GU-T9 gap (operator decision D24): the reference renders a markdown document (headers, tables with TS Zod/Valibot/Channel/Validation columns, typed queries, typed-controller routes); ash_surface has no markdown manifest renderer and README has no sentence declaring markdown docs a non-goal. The facts those tables carry are asserted on the KD-07 machine-readable manifest in manifest_generator_surface_test.exs and json_manifest_generator_surface_test.exs"
    test "includes Channel column when channel functions enabled" do
      :ok
    end

    @tag skip:
           "GU-T9 gap (operator decision D24): the reference renders a markdown document (headers, tables with TS Zod/Valibot/Channel/Validation columns, typed queries, typed-controller routes); ash_surface has no markdown manifest renderer and README has no sentence declaring markdown docs a non-goal. The facts those tables carry are asserted on the KD-07 machine-readable manifest in manifest_generator_surface_test.exs and json_manifest_generator_surface_test.exs"
    test "includes Validation Channel column when both validation and channel enabled" do
      :ok
    end
  end

  describe "ManifestGenerator.generate_manifest/1 - typed queries" do
    @tag skip:
           "GU-T9 gap (operator decision D24): the reference renders a markdown document (headers, tables with TS Zod/Valibot/Channel/Validation columns, typed queries, typed-controller routes); ash_surface has no markdown manifest renderer and README has no sentence declaring markdown docs a non-goal. The facts those tables carry are asserted on the KD-07 machine-readable manifest in manifest_generator_surface_test.exs and json_manifest_generator_surface_test.exs"
    test "includes typed queries section" do
      :ok
    end

    @tag skip:
           "GU-T9 gap (operator decision D24): the reference renders a markdown document (headers, tables with TS Zod/Valibot/Channel/Validation columns, typed queries, typed-controller routes); ash_surface has no markdown manifest renderer and README has no sentence declaring markdown docs a non-goal. The facts those tables carry are asserted on the KD-07 machine-readable manifest in manifest_generator_surface_test.exs and json_manifest_generator_surface_test.exs"
    test "lists typed query const names and result types" do
      :ok
    end

    @tag skip:
           "GU-T9 gap (operator decision D24): the reference renders a markdown document (headers, tables with TS Zod/Valibot/Channel/Validation columns, typed queries, typed-controller routes); ash_surface has no markdown manifest renderer and README has no sentence declaring markdown docs a non-goal. The facts those tables carry are asserted on the KD-07 machine-readable manifest in manifest_generator_surface_test.exs and json_manifest_generator_surface_test.exs"
    test "typed queries use arrow notation" do
      :ok
    end
  end

  describe "ManifestGenerator.generate_manifest/1 - function naming" do
    @tag skip:
           "GU-T9 gap (operator decision D24): the reference renders a markdown document (headers, tables with TS Zod/Valibot/Channel/Validation columns, typed queries, typed-controller routes); ash_surface has no markdown manifest renderer and README has no sentence declaring markdown docs a non-goal. The facts those tables carry are asserted on the KD-07 machine-readable manifest in manifest_generator_surface_test.exs and json_manifest_generator_surface_test.exs"
    test "validation function names are camelCase with validate prefix" do
      :ok
    end

    @tag skip:
           "GU-T9 gap (operator decision D24): the reference renders a markdown document (headers, tables with TS Zod/Valibot/Channel/Validation columns, typed queries, typed-controller routes); ash_surface has no markdown manifest renderer and README has no sentence declaring markdown docs a non-goal. The facts those tables carry are asserted on the KD-07 machine-readable manifest in manifest_generator_surface_test.exs and json_manifest_generator_surface_test.exs"
    test "zod schema names use field formatter with ZodSchema suffix" do
      :ok
    end

    @tag skip:
           "GU-T9 gap (operator decision D24): the reference renders a markdown document (headers, tables with TS Zod/Valibot/Channel/Validation columns, typed queries, typed-controller routes); ash_surface has no markdown manifest renderer and README has no sentence declaring markdown docs a non-goal. The facts those tables carry are asserted on the KD-07 machine-readable manifest in manifest_generator_surface_test.exs and json_manifest_generator_surface_test.exs"
    test "channel function names are camelCase with Channel suffix" do
      :ok
    end
  end

  describe "ManifestGenerator - add_ash_internals_to_manifest config" do
    @tag skip:
           "GU-T9 gap (operator decision D24): the reference renders a markdown document (headers, tables with TS Zod/Valibot/Channel/Validation columns, typed queries, typed-controller routes); ash_surface has no markdown manifest renderer and README has no sentence declaring markdown docs a non-goal. The facts those tables carry are asserted on the KD-07 machine-readable manifest in manifest_generator_surface_test.exs and json_manifest_generator_surface_test.exs"
    test "excludes Ash Action and Resource columns when internals disabled" do
      :ok
    end

    @tag skip:
           "GU-T9 gap (operator decision D24): the reference renders a markdown document (headers, tables with TS Zod/Valibot/Channel/Validation columns, typed queries, typed-controller routes); ash_surface has no markdown manifest renderer and README has no sentence declaring markdown docs a non-goal. The facts those tables carry are asserted on the KD-07 machine-readable manifest in manifest_generator_surface_test.exs and json_manifest_generator_surface_test.exs"
    test "includes Ash Action and Resource columns when internals enabled" do
      :ok
    end

    @tag skip:
           "GU-T9 gap (operator decision D24): the reference renders a markdown document (headers, tables with TS Zod/Valibot/Channel/Validation columns, typed queries, typed-controller routes); ash_surface has no markdown manifest renderer and README has no sentence declaring markdown docs a non-goal. The facts those tables carry are asserted on the KD-07 machine-readable manifest in manifest_generator_surface_test.exs and json_manifest_generator_surface_test.exs"
    test "shows action description when internals enabled and rpc_action has no description" do
      :ok
    end

    @tag skip:
           "GU-T9 gap (operator decision D24): the reference renders a markdown document (headers, tables with TS Zod/Valibot/Channel/Validation columns, typed queries, typed-controller routes); ash_surface has no markdown manifest renderer and README has no sentence declaring markdown docs a non-goal. The facts those tables carry are asserted on the KD-07 machine-readable manifest in manifest_generator_surface_test.exs and json_manifest_generator_surface_test.exs"
    test "uses default description when internals disabled and no rpc_action description" do
      :ok
    end
  end

  describe "ManifestGenerator - conditional columns" do
    @tag skip:
           "GU-T9 gap (operator decision D24): the reference renders a markdown document (headers, tables with TS Zod/Valibot/Channel/Validation columns, typed queries, typed-controller routes); ash_surface has no markdown manifest renderer and README has no sentence declaring markdown docs a non-goal. The facts those tables carry are asserted on the KD-07 machine-readable manifest in manifest_generator_surface_test.exs and json_manifest_generator_surface_test.exs"
    test "generates minimal table when all features disabled" do
      :ok
    end

    @tag skip:
           "GU-T9 gap (operator decision D24): the reference renders a markdown document (headers, tables with TS Zod/Valibot/Channel/Validation columns, typed queries, typed-controller routes); ash_surface has no markdown manifest renderer and README has no sentence declaring markdown docs a non-goal. The facts those tables carry are asserted on the KD-07 machine-readable manifest in manifest_generator_surface_test.exs and json_manifest_generator_surface_test.exs"
    test "generates table with only validation column when only validation enabled" do
      :ok
    end
  end

  describe "ManifestGenerator - namespace grouping" do
    @tag skip:
           "GU-T9 gap (operator decision D24): the reference renders a markdown document (headers, tables with TS Zod/Valibot/Channel/Validation columns, typed queries, typed-controller routes); ash_surface has no markdown manifest renderer and README has no sentence declaring markdown docs a non-goal. The facts those tables carry are asserted on the KD-07 machine-readable manifest in manifest_generator_surface_test.exs and json_manifest_generator_surface_test.exs"
    test "groups by namespace when namespaces are configured" do
      :ok
    end

    @tag skip:
           "GU-T9 gap (operator decision D24): the reference renders a markdown document (headers, tables with TS Zod/Valibot/Channel/Validation columns, typed queries, typed-controller routes); ash_surface has no markdown manifest renderer and README has no sentence declaring markdown docs a non-goal. The facts those tables carry are asserted on the KD-07 machine-readable manifest in manifest_generator_surface_test.exs and json_manifest_generator_surface_test.exs"
    test "actions in the same namespace are grouped together" do
      :ok
    end
  end

  describe "ManifestGenerator - typed controller routes section in :paths_only mode" do
    @tag skip:
           "GU-T9 gap (operator decision D24): the reference renders a markdown document (headers, tables with TS Zod/Valibot/Channel/Validation columns, typed queries, typed-controller routes); ash_surface has no markdown manifest renderer and README has no sentence declaring markdown docs a non-goal. The facts those tables carry are asserted on the KD-07 machine-readable manifest in manifest_generator_surface_test.exs and json_manifest_generator_surface_test.exs"
    test "lists path helpers and no input types, since no fetch functions exist" do
      :ok
    end
  end

  describe "ManifestGenerator - typed controller routes section" do
    @tag skip:
           "GU-T9 gap (operator decision D24): the reference renders a markdown document (headers, tables with TS Zod/Valibot/Channel/Validation columns, typed queries, typed-controller routes); ash_surface has no markdown manifest renderer and README has no sentence declaring markdown docs a non-goal. The facts those tables carry are asserted on the KD-07 machine-readable manifest in manifest_generator_surface_test.exs and json_manifest_generator_surface_test.exs"
    test "includes Typed Controller Routes section header" do
      :ok
    end

    @tag skip:
           "GU-T9 gap (operator decision D24): the reference renders a markdown document (headers, tables with TS Zod/Valibot/Channel/Validation columns, typed queries, typed-controller routes); ash_surface has no markdown manifest renderer and README has no sentence declaring markdown docs a non-goal. The facts those tables carry are asserted on the KD-07 machine-readable manifest in manifest_generator_surface_test.exs and json_manifest_generator_surface_test.exs"
    test "includes route table with Method, Path, Function columns" do
      :ok
    end

    @tag skip:
           "GU-T9 gap (operator decision D24): the reference renders a markdown document (headers, tables with TS Zod/Valibot/Channel/Validation columns, typed queries, typed-controller routes); ash_surface has no markdown manifest renderer and README has no sentence declaring markdown docs a non-goal. The facts those tables carry are asserted on the KD-07 machine-readable manifest in manifest_generator_surface_test.exs and json_manifest_generator_surface_test.exs"
    test "lists the result type of routes declaring returns" do
      :ok
    end

    @tag skip:
           "GU-T9 gap (operator decision D24): the reference renders a markdown document (headers, tables with TS Zod/Valibot/Channel/Validation columns, typed queries, typed-controller routes); ash_surface has no markdown manifest renderer and README has no sentence declaring markdown docs a non-goal. The facts those tables carry are asserted on the KD-07 machine-readable manifest in manifest_generator_surface_test.exs and json_manifest_generator_surface_test.exs"
    test "includes route entries for configured routes" do
      :ok
    end

    @tag skip:
           "GU-T9 gap (operator decision D24): the reference renders a markdown document (headers, tables with TS Zod/Valibot/Channel/Validation columns, typed queries, typed-controller routes); ash_surface has no markdown manifest renderer and README has no sentence declaring markdown docs a non-goal. The facts those tables carry are asserted on the KD-07 machine-readable manifest in manifest_generator_surface_test.exs and json_manifest_generator_surface_test.exs"
    test "includes Zod Schema column when zod schemas enabled" do
      :ok
    end

    @tag skip:
           "GU-T9 gap (operator decision D24): the reference renders a markdown document (headers, tables with TS Zod/Valibot/Channel/Validation columns, typed queries, typed-controller routes); ash_surface has no markdown manifest renderer and README has no sentence declaring markdown docs a non-goal. The facts those tables carry are asserted on the KD-07 machine-readable manifest in manifest_generator_surface_test.exs and json_manifest_generator_surface_test.exs"
    test "includes Valibot Schema column when valibot schemas enabled" do
      :ok
    end

    @tag skip:
           "GU-T9 gap (operator decision D24): the reference renders a markdown document (headers, tables with TS Zod/Valibot/Channel/Validation columns, typed queries, typed-controller routes); ash_surface has no markdown manifest renderer and README has no sentence declaring markdown docs a non-goal. The facts those tables carry are asserted on the KD-07 machine-readable manifest in manifest_generator_surface_test.exs and json_manifest_generator_surface_test.exs"
    test "lists schemas for GET routes with query args" do
      :ok
    end

    @tag skip:
           "GU-T9 gap (operator decision D24): the reference renders a markdown document (headers, tables with TS Zod/Valibot/Channel/Validation columns, typed queries, typed-controller routes); ash_surface has no markdown manifest renderer and README has no sentence declaring markdown docs a non-goal. The facts those tables carry are asserted on the KD-07 machine-readable manifest in manifest_generator_surface_test.exs and json_manifest_generator_surface_test.exs"
    test "shows input type for mutation routes" do
      :ok
    end

    @tag skip:
           "GU-T9 gap (operator decision D24): the reference renders a markdown document (headers, tables with TS Zod/Valibot/Channel/Validation columns, typed queries, typed-controller routes); ash_surface has no markdown manifest renderer and README has no sentence declaring markdown docs a non-goal. The facts those tables carry are asserted on the KD-07 machine-readable manifest in manifest_generator_surface_test.exs and json_manifest_generator_surface_test.exs"
    test "shows dash for routes without input type" do
      :ok
    end
  end

  describe "ManifestGenerator - no typed controllers" do
    @tag skip:
           "GU-T9 gap (operator decision D24): the reference renders a markdown document (headers, tables with TS Zod/Valibot/Channel/Validation columns, typed queries, typed-controller routes); ash_surface has no markdown manifest renderer and README has no sentence declaring markdown docs a non-goal. The facts those tables carry are asserted on the KD-07 machine-readable manifest in manifest_generator_surface_test.exs and json_manifest_generator_surface_test.exs"
    test "omits section when no typed controllers configured" do
      :ok
    end
  end
end
