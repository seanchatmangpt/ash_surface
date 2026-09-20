defmodule AshSurface.ConsumerFixtureTest do
  use ExUnit.Case, async: false

  alias Ash.Info.Manifest
  alias AshSurface.Fixtures.{Server, VolunteerMilestone}

  @tmp_dir Path.expand("../../_build/test/fixtures", __DIR__)

  setup do
    File.mkdir_p!(@tmp_dir)

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

    # 5. Bind verification to the exact consequence identity emitted by the
    # consumer receipt. The ETS resource is shared across end-to-end courts,
    # so member_id alone is not a unique execution identity.
    assert File.exists?(receipt_path)
    receipt_json = File.read!(receipt_path)
    assert {:ok, receipt} = Jason.decode(receipt_json)

    # 6. Observe the exact physical Ash action consequence in ETS data layer
    assert {:ok, records} =
             Ash.read(VolunteerMilestone, domain: AshSurface.Fixtures.Domain)

    consequence_id = get_in(receipt, ["consequence", "id"])

    assert is_binary(consequence_id),
           "Expected receipt to bind the exact Ash consequence identity"

    successful_record = Enum.find(records, fn r -> r.id == consequence_id end)

    refute is_nil(successful_record),
           "Expected the receipt-bound Ash consequence to exist in the data layer"
    assert successful_record.milestone_id == "milestone_serve_42"
    assert successful_record.cost_physical == 10
    assert successful_record.reward_spiritual == 100
    assert successful_record.status == "completed"

    # Confirm that the failed post-dispatch action also physically created a record,
    # proving why UNKNOWN_AFTER_DISPATCH is legally required: silent fallback would duplicate!
    failed_record =
      Enum.find(records, fn r -> r.member_id == "member_fail" end)

    refute is_nil(failed_record),
           "Expected record from post-dispatch disconnect to exist in Ash data layer"

    # 7. Verify cryptographic execution receipt
    assert receipt["actionId"] == "AshSurface.Fixtures.VolunteerMilestone#record"
    assert receipt["dispatchState"] == "completed"
    assert receipt["selectedTransport"] == "http"
    assert receipt["input"]["member_id"] == "member_zoela_01"
    assert receipt["consequence"]["id"] == successful_record.id
    assert is_binary(receipt["receiptHash"])
    assert byte_size(receipt["receiptHash"]) == 64

    # 8. Replay / verification: confirm receipt matches consequence proof
    receipt_payload = %{
      "actionId" => receipt["actionId"],
      "input" => receipt["input"],
      "consequence" => receipt["consequence"],
      "dispatchState" => receipt["dispatchState"],
      "selectedTransport" => receipt["selectedTransport"],
      "timestamp" => receipt["timestamp"]
    }

    expected_hash =
      :crypto.hash(:sha256, canonical_json(receipt_payload))
      |> Base.encode16(case: :lower)

    assert receipt["receiptHash"] == expected_hash
  end

  defp canonical_json(val) when is_map(val) do
    inner =
      val
      |> Enum.sort_by(fn {k, _} -> to_string(k) end)
      |> Enum.map(fn {k, v} -> "#{Jason.encode!(to_string(k))}:#{canonical_json(v)}" end)
      |> Enum.join(",")

    "{" <> inner <> "}"
  end

  defp canonical_json(val) when is_list(val) do
    "[" <> Enum.map_join(val, ",", &canonical_json/1) <> "]"
  end

  defp canonical_json(val), do: Jason.encode!(val)
end
