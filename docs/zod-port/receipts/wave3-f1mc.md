# Wave 3 F1 mock court parse report

Standing: PARTIAL_ALIVE

## Reproduction

`MIX_BUILD_ROOT=_build-f1mc mix test test/ash_surface_mock_discipline_test.exs` exit 0:
`1 test, 0 failures`. The reported unparseable files did NOT reproduce. Both files parse
(`Code.string_to_quoted` returns `{:ok, _}`); lines js_mapped_fields_test.exs:44 and
inference_tsc_test.exs:15 are plain asserts / `~S[...]` sigils. Likely cause: lane w3-07 scanned
the files mid-edit by their authoring lanes. Premise rot, not a scanner gap.

## Changes

- Added a non-vacuity test to the court: `use Mox`, `Mimic.stub/3`, `:meck.new/1` in temp source
  are detected; invalid source returns `{:error, %{file, line}}` (fails loudly); banned text
  inside `~S[]` and heredocs is not flagged.
- Scanner unchanged (lib not owned). Gap: `Application.put_env` injection is not detected.

## Fake/Stub census

Only hit under test/ (excluding support): `intent_round_trip_test.exs:262` `RecordingFakeBus`,
a hand-written real interface implementation, so allowed. No court widening (it would need
lib changes; hit list is reported instead).

## Verification

- court + js_mapped_fields + inference_tsc + no_local_do: 17 tests, 0 failures, 1 skipped.
- `mix format --check-formatted` on the court: exit 0.
- `_build-f1mc` deleted.

## Files changed

test/ash_surface_mock_discipline_test.exs, this receipt.
