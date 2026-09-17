defmodule AshSurface.DigestParityFixtures do
  @moduledoc """
  Fixture generator for the cross-language digest parity tables
  (chicago-digest-parity-051, `test/js/digest_cross_language_v3.test.mjs`).

  One document, five tables — one per digest-bearing contract that exists on
  this base:

    * `contract` — `AshSurface.from_manifest/2` surface digest (the frozen
      canonical-term -> ETF -> SHA-256 canon) over the emitted contract map;
    * `event` — `AshSurface.Event.create/4` state digest + `ev_` content id
      (`sha256("subject:sequence:type:" <> canonical-json(payload))`);
    * `observation` — `AshSurface.Observation.create/3` state digest + `obs_`
      content id (`sha256("subject:" <> canonical-json(facts))`);
    * `ir` — `AshSurface.IR.Codec.from_map/1` digest over the five-section
      staging IR (the same frozen ETF canon over a JSON-isomorphic preimage);
    * `receipt` — `AshSurface.CanonicalJSON.sha256_hex/1` over the runtime
      receipt payload — the Elixir twin of the runtime's `canonicalStringify`
      minting law (`test/js/consumer_e2e_runner.mjs`).

  Every digest is produced by the REAL production module in this process —
  no shadow reimplementation feeds the goldens. Order-twin rows (same content,
  different map insertion order) pin map-order invariance per contract.

  The rendered document is byte-stable: `AshSurface.CanonicalJSON.encode/1`
  (sorted keys) renders the file, so regeneration is deterministic. The
  on-disk bytes are pinned by `AshSurface.DigestParityFixtureTest` — any
  upstream digest-law drift breaks that guard, and the JS parity suite reads
  exactly those bytes.

  Sibling-note (merge-time extension): the episode digest law (ticket 036)
  and the full receipt-digest law (ticket 038) land on sibling branches; this
  document carries the receipt-hash parity that already exists here, and
  gains an `episode` table when 036 integrates.
  """

  alias Ash.Info.Manifest
  alias Ash.Info.Manifest.{Action, Entrypoint}
  alias AshSurface.CanonicalJSON
  alias AshSurface.Event
  alias AshSurface.IR.Codec
  alias AshSurface.Observation

  @fixed_time ~U[2026-09-17T06:30:00Z]
  @output_path "test/js/fixtures/digest_cross_language_fixtures.json"

  @doc "On-disk fixture path (relative to the project root)."
  def output_path, do: @output_path

  @doc """
  Builds the fixture document by driving the real production digest modules.
  """
  def document do
    %{
      "generator" =>
        "AshSurface.DigestParityFixtures — real pipeline: AshSurface.from_manifest/2, " <>
          "AshSurface.Event.create/4, AshSurface.Observation.create/3, " <>
          "AshSurface.IR.Codec.from_map/1, AshSurface.CanonicalJSON.sha256_hex/1",
      "lawVersion" => AshSurface.schema_version(),
      "tables" => %{
        "contract" => contract_rows(),
        "event" => event_rows(),
        "observation" => observation_rows(),
        "ir" => ir_rows(),
        "receipt" => receipt_rows()
      }
    }
  end

  @doc """
  The byte-stable canonical encoding of the fixture document (one trailing
  newline). Both the generator and the Elixir guard test use this exact
  rendering, so the committed file is reproducible from the real pipeline.
  """
  def encode, do: CanonicalJSON.encode(document()) <> "\n"

  @doc "Writes the fixture file and returns its absolute path."
  def write! do
    path = Path.expand(@output_path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, encode())
    path
  end

  # -- contract table (T1) ------------------------------------------------------

  defp contract_rows do
    kiosk_profile = %{
      "consumer" => "kiosk",
      "nλ" => 1,
      "glyphs" => ["α", "ω", "✓"],
      "ratio" => 0.125,
      "ok" => true,
      "gap" => nil,
      "floor" => -2_147_483_649
    }

    c1 =
      surface!(
        %Manifest{
          entrypoints: [entrypoint(AshSurface.Fixtures.VolunteerMilestone, :read, :read)]
        },
        profile: kiosk_profile
      )

    c2 = delegated_surface()

    [
      %{
        "name" => "C1 read-only contract, UTF-8 profile keys + numeric boundaries",
        "elixirDigest" => c1.digest,
        "contract" => c1.contract
      },
      %{
        "name" =>
          "C2 read+record contract, per-action delegated profile (refusals, safe-int ceiling)",
        "elixirDigest" => c2.digest,
        "contract" => c2.contract
      }
    ]
  end

  # The delegated-profile surface is shared between the contract table (C2)
  # and the IR table (IR1 stages its real action entries), so both tables
  # digest the same real pipeline output.
  defp delegated_surface do
    profile = %{
      "audience" => "operators",
      "actions" => %{
        "AshSurface.Fixtures.VolunteerMilestone#record" => %{
          "consumer" => "kiosk",
          "possibleRefusals" => ["REFUSED_NO_AUTHORITY", "REFUSED_GENERATOR_OWNED"],
          "quota" => 9_007_199_254_740_991
        }
      }
    }

    surface!(
      %Manifest{
        entrypoints: [
          entrypoint(AshSurface.Fixtures.VolunteerMilestone, :read, :read),
          entrypoint(AshSurface.Fixtures.VolunteerMilestone, :record, :create)
        ]
      },
      profile: profile
    )
  end

  # -- event table (T2) ---------------------------------------------------------

  defp event_rows do
    e1_payload = %{
      "string" => "héllo ✓",
      "float" => 1.5,
      "negative" => -987_654,
      "nested" => %{"b" => 2, "a" => 1},
      "list" => [1, "two", nil, true],
      "empty_map" => %{},
      "empty_list" => []
    }

    # Same content, reversed insertion order: canonical sort must erase it.
    e2_payload = %{
      "empty_list" => [],
      "list" => [1, "two", nil, true],
      "empty_map" => %{},
      "nested" => %{"a" => 1, "b" => 2},
      "negative" => -987_654,
      "float" => 1.5,
      "string" => "héllo ✓"
    }

    e1 =
      Event.create("mx://zoela/milestone#789", 0, "recorded",
        payload: e1_payload,
        occurred_at: @fixed_time
      )

    e2 =
      Event.create("mx://zoela/milestone#789", 0, "recorded",
        payload: e2_payload,
        occurred_at: @fixed_time
      )

    e3 = Event.create("mx://zoela/mètre#✓", 7, "observed", payload: %{}, occurred_at: @fixed_time)

    [
      event_row("E1 rich payload (unicode, float, negative, nested, empty containers)", e1),
      event_row("E2 order-twin of E1 (same content, different insertion order)", e2),
      event_row("E3 unicode subject, minimal empty payload", e3)
    ]
  end

  defp event_row(name, %Event{} = ev) do
    %{
      "name" => name,
      "subjectRef" => ev.subject_ref,
      "sequence" => ev.sequence,
      "eventType" => ev.event_type,
      "payload" => ev.payload,
      "elixirStateDigest" => ev.state_digest,
      "elixirEventId" => ev.event_id
    }
  end

  # -- observation table (T3) ---------------------------------------------------

  defp observation_rows do
    o1_facts = %{
      "status" => "completed",
      "score" => 0.125,
      "witnesses" => ["para", "vo"],
      "meta" => %{"retries" => 2, "ok" => true, "note" => nil},
      "tags" => []
    }

    # Same content, reversed insertion order: canonical sort must erase it.
    o2_facts = %{
      "tags" => [],
      "meta" => %{"note" => nil, "ok" => true, "retries" => 2},
      "witnesses" => ["para", "vo"],
      "score" => 0.125,
      "status" => "completed"
    }

    o1 = Observation.create("ash://volunteer/milestone#42", o1_facts, observed_at: @fixed_time)
    o2 = Observation.create("ash://volunteer/milestone#42", o2_facts, observed_at: @fixed_time)
    o3 = Observation.create("ash://volontaire#ʒ", %{}, observed_at: @fixed_time)

    [
      observation_row("O1 rich facts (float, lists, nested, empty containers)", o1),
      observation_row("O2 order-twin of O1 (same content, different insertion order)", o2),
      observation_row("O3 unicode subject, empty facts", o3)
    ]
  end

  defp observation_row(name, %Observation{} = obs) do
    %{
      "name" => name,
      "exactSubject" => obs.exact_subject,
      "facts" => obs.facts,
      "standing" => to_string(obs.standing),
      "elixirStateDigest" => obs.state_digest,
      "elixirObservationId" => obs.observation_id
    }
  end

  # -- IR table (T4) ------------------------------------------------------------

  defp ir_rows do
    c2 = delegated_surface()

    staging_actions =
      c2.contract
      |> Map.fetch!("surface")
      |> Map.fetch!("actions")
      |> Map.new(fn %{"id" => id} = action -> {id, action} end)

    ir_staging = %{
      "actions" => staging_actions,
      "identity" => %{
        "generatorIdentity" => "ash_surface:v26.9.17",
        "manifestDigest" => Map.fetch!(c2.contract, "manifestDigest"),
        "surfaceSchemaVersion" => "26.9.17"
      },
      "profile" => %{"audience" => "operators"},
      "resources" => nil,
      "transports" => %{
        "declared" => ["http", "phoenix_channel"],
        "selection" => "before_dispatch"
      }
    }

    ir_sparse = %{
      "actions" => nil,
      "identity" => nil,
      "profile" => nil,
      "resources" => nil,
      "transports" => nil
    }

    ir_deep = %{
      "actions" => %{
        "Σ🜂#capability" => %{
          "bools" => [true, false, nil],
          "bounds" => %{
            "safeCeiling" => 9_007_199_254_740_991,
            "int32min1" => -2_147_483_649,
            "negBig" => -9_876_543_210
          },
          "floats" => [0.125, -0.5, 1.5],
          "empty" => %{"l" => [], "m" => %{}},
          "glyph" => "Σ🜂✓",
          "order" => ["b", "a"]
        }
      },
      "identity" => nil,
      "profile" => %{"order" => ["z", "a", "m"]},
      "resources" => nil,
      "transports" => nil
    }

    [
      ir_row("IR1 staging IR from the real C2 contract action entries", ir_staging),
      ir_row("IR2 sparse IR (all five sections nil)", ir_sparse),
      ir_row("IR3 deep IR (ETF boundary values, unicode, list-order semantics)", ir_deep)
    ]
  end

  defp ir_row(name, sections) do
    {:ok, ir} = Codec.from_map(sections)

    %{
      "name" => name,
      "sections" => Codec.to_map(ir),
      "elixirDigest" => ir.digest
    }
  end

  # -- receipt table (T5) -------------------------------------------------------

  defp receipt_rows do
    r1_payload = %{
      "actionId" => "AshSurface.Fixtures.VolunteerMilestone#record",
      "input" => %{
        "member_id" => "m-1",
        "milestone_id" => "ms-9",
        "cost_physical" => 5,
        "reward_spiritual" => 10
      },
      "consequence" => %{"status" => "completed", "score" => 1.5},
      "dispatchState" => "applied",
      "selectedTransport" => "http",
      "timestamp" => "2026-09-17T06:30:00.000Z"
    }

    # Same content, reversed insertion order: canonical sort must erase it.
    r2_payload = %{
      "timestamp" => "2026-09-17T06:30:00.000Z",
      "selectedTransport" => "http",
      "dispatchState" => "applied",
      "consequence" => %{"score" => 1.5, "status" => "completed"},
      "input" => %{
        "reward_spiritual" => 10,
        "cost_physical" => 5,
        "milestone_id" => "ms-9",
        "member_id" => "m-1"
      },
      "actionId" => "AshSurface.Fixtures.VolunteerMilestone#record"
    }

    r3_payload = %{
      "actionId" => "Σ🜂#witness",
      "input" => %{"glyph" => "✓"},
      "consequence" => %{"seen" => true},
      "dispatchState" => "applied",
      "selectedTransport" => "phoenix_channel",
      "timestamp" => "2026-09-17T06:30:00.000Z"
    }

    [
      receipt_row("R1 runtime-shaped receipt payload", r1_payload),
      receipt_row("R2 order-twin of R1 (same content, different insertion order)", r2_payload),
      receipt_row("R3 unicode action id, channel transport", r3_payload)
    ]
  end

  defp receipt_row(name, payload) do
    %{
      "name" => name,
      "payload" => payload,
      "elixirReceiptHash" => CanonicalJSON.sha256_hex(payload)
    }
  end

  # -- shared builders ------------------------------------------------------------

  defp surface!(manifest, opts) do
    {:ok, surface} = AshSurface.from_manifest(manifest, opts)
    surface
  end

  defp entrypoint(resource, name, type, action_opts \\ []) do
    %Entrypoint{
      resource: resource,
      action: struct!(Action, Keyword.merge([name: name, type: type, custom: %{}], action_opts))
    }
  end
end
