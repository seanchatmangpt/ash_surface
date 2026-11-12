# Wave 3 RBU Receipt (conformance final regen after RBS/RBQ/RBI)

Standing: PASS

Subject: `MIX_ENV=test MIX_BUILD_ROOT=_build-rbu mix run scripts/conformance_regen.exs`
(CONFORMANCE_OUT unset), 788 vectors / 21 files.

## Diff-explain
Zero files changed: sha256 before == after for MANIFEST.json and every vector.
MANIFEST.json f89bb127...2357 unchanged; filter_operators.json e4628012...d6ed3 unchanged (RBK).
IR digest 52edac14...bbf399 unchanged; pin in test/ash_surface/ir_codec_golden_test.exs:53 untouched.
RBS (clean/camelize, KD-13), RBQ (format_input_name), RBI (KD-12 raise) produced no vector delta.
No lib touched.

## Name check
`?`-bearing strings in vectors are constraint/option keys (allow_nil?, keyset?, ...), not
FieldName inputs; no underscore-leading names present. JS reference and Elixir runner agree
(both pass on identical vectors).

## Gates (rc un-piped)
- Idempotence: second regen sha256-identical (MANIFEST + all 20 vectors). rc=0
- node conformance/js/replay.mjs rc=0
- mix test test/conformance: 28 tests, 0 failures, rc=0
- mix ash_surface.parity.tests rc=0, unaccounted=0 broken=0

## Before/after sha256 (identical)
- MANIFEST.json: f89bb127cd35c377d2a53cafe99fb03111815fedb7adf84d10d9dcb6370d2357
- vectors/calculation_envelope.json: 88bf6f160556e039f29f7cb90a25d6792c1699e0e8dfec4b8acaa5e5a2ca6c83
- vectors/canonical_json.json: 376e7b2ee5e820ed7863bcb6bbe94d9e3391233f96b4e2b9f3858193112850e0
- vectors/constraints.json: 11b8301072a91abb19430c22110b0e79c76efefb76d213c67965a7a0a033f001
- vectors/error_envelope.json: 3d174dbfb69310db2db8a647f7ef1b8212fbb216a92d27d4bba39add078d924f
- vectors/filter_operators.json: e46280126e2e856307e8cc8ab51135385b131ac1fae5e0e3540062eecf0d6ed3
- vectors/identity_get.json: 7b7ca3d9683d5fb83ee1b478a4b6459d7781b50497e1ca2785f3657697d6ffaf
- vectors/ir_codec.json: 3d522fda41b6056a234878a39b3440c3c788509129b3c07e73f35daa1b6101e1
- vectors/query_envelope.json: d60a02c1c2bb5d1594a1c00ac0c3c8037c3c2d7cd4d2f62d3106388de642d103
- vectors/receipt_binding.json: 258aec00baeb2d5f6db60b4998e1825d455dd3744b98ee262c6b58e7853f6d13
- vectors/receipt_digest.json: d4f94deab8b04c2df6d303cb25500c04d49b94e2000d1310e4148ef27ea6c520
- vectors/reconcile_status.json: 604b8a479f8f8a476c32b740d774c1a3625ae26f699c57e7686c9e49d08b87b4
- vectors/refusal_vocabulary.json: 0014d38592ee08a501e50e7ad540153a22b1fa80b19645bd3d840eb4b8412ea3
- vectors/relationship_loads.json: 59a6c3d98b690d43ec0ed266134c12e6deca7d31d194673acd68876c598b0cd2
- vectors/selection_admission.json: 7f9b6fe79e7d64a0accc87d0a62331f414e7af5a19ae92574bf54300046a6bda
- vectors/surface_contract_digest.json: 0a67ce4fd8d7d648b6dc8546d1bac2f671ad5ca543eaa64cc82a3a2fb6ec4e40
- vectors/surface_contract_refusal.json: 21f6547bfa91208c79b8bdd14f7987d6d7431bc96833eaea0179817017a42d1a
- vectors/transport_facts_admission.json: 3c9fc0709f6a55b632c243ab1a878a247d6e06cff97466538f83814a17a79246
- vectors/transport_outcome.json: 31f23eb576227008658cb09869b0ec462acb48812e528ac8bbf85bae6830631e
- vectors/transport_selection.json: 3b50bf3d5d5619fb74c82b2383e3c501c3a7d026a37e2fc0e95abb886a19ca31
- vectors/transport_wire.json: 1d1d0cd744e2457092fe114adeafa74b2bfe038a07ecc6999267e437b20689d2
- vectors/union_schema.json: ff4c14d2ab148f8f1bbfa91442e1772a9dc2d4e62773a01596b631b838cdc75e

Falsifier: any vector changed without a receipt; none found.
