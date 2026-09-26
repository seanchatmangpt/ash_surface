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

    # 8. Replay / verification: confirm receipt matches consequence proof
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

  test "closed loop: intent -> live HTTP dispatch -> receipt -> event back-projection -> observation -> projector bytes on disk",
       %{port: port} do
    # -- Stage 0: admit the surface from the real Ash resource --------------
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

    contract_path = Path.join(@tmp_dir, "loop_contract.json")
    receipt_path = Path.join(@tmp_dir, "loop_receipt.json")
    File.write!(contract_path, Jason.encode!(surface.contract))

    # -- Stage 1 END-STATE: the intent exists as content-addressed data -----
    # The manufactured edge: one aimed action id, one payload, one subject.
    # The payload is exactly what the consumer runtime will dispatch, so the
    # loop below is ONE consequence graph, not adjacent fragments.
    input = %{
      member_id: "member_zoela_01",
      milestone_id: "milestone_serve_42",
      cost_physical: 10,
      reward_spiritual: 100
    }

    subject_ref = "ash:AshSurface.Fixtures.VolunteerMilestone#record"

    intent =
      AshSurface.Intent.create(
        "AshSurface.Fixtures.VolunteerMilestone#record",
        input,
        subject_ref
      )

    # Content-addressed identity: same triple, same id, any time.
    assert intent.intent_id ==
             :crypto.hash(:sha256, Jason.encode!([intent.surface_action_id, input, subject_ref]))
             |> Base.encode16(case: :lower)

    intent_map = AshSurface.Intent.to_map(intent)
    assert intent_map["surfaceActionId"] == intent.surface_action_id

    # -- Stage 2: the REAL node runtime dispatches over live HTTP -----------
    {output, exit_code} =
      System.cmd("node", [
        "test/js/consumer_e2e_runner.mjs",
        contract_path,
        to_string(port),
        receipt_path
      ])

    assert exit_code == 0, "Node runner failed with exit code #{exit_code}: #{output}"

    # -- Stage 3 END-STATE: the on-disk receipt binds the intent to the
    #    physical Ash consequence ------------------------------------------
    assert File.exists?(receipt_path)
    assert {:ok, receipt} = Jason.decode(File.read!(receipt_path))

    # The dispatched action and payload are EXACTLY the intent's aimed edge.
    assert receipt["actionId"] == intent.surface_action_id

    assert AshSurface.CanonicalJSON.encode(receipt["input"]) ==
             AshSurface.CanonicalJSON.encode(intent_map["input"])

    assert receipt["dispatchState"] == "completed"
    assert receipt["selectedTransport"] == "http"

    # The receipt is self-verifying: its hash binds its own content.
    assert receipt["receiptHash"] == recomputed_receipt_hash(receipt)

    # The receipt's consequence id names a REAL record in the Ash data layer.
    assert {:ok, records} =
             Ash.read(VolunteerMilestone, domain: AshSurface.Fixtures.Domain)

    successful_record =
      Enum.find(records, fn r -> r.id == receipt["consequence"]["id"] end)

    refute is_nil(successful_record),
           "Receipt consequence #{inspect(receipt["consequence"]["id"])} has no physical record in the Ash data layer"

    assert successful_record.member_id == "member_zoela_01"

    # -- Stage 4 END-STATE: the receipt back-projects to the observation-stream
    #    event through the one production route ------------------------------
    ir_action = %{
      "resource" => "AshSurface.Fixtures.VolunteerMilestone",
      "action" => "record"
    }

    assert {:ok, event} = AshSurface.Event.from_receipt(receipt, ir_action)

    # The projection invents nothing: every section is carried verbatim.
    assert event.receipt_ref == receipt["receiptHash"]
    assert event.payload == receipt["consequence"]
    assert event.subject_ref == subject_ref
    assert event.authority_boundary == :OBSERVE

    assert {:ok, ts, 0} = DateTime.from_iso8601(receipt["timestamp"])
    assert event.occurred_at == ts

    # -- Stage 5 END-STATE: the observation of the REAL data-layer state,
    #    citing the loop's receipt as its evidence ---------------------------
    facts = %{
      "member_id" => successful_record.member_id,
      "milestone_id" => successful_record.milestone_id,
      "cost_physical" => successful_record.cost_physical,
      "reward_spiritual" => successful_record.reward_spiritual,
      "status" => successful_record.status
    }

    observation =
      AshSurface.Observation.create(event.subject_ref, facts,
        evidence_refs: [receipt["receiptHash"]]
      )

    # Content-addressed: digest is sha256 over subject + canonical facts.
    expected_digest =
      :crypto.hash(:sha256, "#{event.subject_ref}:#{AshSurface.CanonicalJSON.encode(facts)}")
      |> Base.encode16(case: :lower)

    assert observation.state_digest == expected_digest
    assert observation.observation_id == "obs_" <> binary_part(expected_digest, 0, 16)
    assert observation.exact_subject == event.subject_ref
    assert observation.standing == :ALIVE
    assert observation.authority_boundary == :OBSERVE
    assert observation.evidence_refs == [receipt["receiptHash"]]

    # -- Stage 6 END-STATE: one projector renders the loop's surface to
    #    deterministic bytes on disk ------------------------------------------
    assert {:ok, ash_section} = AshSurface.Compiler.AshTruth.build(VolunteerMilestone, :record)

    # One delegated aria fact set, reused verbatim in the IR and in the final
    # end-state read-back: the projector must carry these, never invent.
    delegated_aria_inputs = %{
      "member_id" => %{"role" => "textbox", "required" => true},
      "milestone_id" => %{"role" => "textbox", "required" => true},
      "cost_physical" => %{"role" => "spinbutton", "required" => true},
      "reward_spiritual" => %{"role" => "spinbutton", "required" => true}
    }

    ir =
      AshSurface.IR.new(
        ash: ash_section,
        presentation: %AshSurface.IR.Presentation{
          label: "Record volunteer milestone",
          group: "serving",
          order: 1
        },
        schema: %AshSurface.IR.Schema{aria: %{"inputs" => delegated_aria_inputs}}
      )

    aria_prefix = "loop_aria"

    assert {:ok, aria_contract, aria_meta} =
             AshSurface.Projectors.ARIA.project_ir(ir,
               prefix: aria_prefix,
               target_dir: @tmp_dir
             )

    assert aria_meta == %{
             prefix: aria_prefix,
             surface_count: 1,
             group_count: 1,
             emitted: aria_prefix <> ".json"
           }

    aria_path = Path.join(@tmp_dir, aria_prefix <> ".json")
    assert File.exists?(aria_path)

    # The emitted bytes ARE the contract rendering, and re-projection is
    # byte-identical: the artifact is deterministic, not incidental.
    on_disk = File.read!(aria_path)
    assert on_disk == AshSurface.Projectors.ARIA.to_json(aria_contract)

    assert {:ok, rerendered, _meta} = AshSurface.Projectors.ARIA.project_ir(ir)
    assert AshSurface.Projectors.ARIA.to_json(rerendered) == on_disk

    # The on-disk artifact names the loop's own surface identity.
    decoded = Jason.decode!(on_disk)
    assert decoded["tabOrder"] == ["VolunteerMilestone.record"]
    assert [rendered_surface] = decoded["surfaces"]
    assert rendered_surface["id"] == "VolunteerMilestone.record"
    assert rendered_surface["resource"] == "VolunteerMilestone"
    assert rendered_surface["action"] == "record"
    assert rendered_surface["label"] == "Record volunteer milestone"

    # Rendered inputs are the intent's own input surface — exactly the members
    # the human aimed, no more, no fewer — and exactly the REAL Ash accept list
    # of the dispatched action. Two end-state bindings, one artifact.
    rendered_names = rendered_surface["inputs"] |> Enum.map(& &1["name"]) |> Enum.sort()

    assert rendered_names ==
             intent.input |> Map.keys() |> Enum.map(&to_string/1) |> Enum.sort()

    accept_names =
      VolunteerMilestone
      |> Ash.Resource.Info.action(:record)
      |> Map.get(:accept)
      |> Enum.map(&to_string/1)
      |> Enum.sort()

    assert rendered_names == accept_names,
           "rendered aria inputs diverged from the REAL Ash accept list"

    # Every rendered `required` fact matches the REAL attribute law of the
    # resource (`allow_nil?`), and every rendered role is the delegated aria
    # fact read verbatim — the artifact carries admitted facts, never guesses.
    for {name, facts} <- delegated_aria_inputs do
      rendered_input = Enum.find(rendered_surface["inputs"], &(&1["name"] == name))

      refute is_nil(rendered_input), "no rendered aria input for #{name}"

      assert rendered_input["role"] == facts["role"],
             "rendered role for #{name} diverged from the delegated aria fact"

      attribute = Ash.Resource.Info.attribute(VolunteerMilestone, name)

      assert rendered_input["required"] == not attribute.allow_nil?,
             "rendered required for #{name} diverged from Ash attribute law"
    end
  end

  defp recomputed_receipt_hash(receipt) do
    payload = %{
      "actionId" => receipt["actionId"],
      "input" => receipt["input"],
      "consequence" => receipt["consequence"],
      "dispatchState" => receipt["dispatchState"],
      "selectedTransport" => receipt["selectedTransport"],
      "timestamp" => receipt["timestamp"]
    }

    AshSurface.CanonicalJSON.sha256_hex(payload)
  end
end
