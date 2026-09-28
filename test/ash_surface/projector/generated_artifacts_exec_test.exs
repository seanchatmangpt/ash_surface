defmodule AshSurface.Projector.GeneratedArtifactsExecTest do
  @moduledoc """
  Execution receipts for manufactured artifacts.

  Law pinned (AGENTS.md): generated code is only ALIVE with an exact consumer
  execution receipt. Text-fragment assertions pin wording, not behaviour, so
  each manufactured artifact is imported and driven under Node instead:

    * `Expo` schemas / actions / events / receipts / client / tanstack
      (`test/js/generated_expo_*_runner.mjs`)
    * `VoiceKiosk` voice JSON (`generated_voice_kiosk_runner.mjs`)
    * `Projectors.JS` JSDoc + Zod artifact (`generated_js_projector_runner.mjs`)

  Every artifact comes from the real projector; the real runtime is installed
  behind the `ash_surface` import (node_modules shim). Transport is driven
  through the defined seam - a stub adapter with `invoke/1` - never a mock
  library. The final describe is the mutation sanity check: a hand-mutated
  COPY of a manufactured artifact (under `_build/test`, never `lib/`) must make
  the same runner fail, proving the receipts can actually discriminate.
  """

  use ExUnit.Case, async: false

  alias Ash.Info.Manifest
  alias AshSurface.{CanonicalJSON, Event, IR}
  alias AshSurface.Fixtures.VolunteerMilestone
  alias AshSurface.Projector.{Expo, VoiceKiosk}
  alias AshSurface.Projectors.JS

  @prefix "zoela_surface"
  @tmp_dir Path.expand("../../../_build/test/generated_artifacts_exec", __DIR__)
  @record_id "AshSurface.Fixtures.VolunteerMilestone#record"
  @read_id "AshSurface.Fixtures.VolunteerMilestone#read"
  @mx_descriptor_keys ~w(id semanticId resource action authorityBoundary doAuthority receiptRequired evidenceRequired possibleRefusals)
  @uuid "123e4567-e89b-12d3-a456-426614174000"

  @valid_milestone %{
    "cost_physical" => 3,
    "id" => @uuid,
    "member_id" => "member_1",
    "milestone_id" => "ms_1",
    "reward_spiritual" => 5,
    "status" => "recorded"
  }

  setup do
    File.rm_rf!(@tmp_dir)
    File.mkdir_p!(@tmp_dir)
    install_runtime_shim!(@tmp_dir)
    :ok
  end

  describe "schemas.mjs executes" do
    test "the real fixture surface's Zod schemas accept valid input and reject invalid input" do
      %{surface: surface} = manufacture!(%{})

      output_valid = [%{"success" => true}, %{"success" => false, "error" => "REFUSED", "x" => 1}]
      output_invalid = [%{}, %{"success" => "yes"}, %{"success" => true, "receiptRef" => 5}]

      cases =
        for id <- [@read_id, @record_id] do
          %{
            "id" => id,
            "valid" => [@valid_milestone],
            "invalid" => [
              %{},
              %{@valid_milestone | "id" => "not-a-uuid"},
              %{@valid_milestone | "cost_physical" => 1.5},
              %{@valid_milestone | "member_id" => 7},
              Map.delete(@valid_milestone, "status")
            ]
          }
        end

      receipt =
        run_receipt!("generated_expo_schemas_runner.mjs", %{
          "prefix" => @prefix,
          "expectedIds" => surface.action_ids,
          "cases" => cases,
          "outputValid" => output_valid,
          "outputInvalid" => output_invalid
        })

      assert %{"receipt" => "GENERATED_EXPO_SCHEMAS_PASS", "actions" => 2, "accepted" => 2} =
               receipt
    end

    test "every manifest field kind maps to a Zod schema that accepts and rejects real values" do
      kinds = [
        {"string", ["a"], [1, nil]},
        {"integer", [3], [3.5, "3", nil]},
        {"boolean", [true], ["true", 1, nil]},
        {"uuid", [@uuid], ["nope", 7, nil]},
        {"float", [1.5, 2], ["1.5", nil]},
        {"decimal", [2, 0.25], ["2", nil]},
        {"utc_datetime", ["2026-09-17T06:30:00Z"], [5, nil]},
        {"datetime", ["2026-09-17T06:30:00Z"], [5, nil]},
        {"map", [%{"a" => 1}], [[1], "m", nil]},
        {"array", [[1, "a"]], [%{}, "a", nil]},
        # exotic kinds degrade to z.unknown(): anything passes
        {"exotic_unmapped", [5, "x", nil, [1]], []}
      ]

      {actions, resources, cases} =
        for {kind, valid, invalid} <- kinds, reduce: {[], %{}, []} do
          {acts, res, cs} ->
            id = "act_#{kind}"

            field = %{"type" => %{"kind" => kind}}

            {[%{"id" => id, "resource" => "Res_#{kind}"} | acts],
             Map.put(res, kind, %{"name" => "Res_#{kind}", "fields" => %{"f" => field}}),
             [
               %{
                 "id" => id,
                 "safeName" => id,
                 "valid" => Enum.map(valid, &%{"f" => &1}),
                 "invalid" => Enum.map(invalid, &%{"f" => &1}) ++ invalid_missing(kind)
               }
               | cs
             ]}
        end

      run_hand_built!(actions, resources, cases)
    end

    test "allow_nil?, untyped, unresolved and field-less resources degrade as documented" do
      actions = [
        %{"id" => "nullable", "resource" => "R1"},
        %{"id" => "untyped", "resource" => "R2"},
        %{"id" => "unresolved", "resource" => "Missing"},
        %{"id" => "no_resource"},
        %{"id" => "bad_fields", "resource" => "R3"}
      ]

      resources = %{
        "r1" => %{
          "name" => "R1",
          "fields" => %{"n" => %{"type" => %{"kind" => "integer"}, "allow_nil?" => true}}
        },
        "r2" => %{"name" => "R2", "fields" => %{"u" => %{}}},
        "r3" => %{"name" => "R3", "fields" => []}
      }

      cases = [
        %{
          "id" => "nullable",
          "safeName" => "nullable",
          "valid" => [%{}, %{"n" => nil}, %{"n" => 4}],
          "invalid" => [%{"n" => "x"}, %{"n" => 1.5}]
        },
        %{
          "id" => "untyped",
          "safeName" => "untyped",
          "valid" => [%{}, %{"u" => 1}, %{"u" => "anything"}],
          "invalid" => []
        },
        # degenerate resolutions: an empty passthrough object accepts any object
        %{
          "id" => "unresolved",
          "safeName" => "unresolved",
          "valid" => [%{}, %{"k" => 1}],
          "invalid" => []
        },
        %{"id" => "no_resource", "safeName" => "no_resource", "valid" => [%{}], "invalid" => []},
        %{
          "id" => "bad_fields",
          "safeName" => "bad_fields",
          "valid" => [%{"k" => 1}],
          "invalid" => []
        }
      ]

      run_hand_built!(actions, resources, cases)
    end

    test "resources resolve by name or module in both map and list forms" do
      shapes = [
        %{"res" => %{"name" => "Res", "fields" => %{"n" => %{"type" => %{"kind" => "string"}}}}},
        %{
          "res" => %{"module" => "Res", "fields" => %{"n" => %{"type" => %{"kind" => "string"}}}}
        },
        [%{"name" => "Res", "fields" => %{"n" => %{"type" => %{"kind" => "string"}}}}],
        [%{"module" => "Res", "fields" => %{"n" => %{"type" => %{"kind" => "string"}}}}]
      ]

      for resources <- shapes do
        run_hand_built!(
          [%{"id" => "act", "resource" => "Res"}],
          resources,
          [
            %{
              "id" => "act",
              "safeName" => "act",
              "valid" => [%{"n" => "s"}],
              "invalid" => [%{"n" => 1}, %{}]
            }
          ]
        )
      end
    end

    test "action ids with non-identifier characters still bind executable, importable schemas" do
      id = "Volunteer.Milestone#record-milestone"
      safe = "Volunteer_Milestone_record_milestone"

      resources = %{
        "r" => %{"name" => "R", "fields" => %{"n" => %{"type" => %{"kind" => "integer"}}}}
      }

      run_hand_built!(
        [%{"id" => id, "resource" => "R"}],
        resources,
        [
          %{
            "id" => id,
            "safeName" => safe,
            "valid" => [%{"n" => 1}],
            "invalid" => [%{"n" => "1"}]
          }
        ]
      )
    end

    test "a surface with no admitted actions executes to an empty SCHEMAS map" do
      run_hand_built!([], %{}, [])
    end
  end

  describe "actions.mjs executes" do
    test "the registry, getAction and delegated lookups behave as the surface delegates" do
      profile = %{
        "actions" => %{
          @record_id => %{
            "authorityBoundary" => "SELECT",
            "semanticId" => "zoe:SelectOption",
            "doAuthority" => false,
            "receiptRequired" => true
          },
          @read_id => %{"authorityBoundary" => "DO", "doAuthority" => true}
        }
      }

      %{surface: surface} = manufacture!(profile)

      # The delegated facts the runner must observe come from the profile, not
      # from the contract echo alone.
      expected =
        surface.contract["surface"]["actions"]
        |> Enum.sort_by(& &1["id"])
        |> Enum.map(
          &Map.take(
            &1,
            ~w(id resource action semanticId authorityBoundary doAuthority receiptRequired)
          )
        )

      assert [
               %{"authorityBoundary" => "DO", "doAuthority" => true},
               %{"authorityBoundary" => "SELECT"}
             ] =
               Enum.map(expected, &Map.take(&1, ~w(authorityBoundary doAuthority)))

      receipt =
        run_receipt!("generated_expo_actions_runner.mjs", %{
          "prefix" => @prefix,
          "expected" => expected,
          "descriptorKeys" => @mx_descriptor_keys
        })

      assert receipt == %{"receipt" => "GENERATED_EXPO_ACTIONS_PASS", "actions" => 2}
    end

    test "with nothing delegated every boundary is null, never derived from the action type" do
      %{surface: surface} = manufacture!(%{})

      expected =
        surface.contract["surface"]["actions"]
        |> Enum.sort_by(& &1["id"])
        |> Enum.map(
          &Map.take(
            &1,
            ~w(id resource action semanticId authorityBoundary doAuthority receiptRequired)
          )
        )

      assert Enum.all?(expected, &(&1["authorityBoundary"] == nil and &1["doAuthority"] == nil))

      assert %{"receipt" => "GENERATED_EXPO_ACTIONS_PASS"} =
               run_receipt!("generated_expo_actions_runner.mjs", %{
                 "prefix" => @prefix,
                 "expected" => expected,
                 "descriptorKeys" => @mx_descriptor_keys
               })
    end
  end

  describe "events.mjs executes" do
    test "parseEvent admits the real Event.to_map/1 wire form and refuses everything else" do
      manufacture_empty!()

      good =
        "zoe:KingdomNeed#need_42"
        |> Event.create(7, "need_selected",
          payload: %{"selected_candidate" => "person_01"},
          receipt_ref: "rcpt_b3_8f910a2",
          occurred_at: ~U[2026-09-15T10:00:00Z]
        )
        |> Event.to_map()

      assert %{"receipt" => "GENERATED_EXPO_EVENTS_PASS", "fields" => 10} =
               run_receipt!("generated_expo_events_runner.mjs", %{
                 "prefix" => @prefix,
                 "goodEvent" => good
               })
    end
  end

  describe "receipts.mjs executes" do
    test "verification-only: a good hash verifies, a tampered receipt is refused, nothing is minted" do
      manufacture_empty!()

      content = %{
        "actionId" => "Zoela.KingdomNeed#select_option",
        "actorRef" => "member_zoela_01",
        "authorityBoundary" => "SELECT",
        "correlationId" => "cmd_rh_038",
        "domainReceiptRef" => "rcpt_srv_9",
        "episodeId" => "ep_2026_09_17_001",
        "evidenceRefs" => ["ev_1", "ev_2"],
        "exactSubject" => "Zoela.KingdomNeed:need_42",
        "inputDigest" => "in_d3",
        "outcome" => "COMPLETED",
        "policyRef" => "pol/v26.9.17",
        "postStateDigest" => "sd_post_b2",
        "preStateDigest" => "sd_pre_a1",
        "replayKey" => "rk_001",
        "semanticActionId" => "zoe:SelectOption",
        "standingAfter" => "ALIVE",
        "standingBefore" => "ALIVE",
        "taskNetworkRef" => "tn_7",
        "timestamp" => "2026-09-17T06:30:00Z",
        "transportReceipt" => %{"dispatchState" => "completed", "selected" => "http"}
      }

      # Hash minted by the Elixir owner of the canonical-bytes law, outside the JS module.
      receipt = Map.put(content, "receiptHash", CanonicalJSON.sha256_hex(content))

      assert %{
               "receipt" => "GENERATED_EXPO_RECEIPTS_PASS",
               "verified" => true,
               "tamperRefused" => true
             } =
               run_receipt!("generated_expo_receipts_runner.mjs", %{
                 "prefix" => @prefix,
                 "receipt" => receipt
               })
    end
  end

  describe "client + tanstack adapter execute" do
    test "the manufactured factory wires the shipped runtime and TanStack mutations invoke with receipt" do
      %{surface: surface} = manufacture!(%{})

      assert %{"receipt" => "GENERATED_EXPO_TANSTACK_PASS", "wiredToInvokeWithReceipt" => true} =
               run_receipt!("generated_expo_tanstack_runner.mjs", %{
                 "prefix" => @prefix,
                 "factory" => "createZoelaClient",
                 "contract" => surface.contract,
                 "actionId" => @record_id,
                 "resource" => "AshSurface.Fixtures.VolunteerMilestone",
                 "action" => "record",
                 "validInput" => @valid_milestone,
                 "invalidInput" => %{@valid_milestone | "id" => "not-a-uuid"}
               })
    end
  end

  describe "VoiceKiosk voice JSON executes" do
    test "the artifact parses under a strict Zod shape and its gating holds on the emitted data" do
      surface = voice_surface()
      dir = Path.join(@tmp_dir, "voice")

      assert {:ok, artifacts, %{intent_count: 3}} =
               AshSurface.project(surface, VoiceKiosk, prefix: "kiosk", target_dir: dir)

      assert Map.keys(artifacts) == ["kiosk.voice.json"]

      spec_path =
        write_json!("voice_spec.json", %{
          "artifactPath" => Path.join(dir, "kiosk.voice.json"),
          "surfaceDigest" => surface.digest,
          "actionIds" => surface.action_ids
        })

      assert %{"receipt" => "GENERATED_VOICE_KIOSK_PASS", "intents" => 3} =
               run_node!(["test/js/generated_voice_kiosk_runner.mjs", spec_path])
    end
  end

  describe "Projectors.JS artifact executes" do
    test "namespaces, Zod schemas and the DO dispatch-intent law hold when imported" do
      dir = Path.join(@tmp_dir, "js")
      install_runtime_shim!(dir)
      irs = js_irs()
      assert {:ok, %{"ash_surface_client.mjs" => _}, _meta} = JS.project_ir(irs, target_dir: dir)

      fixture =
        Path.join(dir, "fixture.json")
        |> tap(
          &File.write!(
            &1,
            Jason.encode!(%{
              prefix: "ash_surface_client",
              actions: js_truths(irs)
            })
          )
        )

      assert %{"receipt" => "GENERATED_JS_PROJECTOR_PASS", "actions" => 3} =
               run_node!(["test/js/generated_js_projector_runner.mjs", dir, fixture])
    end
  end

  describe "mutation sanity: a broken artifact copy fails the same receipt" do
    test "schemas: uuid weakened to string is caught" do
      assert_mutation_caught!(
        "zoela_surface.schemas.mjs",
        "z.string().uuid()",
        "z.string()",
        fn dir -> run_schemas_real!(dir) end
      )
    end

    test "events: OBSERVE-only authority widened to any string is caught" do
      assert_mutation_caught!(
        "zoela_surface.events.mjs",
        ~s|z.literal("OBSERVE").default("OBSERVE")|,
        ~s|z.string().default("OBSERVE")|,
        fn dir -> run_events!(dir) end
      )
    end

    test "receipts: canonical key sorting removed is caught" do
      assert_mutation_caught!(
        "zoela_surface.receipts.mjs",
        "Object.keys(obj).sort()",
        "Object.keys(obj)",
        fn dir -> run_receipts!(dir) end
      )
    end

    test "actions: unknown-id lookup that fabricates an admission is caught" do
      assert_mutation_caught!(
        "zoela_surface.actions.mjs",
        "return ACTIONS.find((a) => a.id === id) ?? null;",
        "return ACTIONS.find((a) => a.id === id) ?? ACTIONS[0];",
        fn dir -> run_actions!(dir) end
      )
    end

    test "tanstack: mutation wired to invoke instead of invokeWithReceipt is caught" do
      assert_mutation_caught!(
        "zoela_surface.tanstack.mjs",
        "action.invokeWithReceipt(input)",
        "action.invoke(input)",
        fn dir -> run_tanstack!(dir) end
      )
    end
  end

  # -- mutation harness -------------------------------------------------------

  defp assert_mutation_caught!(file, from, to, runner) do
    %{surface: _} = manufacture!(%{})
    mutant = Path.join(@tmp_dir, "mutant")
    File.rm_rf!(mutant)
    File.mkdir_p!(mutant)
    install_runtime_shim!(mutant)

    for f <- File.ls!(@tmp_dir), String.starts_with?(f, "#{@prefix}.") do
      File.cp!(Path.join(@tmp_dir, f), Path.join(mutant, f))
    end

    # Control: the pristine copy passes the very same runner.
    assert {_, 0} = runner.(mutant)

    path = Path.join(mutant, file)
    source = File.read!(path)
    assert String.contains?(source, from), "mutation anchor #{inspect(from)} not found in #{file}"
    File.write!(path, String.replace(source, from, to))

    assert {output, status} = runner.(mutant)
    refute status == 0, "mutated #{file} passed its execution receipt: #{output}"
    assert output =~ "AssertionError" or output =~ "Error"
  end

  defp run_schemas_real!(dir) do
    {:ok, surface} = fixture_surface(%{})

    node_cmd([
      "test/js/generated_expo_schemas_runner.mjs",
      dir,
      write_json!("mut_schemas.json", %{
        "prefix" => @prefix,
        "expectedIds" => surface.action_ids,
        "cases" => [
          %{
            "id" => @record_id,
            "valid" => [@valid_milestone],
            "invalid" => [%{@valid_milestone | "id" => "not-a-uuid"}]
          }
        ]
      })
    ])
  end

  defp run_events!(dir) do
    good = Event.create("s", 1, "t", occurred_at: ~U[2026-09-15T10:00:00Z]) |> Event.to_map()

    node_cmd([
      "test/js/generated_expo_events_runner.mjs",
      dir,
      write_json!("mut_events.json", %{"prefix" => @prefix, "goodEvent" => good})
    ])
  end

  defp run_receipts!(dir) do
    content = %{
      "episodeId" => "e",
      "correlationId" => "c",
      "exactSubject" => "s",
      "actionId" => "a",
      "semanticActionId" => "sa",
      "authorityBoundary" => "DO",
      "inputDigest" => "d",
      "transportReceipt" => %{"z" => 1, "a" => 2},
      "evidenceRefs" => ["x"],
      "outcome" => "COMPLETED",
      "replayKey" => "r",
      "timestamp" => "t"
    }

    receipt = Map.put(content, "receiptHash", CanonicalJSON.sha256_hex(content))

    node_cmd([
      "test/js/generated_expo_receipts_runner.mjs",
      dir,
      write_json!("mut_receipts.json", %{"prefix" => @prefix, "receipt" => receipt})
    ])
  end

  defp run_actions!(dir) do
    {:ok, surface} = fixture_surface(%{})

    expected =
      surface.contract["surface"]["actions"]
      |> Enum.sort_by(& &1["id"])
      |> Enum.map(
        &Map.take(
          &1,
          ~w(id resource action semanticId authorityBoundary doAuthority receiptRequired)
        )
      )

    node_cmd([
      "test/js/generated_expo_actions_runner.mjs",
      dir,
      write_json!("mut_actions.json", %{
        "prefix" => @prefix,
        "expected" => expected,
        "descriptorKeys" => @mx_descriptor_keys
      })
    ])
  end

  defp run_tanstack!(dir) do
    {:ok, surface} = fixture_surface(%{})

    node_cmd([
      "test/js/generated_expo_tanstack_runner.mjs",
      dir,
      write_json!("mut_tanstack.json", %{
        "prefix" => @prefix,
        "factory" => "createZoelaClient",
        "contract" => surface.contract,
        "actionId" => @record_id,
        "resource" => "AshSurface.Fixtures.VolunteerMilestone",
        "action" => "record",
        "validInput" => @valid_milestone,
        "invalidInput" => %{@valid_milestone | "id" => "not-a-uuid"}
      })
    ])
  end

  # -- manufacture + run helpers ---------------------------------------------

  defp fixture_surface(profile) do
    with {:ok, manifest} <-
           Manifest.generate(
             otp_app: :ash_surface,
             action_entrypoints: [{VolunteerMilestone, :record}, {VolunteerMilestone, :read}]
           ) do
      AshSurface.from_manifest(manifest, profile: profile)
    end
  end

  defp manufacture!(profile) do
    assert {:ok, surface} = fixture_surface(profile)

    assert {:ok, artifacts, _meta} =
             AshSurface.project(surface, Expo, prefix: @prefix, target_dir: @tmp_dir)

    %{surface: surface, artifacts: artifacts}
  end

  defp manufacture_empty! do
    surface =
      AshSurface.TestSupport.VerifiedSurface.seal(%AshSurface.Surface{
        manifest: %{},
        contract: %{"surface" => %{"actions" => []}},
        digest: "test_digest",
        action_ids: []
      })

    assert {:ok, _artifacts, _meta} =
             AshSurface.project(surface, Expo, prefix: @prefix, target_dir: @tmp_dir)
  end

  defp run_hand_built!(actions, resources, cases) do
    surface =
      AshSurface.TestSupport.VerifiedSurface.seal(%AshSurface.Surface{
        manifest: nil,
        contract: %{
          "surface" => %{"actions" => actions},
          "manifest" => %{"resources" => resources}
        },
        digest: "digest-test",
        action_ids: Enum.map(actions, & &1["id"])
      })

    dir = Path.join(@tmp_dir, "hand_#{System.unique_integer([:positive])}")
    install_runtime_shim!(dir)

    assert {:ok, _artifacts, _meta} =
             AshSurface.project(surface, Expo, prefix: @prefix, target_dir: dir)

    spec_path =
      write_json!("hand_spec_#{System.unique_integer([:positive])}.json", %{
        "prefix" => @prefix,
        "expectedIds" => surface.action_ids,
        "cases" => cases,
        "outputValid" => [%{"success" => true}],
        "outputInvalid" => [%{"success" => 1}]
      })

    assert %{"receipt" => "GENERATED_EXPO_SCHEMAS_PASS"} =
             run_node!(["test/js/generated_expo_schemas_runner.mjs", dir, spec_path])
  end

  # A required kind rejects a missing field; z.unknown() (exotic) does not.
  defp invalid_missing("exotic_unmapped"), do: []
  defp invalid_missing(_kind), do: [%{}]

  defp run_receipt!(runner, spec) do
    spec_path = write_json!("spec_#{System.unique_integer([:positive])}.json", spec)
    run_node!(["test/js/#{runner}", @tmp_dir, spec_path])
  end

  defp write_json!(name, term) do
    path = Path.join(@tmp_dir, name)
    File.write!(path, Jason.encode!(term))
    path
  end

  defp node_cmd(args) do
    System.cmd("node", args, stderr_to_stdout: true, cd: Path.expand("../../..", __DIR__))
  end

  defp run_node!(args) do
    {output, status} = node_cmd(args)
    assert status == 0, "execution receipt failed (#{Enum.join(args, " ")}):\n#{output}"

    assert {:ok, receipt} =
             output |> String.trim() |> String.split("\n") |> List.last() |> Jason.decode()

    receipt
  end

  defp install_runtime_shim!(dir) do
    package_dir = Path.join([dir, "node_modules", "ash_surface"])
    File.mkdir_p!(package_dir)

    File.write!(
      Path.join(package_dir, "package.json"),
      Jason.encode!(%{"name" => "ash_surface", "type" => "module", "exports" => "./index.mjs"})
    )

    File.cp!(
      Path.expand("priv/static/ash_surface_runtime.mjs"),
      Path.join(package_dir, "index.mjs")
    )

    zod_source = Path.expand("node_modules/zod")
    assert File.dir?(zod_source), "npm install must provide node_modules/zod before mix test"

    case File.ln_s(zod_source, Path.join([dir, "node_modules", "zod"])) do
      :ok -> :ok
      {:error, :eexist} -> :ok
      {:error, reason} -> flunk("failed to link Zod runtime: #{inspect(reason)}")
    end
  end

  # -- voice + JS fixtures ----------------------------------------------------

  defp voice_surface do
    actions = [
      %{
        "id" => "Volunteer.Milestone#read",
        "resource" => "Volunteer.Milestone",
        "action" => "read",
        "authorityBoundary" => "OBSERVE",
        "doAuthority" => false,
        "profile" => %{"presentation" => %{"label" => "Hear today's milestones"}}
      },
      %{
        "id" => "Volunteer.Milestone#record",
        "resource" => "Volunteer.Milestone",
        "action" => "record",
        "authorityBoundary" => "DO",
        "doAuthority" => true,
        "profile" => %{}
      },
      %{
        "id" => "Volunteer.Milestone#pick",
        "resource" => "Volunteer.Milestone",
        "action" => "pick",
        "authorityBoundary" => "SELECT",
        "doAuthority" => false,
        "profile" => %{"capabilities" => ["authority_required"]}
      }
    ]

    resources = %{
      "res" => %{
        "name" => "Volunteer.Milestone",
        "fields" => %{
          "member_id" => %{"type" => %{"kind" => "string"}, "allow_nil?" => false},
          "cost_physical" => %{"type" => %{"kind" => "integer"}, "allow_nil?" => true}
        }
      }
    }

    AshSurface.TestSupport.VerifiedSurface.seal(%AshSurface.Surface{
      manifest: nil,
      contract: %{
        "surface" => %{"actions" => actions},
        "manifest" => %{"resources" => resources}
      },
      digest: "digest-voice",
      action_ids: Enum.map(actions, & &1["id"])
    })
  end

  @create_zod "z.object({\n  title: z.string().min(1),\n  due_on: z.string().optional()\n})"
  @list_zod "z.object({\n  status: z.enum([\"open\", \"done\"]).optional()\n})"

  defp js_irs do
    [
      IR.new(
        ash: %IR.Ash{
          resource: "Todo",
          action: :create,
          action_type: :create,
          policies: [%{"authorityBoundary" => "DO"}]
        },
        capability: %IR.Capability{capability_id: "todo.write", receipt_required: true},
        schema: %IR.Schema{zod: @create_zod}
      ),
      IR.new(
        ash: %IR.Ash{
          resource: "Todo",
          action: :list,
          action_type: :read,
          policies: [%{"authorityBoundary" => "OBSERVE"}]
        },
        schema: %IR.Schema{zod: @list_zod}
      ),
      IR.new(
        ash: %IR.Ash{resource: "Member", action: :deactivate, action_type: :destroy, policies: []}
      )
    ]
  end

  defp js_truths(irs) do
    for entry <- AshSurface.Projector.IREntry.entries(irs) do
      {valid, invalid} =
        case entry.id do
          "Todo.create" -> {%{"title" => "ship it", "due_on" => "2026-09-16"}, %{"title" => ""}}
          "Todo.list" -> {%{}, %{"status" => "bogus"}}
          _ -> {nil, nil}
        end

      %{
        id: entry.id,
        resource: entry.resource,
        action: entry.action,
        actionType: entry.action_type,
        authorityBoundary: entry.authority_boundary,
        receiptRequired: entry.receipt_required,
        descriptorKind:
          if(AshSurface.Projector.IREntry.do_boundary?(entry),
            do: "DISPATCH_INTENT",
            else: "DESCRIPTOR"
          ),
        zod: entry.zod,
        validInput: valid,
        invalidInput: invalid
      }
    end
  end
end
