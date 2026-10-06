defmodule TokyoDepegSurfaceTest do
  @moduledoc """
  Plan W7 court: the Tokyo-Depeg burn-in dashboard as an ash_surface surface.

  Full real projection path, no mocks:

    authored manifest (priv/surfaces/tdb_burn_in_manifest.exs)
      -> AshSurface.from_manifest/2  (surface contract + digest)
      -> AshSurface.Compiler.compile/2 (IR sections per action)
      -> AshSurface.Projectors.JS.project_ir/2  (the .mjs client artifact)
      -> written to tmp/tdb-surface/
      -> executed by node (generated client + ash_surface_runtime.mjs createClient)

  Courts:
    * the surface digest is a verified fact (verify_surface_digest/1) and
      deterministic across constructions;
    * every action is a read-only observatory action (authorityBoundary
      "OBSERVE", doAuthority false, zero actuation authority in the client);
    * the JS render is byte-deterministic (two renders, identical sha256);
    * the generated client executes in node: namespaces, DESCRIPTOR-only
      descriptors, dispatchIntent refused (REFUSED_NOT_DO_BOUNDARY /
      REFUSED_UNKNOWN_ACTION);
    * the runtime `createClient` admits the surface contract and exposes the
      REFUSED_* stream per section.
  """

  use ExUnit.Case, async: false

  @manifest_file Path.expand("priv/surfaces/tdb_burn_in_manifest.exs", __DIR__ <> "/..")
  @repo_root Path.expand("..", __DIR__)
  @out_dir Path.expand("tmp/tdb-surface", @repo_root)
  @artifact "ash_surface_client.mjs"

  setup_all do
    Code.require_file(@manifest_file, __DIR__)

    manifest = Tdb.BurnIn.SurfaceManifest.manifest()
    profile = Tdb.BurnIn.SurfaceManifest.profile()

    {:ok, surface} = AshSurface.from_manifest(manifest, profile: profile)

    {:ok, irs} = AshSurface.Compiler.compile(manifest)

    %{surface: surface, manifest: manifest, profile: profile, irs: irs}
  end

  # -- Manifest / surface contract -------------------------------------------

  test "manifest describes exactly the four dashboard sections", %{
    manifest: manifest,
    surface: surface
  } do
    ids = Tdb.BurnIn.SurfaceManifest.action_ids()

    assert length(ids) == 4
    assert surface.action_ids == ids

    assert Enum.map(manifest.entrypoints, &AshSurface.action_id/1) |> Enum.sort() == ids

    for id <- ids do
      assert id =~ ~r/^Tdb\.BurnIn\.Resources\.(BurnCycleStatus|StageVerdicts|RefusalLedger|AlignmentCosts)#read$/
    end
  end

  test "surface digest is a verified, deterministic content address", %{surface: surface} do
    assert :ok = AshSurface.verify_surface_digest(surface)
    assert byte_size(surface.digest) == 64

    assert {:ok, surface2} =
             AshSurface.from_manifest(Tdb.BurnIn.SurfaceManifest.manifest(),
               profile: Tdb.BurnIn.SurfaceManifest.profile()
             )

    assert surface2.digest == surface.digest
  end

  test "every dashboard action is a read-only observatory action in the contract", %{
    surface: surface
  } do
    actions = surface.contract["surface"]["actions"]
    assert length(actions) == 4

    for action <- actions do
      assert action["action"] == "read"
      assert action["resource"] =~ ~r/^Tdb\.BurnIn\./
      assert action["semanticId"] =~ ~r/^tdb:/
      assert action["authorityBoundary"] == "OBSERVE"
      assert action["doAuthority"] == false
      assert action["receiptRequired"] == true
      assert action["evidenceRequired"] == true
      assert is_list(action["possibleRefusals"]) and action["possibleRefusals"] != []

      assert Enum.all?(action["possibleRefusals"], &String.starts_with?(&1, "REFUSED_"))
    end

    refusal_ledger =
      Enum.find(actions, &(&1["semanticId"] == "tdb:RefusalLedger"))

    assert "REFUSED_CONFORMANCE_DEVIATION" in refusal_ledger["possibleRefusals"]
    assert "REFUSED_AUTHORITY_REVOKED" in refusal_ledger["possibleRefusals"]
    assert "REFUSED_LEASE_EXPIRED" in refusal_ledger["possibleRefusals"]
    assert "REFUSED_DUPLICATE_EFFECT" in refusal_ledger["possibleRefusals"]
  end

  # -- Compiler IR ------------------------------------------------------------

  test "compiler admits the manifest into one IR per section, refuse-fail-closed",
       %{manifest: manifest, irs: irs} do
    assert length(irs) == 4

    assert {:error, :no_sections} =
             AshSurface.Compiler.compile(manifest, sections: [])

    assert {:error, {:missing_section_keys, missing}} =
             AshSurface.Compiler.compile(manifest, sections: [ash: AshSurface.Compiler.Section.Ash])

    assert [:semantic, :capability, :presentation, :schema] -- missing == []
  end

  test "compiler IR is deterministic across compiles", %{manifest: manifest, irs: irs} do
    assert {:ok, irs2} = AshSurface.Compiler.compile(manifest)
    assert irs == irs2
  end

  # -- JS projection (byte-deterministic render) ------------------------------

  test "JS render is byte-deterministic; artifact written to tmp/tdb-surface", %{
    irs: irs
  } do
    assert {:ok, artifacts1, meta1} =
             AshSurface.Projectors.JS.project_ir(irs, target_dir: @out_dir)

    assert {:ok, artifacts2, meta2} =
             AshSurface.Projectors.JS.project_ir(irs)

    assert meta1 == %{prefix: "ash_surface_client", action_count: 4, namespace_count: 4}
    assert meta2 == meta1

    code1 = artifacts1[@artifact]
    code2 = artifacts2[@artifact]
    assert is_binary(code1) and code1 == code2

    digest = :crypto.hash(:sha256, code1) |> Base.encode16(case: :lower)

    # digest of the in-memory render == digest of the on-disk artifact
    on_disk = File.read!(Path.join(@out_dir, @artifact))
    assert :crypto.hash(:sha256, on_disk) |> Base.encode16(case: :lower) == digest

    File.write!(Path.join(@out_dir, "render_digest.txt"), digest <> "\n")

    # namespaces: one per section, sorted
    for ns <- ["AlignmentCosts", "BurnCycleStatus", "RefusalLedger", "StageVerdicts"] do
      assert code1 =~ "export const #{ns} = Object.freeze({"
    end

    # read-only observatory law in the artifact: DESCRIPTOR-only, no DO boundary
    assert code1 =~ ~r/descriptorKind: "DESCRIPTOR"/
    refute code1 =~ ~r/descriptorKind: "DISPATCH_INTENT"/
  end

  # -- Node execution court ---------------------------------------------------

  test "generated client + runtime createClient execute under node", %{surface: surface} do
    contract_path = Path.join(@out_dir, "tdb_surface_contract.json")
    File.write!(contract_path, Jason.encode!(surface.contract))

    runner = Path.join(@out_dir, "node_court.mjs")

    File.write!(runner, """
    import { readFileSync } from "node:fs";
    import assert from "node:assert/strict";
    import { createClient } from "#{@repo_root}/priv/static/ash_surface_runtime.mjs";
    import {
      ACTIONS,
      NAMESPACES,
      SCHEMAS,
      getAction,
      dispatchIntent,
    } from "#{Path.join(@out_dir, @artifact)}";

    const ids = [
      "Tdb.BurnIn.Resources.AlignmentCosts#read",
      "Tdb.BurnIn.Resources.BurnCycleStatus#read",
      "Tdb.BurnIn.Resources.RefusalLedger#read",
      "Tdb.BurnIn.Resources.StageVerdicts#read",
    ];

    // 1. The generated client artifact: four namespaces, four descriptors,
    //    all DESCRIPTOR (never DISPATCH_INTENT), unknown action refused.
    assert.equal(Object.keys(NAMESPACES).length, 4);
    assert.equal(ACTIONS.length, 4);
    for (const ns of ["AlignmentCosts", "BurnCycleStatus", "RefusalLedger", "StageVerdicts"]) {
      assert.ok(NAMESPACES[ns], ns);
    }

    const entry = getAction("BurnCycleStatus.read");
    assert.ok(entry);
    assert.equal(entry.descriptorKind, "DESCRIPTOR");
    assert.equal(entry.actionType, "read");
    assert.equal(entry.receiptRequired, false); // honest nil: resource not AshA2A-registered

    assert.throws(() => dispatchIntent("BurnCycleStatus.read", {}),
      /REFUSED_NOT_DO_BOUNDARY/);
    assert.throws(() => dispatchIntent("Nope.read", {}), /REFUSED_UNKNOWN_ACTION/);

    // 2. The surface runtime admits the surface contract.
    const contract = JSON.parse(readFileSync("#{contract_path}", "utf8"));
    const client = createClient({ contract });

    assert.equal(Object.keys(client.actions).length, 4);
    for (const id of ids) {
      const a = client.get(id);
      assert.ok(a, id);
      assert.equal(a.authorityBoundary, "OBSERVE");
      assert.equal(a.doAuthority, false);
      assert.equal(a.profile.receiptRequired, true);
      assert.ok(a.possibleRefusals.every((code) => code.startsWith("REFUSED_")));
      assert.ok(Object.isFrozen(a.possibleRefusals));
    }

    const ledger = client.get("Tdb.BurnIn.Resources.RefusalLedger#read");
    for (const code of [
      "REFUSED_CONFORMANCE_DEVIATION",
      "REFUSED_AUTHORITY_REVOKED",
      "REFUSED_LEASE_EXPIRED",
      "REFUSED_DUPLICATE_EFFECT",
    ]) {
      assert.ok(ledger.possibleRefusals.includes(code), code);
    }

    console.log("node court ok: 4 DESCRIPTOR actions; createClient admits the tdb contract");
    """)

    {output, exit_code} = System.cmd("node", [runner], cd: @repo_root, stderr_to_stdout: true)

    assert exit_code == 0, "node court failed:\n#{output}"
    assert output =~ "node court ok"
  end
end
