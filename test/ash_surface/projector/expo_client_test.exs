defmodule AshSurface.Projector.ExpoClientTest do
  @moduledoc """
  State-based tests of `AshSurface.Projector.Expo`'s client runtime factory
  emission (`{prefix}.mjs`) and TanStack adapter emission
  (`{prefix}.tanstack.mjs`).

  The client factory must wire `createClient` from the shipped runtime surface
  (`priv/static/ash_surface_runtime.mjs`) instead of duplicating it, and both
  artifacts must be syntactically self-consistent against the sibling
  artifacts manufactured in the same projection.
  """

  use ExUnit.Case, async: false

  alias Ash.Info.Manifest
  alias AshSurface.Fixtures.VolunteerMilestone
  alias AshSurface.Projector.Expo

  @prefix "zoela_surface"
  @client_file "#{@prefix}.mjs"
  @tanstack_file "#{@prefix}.tanstack.mjs"
  @tmp_dir Path.expand("../../../_build/test/projector_expo_client", __DIR__)

  setup do
    File.rm_rf!(@tmp_dir)
    File.mkdir_p!(@tmp_dir)

    assert {:ok, manifest} =
             Manifest.generate(
               otp_app: :ash_surface,
               action_entrypoints: [
                 {VolunteerMilestone, :record},
                 {VolunteerMilestone, :read}
               ]
             )

    profile = %{
      audience: :zoe_kingdom,
      actions: %{
        "AshSurface.Fixtures.VolunteerMilestone#record" => %{
          semanticId: "zoe:SelectOption",
          authorityBoundary: "SELECT",
          doAuthority: false,
          receiptRequired: true,
          evidenceRequired: true,
          possibleRefusals: ["AUTHORITY_REFUSED", "EVIDENCE_REQUIRED", "UNKNOWN_AFTER_DISPATCH"]
        }
      }
    }

    assert {:ok, surface} = AshSurface.from_manifest(manifest, profile: profile)

    assert {:ok, artifacts, meta} =
             AshSurface.project(surface, Expo, prefix: @prefix, target_dir: @tmp_dir)

    assert meta.prefix == @prefix
    assert meta.action_count == 2

    %{artifacts: artifacts}
  end

  describe "client runtime factory emission (zoela_surface.mjs)" do
    test "wires createClient from the shipped runtime surface, not a duplicated one", %{
      artifacts: artifacts
    } do
      client = artifacts[@client_file]

      # Golden fragment: the factory references the shipped runtime for
      # createClient and the sibling projections for schemas/actions metadata.
      assert client =~ """
             import { createClient } from "ash_surface";
             import { SCHEMAS } from "./#{@prefix}.schemas.mjs";
             import { ACTIONS } from "./#{@prefix}.actions.mjs";
             """

      # Golden fragment: createClient is invoked with the manufactured
      # schemas pre-bound, exactly as the projector documents.
      assert client =~ """
               const client = createClient({
                 contract,
                 transports,
                 prefer,
                 schemas: SCHEMAS,
               });
             """

      # The referenced symbol is owned by the shipped runtime surface, so the
      # emission wires the framework-neutral adapter shipped from priv/static.
      assert {:ok, runtime} = AshSurface.runtime_source()
      assert runtime =~ "export function createClient"
      assert Path.basename(AshSurface.runtime_path()) == "ash_surface_runtime.mjs"

      # Not a duplicated runtime: the emission must reference, never restate,
      # runtime implementation details.
      refute client =~ "function createClient(", "client emission duplicates createClient"
      refute client =~ "SURFACE_RUNTIME_VERSION", "client emission duplicates runtime version"
      refute client =~ "class SurfaceRuntimeError", "client emission duplicates runtime errors"

      refute client =~ "selectTransport",
             "client emission duplicates runtime transport selection"

      refute client =~ "from \"zod\"", "client emission duplicates the schema surface"
      refute client =~ "z.object(", "client emission inlines manufactured schemas"
    end

    test "returns the runtime client surface extended with actions metadata and offline reconcile",
         %{artifacts: artifacts} do
      client = artifacts[@client_file]

      # Golden fragment: the factory signature forwards contract, transports,
      # preference, and a reconcile endpoint.
      assert client =~
               "export function createZoelaClient({ contract, transports = {}, prefer = \"http\", reconcileEndpoint }) {"

      # Golden fragment: the runtime client is spread (preserving its frozen
      # surface: actions, resources, events, get, inspect, reconcile) and
      # extended with the manufactured ACTIONS metadata.
      assert client =~ """
               return Object.freeze({
                 ...client,
                 actionsMetadata: ACTIONS,
             """

      # Documented reconcile semantics: refuse without an endpoint, fall back
      # to STILL_UNKNOWN on a non-ok response.
      assert client =~ "async reconcile(commandId) {"
      assert client =~ "throw new Error(\"No reconcileEndpoint configured on client\");"
      assert client =~ "encodeURIComponent(commandId)"
      assert client =~ "if (!res.ok) return { status: \"STILL_UNKNOWN\" };"
      assert client =~ "return await res.json();"
    end
  end

  describe "tanstack adapter emission (zoela_surface.tanstack.mjs)" do
    test "exports the documented query key hierarchy", %{artifacts: artifacts} do
      tanstack = artifacts[@tanstack_file]

      # The adapter references the sibling actions artifact for metadata
      # instead of duplicating the ACTIONS catalog.
      assert tanstack =~ "import { getAction } from \"./#{@prefix}.actions.mjs\";"

      refute tanstack =~ "export const ACTIONS",
             "tanstack emission duplicates the ACTIONS catalog"

      # Golden fragment: stable, hierarchical query keys rooted at the
      # ash_surface namespace.
      assert tanstack =~ """
             export const queryKeys = {
               all: ["ash_surface"],
               resource: (res) => ["ash_surface", res],
               action: (res, act) => ["ash_surface", res, act],
             };
             """
    end

    test "exports createMutationOptions wired to receipt-bearing invocation", %{
      artifacts: artifacts
    } do
      tanstack = artifacts[@tanstack_file]

      assert tanstack =~ "export function createMutationOptions(client, actionId) {"
      assert tanstack =~ "const meta = getAction(actionId);"
      assert tanstack =~ "const action = client.get(actionId);"

      # Golden fragment: mutation keys derive from action metadata through the
      # query key hierarchy, and the mutation function preserves consequence
      # semantics by invoking with receipt rather than fire-and-forget.
      assert tanstack =~ """
               return {
                 mutationKey: queryKeys.action(meta?.resource, meta?.action),
                 mutationFn: async (input) => {
                   return await action.invokeWithReceipt(input);
                 }
               };
             """
    end
  end

  describe "syntactic self-consistency of both emissions" do
    test "both artifacts parse as ECMAScript modules under node --check" do
      for file <- [@client_file, @tanstack_file] do
        path = Path.join(@tmp_dir, file)

        {output, exit_code} = System.cmd("node", ["--check", path], stderr_to_stdout: true)

        assert exit_code == 0, "node --check failed on #{file}: #{output}"
      end
    end

    test "every relative import resolves to an artifact from the same projection", %{
      artifacts: artifacts
    } do
      for file <- [@client_file, @tanstack_file] do
        source = artifacts[file]

        relative_specs =
          for spec <- import_specifiers(source), String.starts_with?(spec, "./"), do: spec

        assert relative_specs != [], "expected #{file} to reference at least one sibling artifact"

        for spec <- relative_specs do
          assert Map.has_key?(artifacts, Path.basename(spec)),
                 "#{file} imports #{spec} which was not manufactured in this projection"
        end
      end
    end

    test "named imports are exported by the sibling artifacts they reference", %{
      artifacts: artifacts
    } do
      client = artifacts[@client_file]
      tanstack = artifacts[@tanstack_file]
      schemas = artifacts["#{@prefix}.schemas.mjs"]
      actions = artifacts["#{@prefix}.actions.mjs"]

      assert client =~ "import { SCHEMAS } from \"./#{@prefix}.schemas.mjs\";"
      assert schemas =~ "export const SCHEMAS = {"

      assert client =~ "import { ACTIONS } from \"./#{@prefix}.actions.mjs\";"
      assert actions =~ "export const ACTIONS = Object.freeze("

      assert tanstack =~ "import { getAction } from \"./#{@prefix}.actions.mjs\";"
      assert actions =~ "export function getAction("
    end

    test "both artifacts carry the shipped runtime's version in their generated headers", %{
      artifacts: artifacts
    } do
      assert {:ok, runtime} = AshSurface.runtime_source()

      [version] =
        Regex.run(~r/SURFACE_RUNTIME_VERSION = "([^"]+)"/, runtime, capture: :all_but_first)

      for file <- [@client_file, @tanstack_file] do
        assert artifacts[file] =~ "// @generated by AshSurface.Projector.Expo (CalVer #{version})"
      end
    end
  end

  defp import_specifiers(source) do
    ~r/from\s+"([^"]+)"/
    |> Regex.scan(source)
    |> Enum.map(fn [_, spec] -> spec end)
  end
end
