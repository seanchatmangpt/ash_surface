defmodule AshSurface.Projector.ExpoReceiptsHashTest do
  @moduledoc """
  Formula pins for the receiptHash integrity law (chicago-receipthash-038).

  The subject is the REAL emitted artifact: a live surface is projected through
  `AshSurface.Projector.Expo`, the receipts emission is written to disk and
  executed under Node — no doubles. The law pinned:

    receiptHash = lowercase-hex SHA-256 over canonical JSON (recursively
    key-sorted objects, order-preserving arrays) of the receipt's named
    content fields EXCLUDING the receiptHash slot itself.

  Independence: the expected preimage is a hand-written byte literal, and the
  golden hash was computed outside both runtimes (shell `shasum -a 256` over
  the same literal). The emitted module, the Elixir canonical encoder, and the
  golden constant must all agree on those exact bytes.
  """

  use ExUnit.Case, async: false

  alias Ash.Info.Manifest
  alias AshSurface.Fixtures.VolunteerMilestone
  alias AshSurface.Projector.Expo

  @prefix "zoela_surface"
  @tmp_dir Path.expand("../../../_build/test/receipthash", __DIR__)

  # The named content fields of the envelope fixture, hand-sorted for the
  # canonical bytes. receiptHash itself is deliberately absent.
  @expected_preimage ~s({"actionId":"Zoela.KingdomNeed#select_option","actorRef":"member_zoela_01","authorityBoundary":"SELECT","correlationId":"cmd_rh_038","domainReceiptRef":"rcpt_srv_9","episodeId":"ep_2026_09_17_001","evidenceRefs":["ev_1","ev_2"],"exactSubject":"Zoela.KingdomNeed:need_42","inputDigest":"in_d3","outcome":"COMPLETED","policyRef":"pol/v26.9.17","postStateDigest":"sd_post_b2","preStateDigest":"sd_pre_a1","replayKey":"rk_001","semanticActionId":"zoe:SelectOption","standingAfter":"ALIVE","standingBefore":"ALIVE","taskNetworkRef":"tn_7","timestamp":"2026-09-17T06:30:00Z","transportReceipt":{"dispatchState":"completed","selected":"http"}})

  # Golden vector computed independently of both runtimes:
  # `shasum -a 256` over the literal above.
  @golden_hash "a6bfe0ce6bede0a0d788445f06c356a024cf6fe1e69cb50bc7747730811599b9"

  # Canonical insertion order (matches the sorted literal).
  @content_pairs [
    {"actionId", "Zoela.KingdomNeed#select_option"},
    {"actorRef", "member_zoela_01"},
    {"authorityBoundary", "SELECT"},
    {"correlationId", "cmd_rh_038"},
    {"domainReceiptRef", "rcpt_srv_9"},
    {"episodeId", "ep_2026_09_17_001"},
    {"evidenceRefs", ["ev_1", "ev_2"]},
    {"exactSubject", "Zoela.KingdomNeed:need_42"},
    {"inputDigest", "in_d3"},
    {"outcome", "COMPLETED"},
    {"policyRef", "pol/v26.9.17"},
    {"postStateDigest", "sd_post_b2"},
    {"preStateDigest", "sd_pre_a1"},
    {"replayKey", "rk_001"},
    {"semanticActionId", "zoe:SelectOption"},
    {"standingAfter", "ALIVE"},
    {"standingBefore", "ALIVE"},
    {"taskNetworkRef", "tn_7"},
    {"timestamp", "2026-09-17T06:30:00Z"},
    {"transportReceipt", %{"dispatchState" => "completed", "selected" => "http"}}
  ]

  setup do
    assert @golden_hash ==
             :crypto.hash(:sha256, @expected_preimage) |> Base.encode16(case: :lower),
           "golden hash must equal the shell-computed digest of the preimage literal"

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
          doAuthority: false
        }
      }
    }

    assert {:ok, surface} = AshSurface.from_manifest(manifest, profile: profile)
    assert {:ok, artifacts, _meta} = AshSurface.project(surface, Expo, prefix: @prefix)

    File.rm_rf!(@tmp_dir)
    File.mkdir_p!(@tmp_dir)

    receipts_path = Path.join(@tmp_dir, "#{@prefix}.receipts.mjs")
    File.write!(receipts_path, Map.fetch!(artifacts, "#{@prefix}.receipts.mjs"))

    runner_path = Path.join(@tmp_dir, "preimage_runner.mjs")
    File.write!(runner_path, preimage_runner())

    %{tmp_dir: @tmp_dir}
  end

  # Executes the REAL emitted receipts.mjs. Each fixture is a list of
  # [key, value] pairs so the test controls the object's insertion order in
  # the JS runtime; the runner reports the emitted preimage bytes, their
  # sha256 (platform crypto), and whether the hash binds the receiptHash slot.
  defp preimage_runner do
    """
    import { readFileSync } from "node:fs";
    import crypto from "node:crypto";
    import { receiptHashPreimage } from "./#{@prefix}.receipts.mjs";

    const fixtures = JSON.parse(readFileSync(process.argv[2], "utf-8"));
    const results = fixtures.map(function (fixture) {
      const receipt = Object.fromEntries(fixture.pairs);
      const preimage = receiptHashPreimage(receipt);
      const hash = crypto.createHash("sha256").update(preimage).digest("hex");
      return {
        name: fixture.name,
        preimage: preimage,
        hash: hash,
        binds: hash === receipt.receiptHash
      };
    });
    process.stdout.write(JSON.stringify(results));
    """
  end

  defp run_preimage_runner(fixtures) do
    fixtures_path = Path.join(@tmp_dir, "fixtures.json")
    File.write!(fixtures_path, Jason.encode!(fixtures))

    {output, exit_code} =
      System.cmd("node", [Path.join(@tmp_dir, "preimage_runner.mjs"), fixtures_path],
        stderr_to_stdout: true
      )

    assert exit_code == 0, "preimage runner failed (exit #{exit_code}): #{output}"

    assert {:ok, results} = Jason.decode(output)
    results
  end

  defp receipt_with_hash(pairs) do
    # JSON has no tuples: pairs cross to the runner as [key, value] arrays, so
    # Object.fromEntries builds the receipt with exactly this insertion order.
    (pairs ++ [{"receiptHash", @golden_hash}])
    |> Enum.map(fn {key, value} -> [key, value] end)
  end

  test "emitted receiptHashPreimage reproduces the exact canonical preimage bytes and the golden hash" do
    [result] =
      run_preimage_runner([
        %{"name" => "canonical", "pairs" => receipt_with_hash(@content_pairs)}
      ])

    # The emitted formula emits exactly the documented canonical bytes.
    assert result["preimage"] == @expected_preimage

    # The emitted bytes hash to the shell-computed golden vector...
    assert result["hash"] == @golden_hash

    # ...and the hash binds the receipt's receiptHash slot.
    assert result["binds"] == true
  end

  test "the Elixir canonical encoder lands on the same golden bytes for the same named fields" do
    content = Map.new(@content_pairs)

    # Same formula, Elixir owner of the canonical-bytes law: hash over the
    # named content fields, never over the receiptHash slot.
    assert AshSurface.CanonicalJSON.sha256_hex(content) == @golden_hash

    # Byte-level agreement, not just digest agreement.
    assert AshSurface.CanonicalJSON.encode(content) == @expected_preimage
  end

  test "reorder-invariant: reversed insertion order in the JS runtime yields identical bytes and hash" do
    [canonical, reversed] =
      run_preimage_runner([
        %{"name" => "canonical", "pairs" => receipt_with_hash(@content_pairs)},
        %{"name" => "reversed", "pairs" => receipt_with_hash(Enum.reverse(@content_pairs))}
      ])

    assert reversed["preimage"] == canonical["preimage"]
    assert reversed["preimage"] == @expected_preimage
    assert reversed["hash"] == @golden_hash
    assert reversed["binds"] == true
  end

  test "value-sensitive: one changed content value moves the preimage and the hash (unbound slot refuses)" do
    tampered_pairs =
      Enum.map(@content_pairs, fn
        {"outcome", _} -> {"outcome", "REFUSED"}
        {"postStateDigest", _} -> {"postStateDigest", "sd_post_c3"}
        pair -> pair
      end)

    [canonical, tampered] =
      run_preimage_runner([
        %{"name" => "canonical", "pairs" => receipt_with_hash(@content_pairs)},
        %{"name" => "tampered", "pairs" => receipt_with_hash(tampered_pairs)}
      ])

    refute tampered["preimage"] == canonical["preimage"]
    refute tampered["hash"] == @golden_hash

    # A receipt whose content moved but whose receiptHash slot was not
    # re-minted fails the binding: the hash is value-sensitive evidence.
    assert tampered["binds"] == false
  end

  test "typed refusal: the emitted preimage formula refuses non-envelope subjects" do
    fixtures_path = Path.join(@tmp_dir, "refusal_fixtures.json")
    File.write!(fixtures_path, Jason.encode!([%{"name" => "scalar", "pairs" => 42}]))

    {output, exit_code} =
      System.cmd("node", [Path.join(@tmp_dir, "preimage_runner.mjs"), fixtures_path],
        stderr_to_stdout: true
      )

    refute exit_code == 0, "non-envelope receipt must be refused, got: #{output}"
    assert output =~ "TypeError"
  end
end
