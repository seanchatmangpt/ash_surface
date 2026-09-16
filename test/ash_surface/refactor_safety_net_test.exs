defmodule AshSurface.RefactorSafetyNetTest do
  @moduledoc """
  Refactor safety net — the integration canary (ticket refactor-safety-net-003).

  The chicago zero-config test wave (t01-t40) landed 40 law suites through a
  40-branch merge. A merge that silently drops a file compiles green and passes
  every surviving suite — the loss is invisible until someone reaches for the
  law that is no longer there. This canary makes the drop loud: every
  load-bearing chicago-wave suite is pinned here by short name and canonical
  path, and any missing file breaks the build immediately.

  Law under test: each load-bearing suite EXISTS at its canonical path.

  gapfix-do-tripwire-006 extended the canon to the 33 post-merge law suites
  that landed after this canary did (the v26.9.16 v-wave and its deepening
  branches) — a merge could previously drop any of them silently. The
  contract is identical for every pin.

  ## The canon (short name -> canonical path -> law)

    * `transport_select`    -> transport_select_test.exs    -> transport law: selector
    * `transport_fallback`  -> transport_fallback_test.exs  -> transport law: fallback ladder
    * `transport_outcome`   -> transport_outcome_test.exs   -> transport law: outcome states
    * `transport_falsifiers`-> transport_falsifiers_test.exs-> transport law: falsifiers
    * `digest`              -> digest_test.exs               -> SHA-256 cross-language digest law
    * `golden_stability`    -> action_id_test.exs            -> frozen golden id stability law
    * `validator`           -> resource/validator_test.exs   -> resource validator law
    * `validator_adversarial`-> resource/validator_adversarial_test.exs -> adversarial validator falsifiers

  ## Post-merge law suites (v26.9.16 v-wave, added by gapfix-do-tripwire-006)

    * `aria_projector`        -> aria_projector_test.exs        -> deep ARIA projector contract (deepens v19)
    * `ash_section_truth`     -> ash_section_truth_test.exs     -> golden ash section: five action types, six typed argument families
    * `capability_delegation` -> capability_delegation_test.exs -> capability section truth is ash_a2a's own derivation
    * `compiler_aria_section` -> compiler/aria_section_test.exs -> aria section: mount point, role table, required, describedby ids
    * `compiler_ash_section`  -> compiler/ash_section_test.exs  -> ash section built from a real inline resource
    * `compiler_capability_section` -> compiler/capability_section_test.exs -> capability-section builder delegates to ash_a2a
    * `compiler_presentation_section` -> compiler/presentation_section_test.exs -> presentation section from a real resource (humanize default)
    * `compiler_schema_section` -> compiler/schema_section_test.exs -> compiler schema section content contract
    * `compiler_semantic_section` -> compiler/semantic_section_test.exs -> semantic section builder, table-driven state law
    * `compiler_discovery`    -> compiler_discovery_test.exs    -> DiscoverOnce law of AshSurface.Compiler
    * `compiler`              -> compiler_test.exs              -> compiler discovery-once and section invocation order
    * `intent_candidate`      -> intent/candidate_test.exs      -> candidate shaping law (canonical-local declarations)
    * `intent_dispatch`       -> intent/dispatch_test.exs       -> delegated-DO falsifiers at the dispatch edge
    * `intent_path`           -> intent_path_test.exs           -> SurfaceIntent: the pre-dispatch record of a consumer's will to act
    * `intent_round_trip`     -> intent_round_trip_test.exs     -> O*->Human->Candidate->DO->Receipt->Event as one state loop
    * `intent`                -> intent_test.exs                -> SurfaceIntent construction and consequence edge
    * `ir_event_projection`   -> ir/event_projection_test.exs   -> consequence -> observation back-projection
    * `ir_codec_golden`       -> ir_codec_golden_test.exs       -> five-section SurfaceIR codec golden law
    * `ir_codec`              -> ir_codec_test.exs              -> IR codec serialization and content-addressing law
    * `ir_struct`             -> ir_struct_test.exs             -> IR + five embedded sections canonical shape
    * `ir`                    -> ir_test.exs                    -> SurfaceIR construction law
    * `live_view_projector`   -> live_view_projector_test.exs   -> deepened LiveView project_ir/2 contract (v35)
    * `no_local_do`           -> no_local_do_test.exs           -> no-local-DO tripwire: the surface never decides DO
    * `presentation_section`  -> presentation_section_test.exs  -> presentation label coercion: carrier, not coercer
    * `projector_ir_projector`-> projector/ir_projector_test.exs-> IRProjector over the injected legacy-behaviour seam
    * `voice_kiosk`           -> projector/voice_kiosk_test.exs -> VoiceKiosk extensibility proof: prompts, slot hints, receipt lines
    * `projector_ir_determinism` -> projector_ir_determinism_test.exs -> projector byte-determinism over permuted IRs
    * `projectors_aria`       -> projectors/aria_projector_test.exs -> Projectors.ARIA contract map law
    * `projectors_js`         -> projectors/js_projector_test.exs -> Projectors.JS single byte-deterministic JSDoc+Zod artifact
    * `projectors_live_view`  -> projectors/live_view_test.exs  -> ash_admin-pattern LiveView structure projector goldens
    * `validator_ir_alignment`-> resource/validator_ir_alignment_test.exs -> validator path and IR path action-set alignment
    * `schema_section`        -> schema_section_test.exs        -> zod schema section depth contract for Expo emission
    * `semantic_delegation`   -> semantic_delegation_test.exs   -> semantic delegation: compiled subject/predicates/ontology truth

  `golden_stability` is the suite whose own header freezes the golden tables
  and names "the action_id stability law"; it lives at `action_id_test.exs`.

  Renames are legal but must be conscious: update the canon table in the same
  change, or this canary fails. Deletions are refused — a chicago law suite
  may only be removed by removing its law.
  """

  use ExUnit.Case, async: true

  # {short name, canonical path (from test/), law one-liner}
  @canon [
    {"transport_select", "ash_surface/transport_select_test.exs", "transport law: selector"},
    {"transport_fallback", "ash_surface/transport_fallback_test.exs",
     "transport law: fallback ladder"},
    {"transport_outcome", "ash_surface/transport_outcome_test.exs",
     "transport law: outcome states"},
    {"transport_falsifiers", "ash_surface/transport_falsifiers_test.exs",
     "transport law: falsifiers"},
    {"digest", "ash_surface/digest_test.exs", "SHA-256 cross-language digest law"},
    {"golden_stability", "ash_surface/action_id_test.exs", "frozen golden id stability law"},
    {"validator", "ash_surface/resource/validator_test.exs", "resource validator law"},
    {"validator_adversarial", "ash_surface/resource/validator_adversarial_test.exs",
     "adversarial validator falsifiers"},
    # --- post-merge v26.9.16 law suites (gapfix-do-tripwire-006) ---
    {"aria_projector", "ash_surface/aria_projector_test.exs",
     "deep ARIA projector contract (deepens v19)"},
    {"ash_section_truth", "ash_surface/ash_section_truth_test.exs",
     "golden ash section: five action types, six typed argument families"},
    {"capability_delegation", "ash_surface/capability_delegation_test.exs",
     "capability section truth is ash_a2a's own derivation"},
    {"compiler_aria_section", "ash_surface/compiler/aria_section_test.exs",
     "aria section: mount point, role table, required, describedby ids"},
    {"compiler_ash_section", "ash_surface/compiler/ash_section_test.exs",
     "ash section built from a real inline resource"},
    {"compiler_capability_section", "ash_surface/compiler/capability_section_test.exs",
     "capability-section builder delegates to ash_a2a"},
    {"compiler_presentation_section", "ash_surface/compiler/presentation_section_test.exs",
     "presentation section from a real resource (humanize default)"},
    {"compiler_schema_section", "ash_surface/compiler/schema_section_test.exs",
     "compiler schema section content contract"},
    {"compiler_semantic_section", "ash_surface/compiler/semantic_section_test.exs",
     "semantic section builder, table-driven state law"},
    {"compiler_discovery", "ash_surface/compiler_discovery_test.exs",
     "DiscoverOnce law of AshSurface.Compiler"},
    {"compiler", "ash_surface/compiler_test.exs",
     "compiler discovery-once and section invocation order"},
    {"intent_candidate", "ash_surface/intent/candidate_test.exs",
     "candidate shaping law (canonical-local declarations)"},
    {"intent_dispatch", "ash_surface/intent/dispatch_test.exs",
     "delegated-DO falsifiers at the dispatch edge"},
    {"intent_path", "ash_surface/intent_path_test.exs",
     "SurfaceIntent: the pre-dispatch record of a consumer's will to act"},
    {"intent_round_trip", "ash_surface/intent_round_trip_test.exs",
     "O*->Human->Candidate->DO->Receipt->Event as one state loop"},
    {"intent", "ash_surface/intent_test.exs", "SurfaceIntent construction and consequence edge"},
    {"ir_event_projection", "ash_surface/ir/event_projection_test.exs",
     "consequence -> observation back-projection"},
    {"ir_codec_golden", "ash_surface/ir_codec_golden_test.exs",
     "five-section SurfaceIR codec golden law"},
    {"ir_codec", "ash_surface/ir_codec_test.exs", "IR codec serialization and content-addressing law"},
    {"ir_struct", "ash_surface/ir_struct_test.exs", "IR + five embedded sections canonical shape"},
    {"ir", "ash_surface/ir_test.exs", "SurfaceIR construction law"},
    {"live_view_projector", "ash_surface/live_view_projector_test.exs",
     "deepened LiveView project_ir/2 contract (v35)"},
    {"no_local_do", "ash_surface/no_local_do_test.exs",
     "no-local-DO tripwire: the surface never decides DO"},
    {"presentation_section", "ash_surface/presentation_section_test.exs",
     "presentation label coercion: carrier, not coercer"},
    {"projector_ir_projector", "ash_surface/projector/ir_projector_test.exs",
     "IRProjector over the injected legacy-behaviour seam"},
    {"voice_kiosk", "ash_surface/projector/voice_kiosk_test.exs",
     "VoiceKiosk extensibility proof: prompts, slot hints, receipt lines"},
    {"projector_ir_determinism", "ash_surface/projector_ir_determinism_test.exs",
     "projector byte-determinism over permuted IRs"},
    {"projectors_aria", "ash_surface/projectors/aria_projector_test.exs",
     "Projectors.ARIA contract map law"},
    {"projectors_js", "ash_surface/projectors/js_projector_test.exs",
     "Projectors.JS single byte-deterministic JSDoc+Zod artifact"},
    {"projectors_live_view", "ash_surface/projectors/live_view_test.exs",
     "ash_admin-pattern LiveView structure projector goldens"},
    {"validator_ir_alignment", "ash_surface/resource/validator_ir_alignment_test.exs",
     "validator path and IR path action-set alignment"},
    {"schema_section", "ash_surface/schema_section_test.exs",
     "zod schema section depth contract for Expo emission"},
    {"semantic_delegation", "ash_surface/semantic_delegation_test.exs",
     "semantic delegation: compiled subject/predicates/ontology truth"}
  ]

  test "the canon pins every load-bearing suite exactly once (no shadowed pins)" do
    paths = Enum.map(@canon, fn {_name, path, _law} -> path end)

    assert length(paths) == length(Enum.uniq(paths)),
           "canon table has duplicate paths — a pin is shadowing another"
  end

  for {short_name, path, law} <- @canon do
    test "canary: #{short_name} suite exists at canonical path #{path} (#{law})" do
      absolute = Path.expand(Path.join("../", unquote(path)), __DIR__)

      assert File.exists?(absolute),
             "integration dropped #{unquote(short_name)} (#{unquote(law)}): " <>
               "expected #{unquote(path)} to exist — restore the suite or consciously " <>
               "amend the canon in the same change; never delete a chicago law silently"
    end
  end
end
