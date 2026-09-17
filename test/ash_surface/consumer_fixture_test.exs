defmodule AshSurface.ConsumerFixtureTest do
  use ExUnit.Case, async: false

  alias Ash.Info.Manifest
  alias AshSurface.Fixtures.{Server, VolunteerMilestone}

  @tmp_dir Path.expand("../../_build/test/fixtures", __DIR__)

  setup do
    File.mkdir_p!(@tmp_dir)

    # The Ash ETS data layer is a shared (non-private) ordered set, so records
    # created by earlier tests in the same run leak into the read below. The
    # episode suite dispatches the same runner and the same member_zoela_01
    # input, making Enum.find/1 (ordered by random UUID pkey) return a stale
    # record and fail the receipt-id binding. Reset the fixture table so this
    # test observes only its own consequences, independent of test order.
    if :ets.whereis(VolunteerMilestone) != :undefined do
      :ets.delete_all_objects(VolunteerMilestone)
    end

    {:ok, server_pid} = Server.start_link()
    port = Server.get_port(server_pid)

    on_exit(fn ->
      if Process.alive?(server_pid), do: Server.stop(server_pid)
    end)

    {:ok, server_pid: server_pid, port: port}
  end

  test "full end-to-end consumer execution: manifest -> surface -> JS runtime -> HTTP dispatch -> Ash consequence -> cryptographic receipt",
       %{port: port} do
    # 1. Ash manifest generation from real Ash resource
    assert {:ok, manifest} =
             Manifest.generate(
               otp_app: :ash_surface,
               action_entrypoints: [
                 {VolunteerMilestone, :record},
                 {VolunteerMilestone, :read}
               ]
             )

    # 2. AshSurface projection with explicit transport preference
    profile = %{
      audience: :public,
      actions: %{
        "AshSurface.Fixtures.VolunteerMilestone#record" => %{
          consumer: :mobile,
          transport: :http
        }
      }
    }

    assert {:ok, surface} = AshSurface.from_manifest(manifest, profile: profile)
    assert is_binary(surface.digest)

    # 3. Write verified cross-language contract
    contract_path = Path.join(@tmp_dir, "e2e_contract.json")
    receipt_path = Path.join(@tmp_dir, "e2e_receipt.json")
    File.write!(contract_path, Jason.encode!(surface.contract))

    # 4. Execute JavaScript consumer fixture over Node.js
    {output, exit_code} =
      System.cmd("node", [
        "test/js/consumer_e2e_runner.mjs",
        contract_path,
        to_string(port),
        receipt_path
      ])

    assert exit_code == 0, "Node runner failed with exit code #{exit_code}: #{output}"

    # 5. Observe physical Ash action consequence in ETS data layer
    assert {:ok, records} =
             Ash.read(VolunteerMilestone, domain: AshSurface.Fixtures.Domain)

    # Confirm that the failed post-dispatch action also physically created a record,
    # proving why UNKNOWN_AFTER_DISPATCH is legally required: silent fallback would duplicate!
    failed_record =
      Enum.find(records, fn r -> r.member_id == "member_fail" end)

    refute is_nil(failed_record),
           "Expected record from post-dispatch disconnect to exist in Ash data layer"

    # 6. Verify cryptographic execution receipt
    assert File.exists?(receipt_path)
    receipt_json = File.read!(receipt_path)
    assert {:ok, receipt} = Jason.decode(receipt_json)

    assert receipt["actionId"] == "AshSurface.Fixtures.VolunteerMilestone#record"
    assert receipt["dispatchState"] == "completed"
    assert receipt["selectedTransport"] == "http"
    assert receipt["input"]["member_id"] == "member_zoela_01"

    # The successful consequence is identified by the receipt's OWN consequence
    # id, never by first-match on member_id: the ETS data layer is shared across
    # test modules for this whole run (the MX closed-loop suites dispatch the
    # same runner with the same member_id), so member_id lookup is
    # order-dependent across test modules and races the seed.
    successful_record =
      Enum.find(records, fn r -> r.id == receipt["consequence"]["id"] end)

    refute is_nil(successful_record),
           "Receipt consequence #{inspect(receipt["consequence"]["id"])} has no physical record in the Ash data layer"

    assert successful_record.member_id == "member_zoela_01"
    assert successful_record.milestone_id == "milestone_serve_42"
    assert successful_record.cost_physical == 10
    assert successful_record.reward_spiritual == 100
    assert successful_record.status == "completed"
    assert is_binary(receipt["receiptHash"])
    assert byte_size(receipt["receiptHash"]) == 64

    # 7. Replay / verification: confirm receipt matches consequence proof
    receipt_payload = %{
      "actionId" => receipt["actionId"],
      "input" => receipt["input"],
      "consequence" => receipt["consequence"],
      "dispatchState" => receipt["dispatchState"],
      "selectedTransport" => receipt["selectedTransport"],
      "timestamp" => receipt["timestamp"]
    }

    expected_hash = AshSurface.CanonicalJSON.sha256_hex(receipt_payload)

    assert receipt["receiptHash"] == expected_hash
  end

  test "runtime receipt back-projection replays to the identical observation event",
       %{port: port} do
    # 1-3. Same manufacturing pass as the e2e receipt test: manifest -> surface
    # -> cross-language contract, this time to feed the REAL node-runtime
    # receipt through the production back-projection route (finish-replay-020).
    assert {:ok, manifest} =
             Manifest.generate(
               otp_app: :ash_surface,
               action_entrypoints: [
                 {VolunteerMilestone, :record},
                 {VolunteerMilestone, :read}
               ]
             )

    profile = %{
      audience: :public,
      actions: %{
        "AshSurface.Fixtures.VolunteerMilestone#record" => %{
          consumer: :mobile,
          transport: :http
        }
      }
    }

    assert {:ok, surface} = AshSurface.from_manifest(manifest, profile: profile)

    contract_path = Path.join(@tmp_dir, "replay_contract.json")
    receipt_path = Path.join(@tmp_dir, "replay_receipt.json")
    File.write!(contract_path, Jason.encode!(surface.contract))

    # 4. Mint a real receipt through the node runtime over the wire.
    {output, exit_code} =
      System.cmd("node", [
        "test/js/consumer_e2e_runner.mjs",
        contract_path,
        to_string(port),
        receipt_path
      ])

    assert exit_code == 0, "Node runner failed with exit code #{exit_code}: #{output}"

    assert {:ok, receipt} = Jason.decode(File.read!(receipt_path))

    ir_action = %{
      "resource" => "AshSurface.Fixtures.VolunteerMilestone",
      "action" => "record"
    }

    # 5. Production route: the receipt reaches the observation stream ONLY
    # through the back-projection, and replaying it yields the identical event.
    assert {:ok, event} = AshSurface.Event.from_receipt(receipt, ir_action)
    assert {:ok, replayed} = AshSurface.Event.from_receipt(receipt, ir_action)

    assert replayed == event

    assert AshSurface.Event.to_map(replayed) == AshSurface.Event.to_map(event)

    # 6. The projection invents nothing: every section is carried verbatim.
    assert event.receipt_ref == receipt["receiptHash"]
    assert event.payload == receipt["consequence"]

    assert {:ok, ts, 0} = DateTime.from_iso8601(receipt["timestamp"])
    assert event.occurred_at == ts

    # 7. Replay equality survives a different serialization order of the same
    # receipt content: identity is canonical, never map-order derived.
    permuted =
      Map.update!(receipt, "consequence", fn c ->
        c |> Map.to_list() |> Enum.reverse() |> Map.new()
      end)

    assert {:ok, permuted_event} = AshSurface.Event.from_receipt(permuted, ir_action)
    assert permuted_event == event

    # 8. Cross-language digest law: the lib canonical encoder re-derives the
    # JS-minted receiptHash over the same sorted-key bytes.
    assert AshSurface.CanonicalJSON.sha256_hex(Map.drop(receipt, ["receiptHash"])) ==
             receipt["receiptHash"]
  end
end
