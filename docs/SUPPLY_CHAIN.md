# Supply chain

What an enterprise procurement review can verify about `ash_surface`, and how.

## Controls

| Control | Where | Cadence |
| --- | --- | --- |
| Dependency updates (mix, npm, github-actions), grouped | `.github/dependabot.yml` | weekly |
| Advisory + hygiene audit (`mix hex.audit`, `npm audit --omit=dev --audit-level=high`, `mix deps.unlock --check-unused`, `npm audit signatures`) | `.github/workflows/security.yml` | daily + every PR |
| Existing PR gate | `.github/workflows/ci.yml` (`mix hex.audit`) | every PR |
| SBOM (CycloneDX 1.5) | `scripts/sbom.sh` | every release, drift-checked daily |
| Build provenance attestation | `.github/workflows/release.yml` | every tag |
| Human-approved publish | `hex-publish` environment | every release |

### Why a scheduled audit

Advisories publish against code that has not changed. `mint` went red
mid-PR on 2026-09-28 (EEF-CVE-2026-91043/92103/94194, fixed by `10b2be4`) with
no commit touching it. A PR-only audit is green until the next unrelated push;
the daily run makes an advisory a red build within a day. All steps are
fail-closed: no error-tolerance flags.

## SBOM

```sh
scripts/sbom.sh sbom.cdx.json
```

Reads only `mix.lock`, `package-lock.json` and `mix.exs` (`@version`). Offline,
no third-party tooling, no clock, no randomness: `serialNumber` is a UUID
derived from the component list, keys are sorted, so identical lockfiles yield
byte-identical output (asserted in `test/ash_surface/supply_chain_test.exs`).
Each hex component has `pkg:hex/<name>@<version>`, the outer SHA-256 as `hashes`
and the inner checksum as a property; git dependencies use
`pkg:github/<owner>/<repo>@<40-hex commit>`; npm uses `pkg:npm/...` with the
SHA-512 integrity and license. It does not include transitive npm devtools
(`playwright` is installed `--no-save` in CI only) or system packages.

## Provenance

`release.yml` runs `actions/attest-build-provenance` over `dist/*` (source
tarball, SBOM, hex tarball when buildable). Needs job permissions
`id-token: write` and `attestations: write`. Verify:

```sh
gh attestation verify ash_surface-<ver>-src.tar.gz --repo seanchatmangpt/ash_surface
```

## Known gaps (honest list)

- **Actions are pinned by version tag, not commit SHA**, as in `ci.yml`. SHA
  pinning needs online tag resolution and is a follow-up; once done, the
  github-actions Dependabot ecosystem maintains the SHAs.
- **Git dependencies**: `ash_a2a` (tag `v26.9.22`, resolved to a commit in
  `mix.lock`) and `ash_r2rml` (commit ref) are not hex packages: no registry
  checksum, not visible to `mix hex.audit`, ignored by Dependabot. They also
  block `mix hex.build` ("Only Hex packages can be dependencies"), so hex
  publication is blocked until they are published. Bump them by hand and
  review the diff.
- No Dependabot/attestation run could be verified offline; the workflows are
  YAML-validated only.

## License audit

Source: `deps/*/hex_metadata.config` (88 of 90 deps; the two git deps carry no
metadata), plus npm `zod` (MIT), at the time of writing.

| License | Count | Notes |
| --- | --- | --- |
| MIT | 47 | permissive |
| Apache-2.0 (incl. `Apache 2`) | 38 | permissive; `content_type` declares the non-SPDX `Apache 2` |
| MIT / Apache-2.0 dual | 1 | permissive |
| BSD 2-Clause | 1 | permissive (`yamerl`; non-SPDX spelling of BSD-2-Clause) |
| **MPL-2.0** | 1 | **flag**: `open_api_spex` (transitive via `ash_ai`/`ash_json_api`) |

MPL-2.0 is weak file-level copyleft: modifications to MPL files must be shared,
but linking from a permissive/proprietary work is allowed and it does not
propagate to `ash_surface` (MIT). It is a dev/transitive dependency, not
vendored. Legal should be told it exists; no action is required unless the
file is modified. `ash_a2a` and `ash_r2rml` (git) licenses were not verifiable
offline. Re-run:

```sh
for f in deps/*/hex_metadata.config; do echo "$(basename $(dirname $f)) $(grep -o '"licenses">>,\[.*\]}' $f)"; done
```
