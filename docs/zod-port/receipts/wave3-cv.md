# Wave 3 CV: container renderers adversarial re-pin

Standing: PASS

- Cause verified: premise rot. Default output formatter is :camel_case, so embedded field
  names and union member keys are camelized; tests expected verbatim hostile names.
  No renderer defect (no key collision, no __proto__/constructor emission seen).
- Re-pin (test only): embedded fields carry `"wire" => true` (verbatim, as lane CI did);
  union expected keys computed via `AshSurface.FieldName.emitted/1`, deduped on collision.
  Hostile-name set unchanged.
- Before: `MIX_BUILD_ROOT=_build-cv mix test .../container_renderers_adversarial_test.exs`
  53 tests, 4 failures.
- After: `MIX_BUILD_ROOT=_build-cv mix test test/ash_surface/adversarial` rc=0 (un-piped
  to file, then echo), 133 tests, 0 failures.
- Not run: full suite (UNVERIFIED). Collision-after-camelization court not added: no defect
  witnessed.
