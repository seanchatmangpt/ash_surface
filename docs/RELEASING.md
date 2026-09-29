# Releasing

CalVer `YY.M.N`. `mix.exs` `@version` is the single source; the tag is `v<version>`
and `release.yml` refuses a tag that disagrees with it or with a missing
`## [<version>]` heading in `CHANGELOG.md`.

## Checklist

1. **Bump**: `scripts/bump_version.sh` (or edit `@version`), then move
   `CHANGELOG.md` `[Unreleased]` items under `## [<version>] - <date>`.
2. **Census / floor re-pin** (TESTING.md, "Chicago suite census"): if suites
   were added or removed, regenerate `scripts/chicago_census.txt` with
   `git ls-files 'test/*_test.exs' 'test/js/*.test.mjs' | LC_ALL=C sort` and
   re-measure the `# floor: <N>` line from `mix test`. New test files that are
   not in the census fail the battery; a stale floor lets a suite shrink.
3. **Golden re-pin**: IR codec and runtime goldens
   (`test/ash_surface/ir_codec_golden_test.exs`, runtime artifact golden) must
   be re-frozen deliberately, never to make a red test green. Re-run the
   falsifier (`scripts/ci_falsifier.sh`) so the guards still turn red.
4. **Local gates**, cheapest first (AGENTS.md): JS tests, `node --check
   priv/static/*.mjs`, `mix format --check-formatted`,
   `mix compile --warnings-as-errors`, `mix test.all`, `mix test.zero`,
   `bash scripts/zero_config_v2.sh`.
5. **Supply chain**: `mix supply.check`, `npm audit --omit=dev
   --audit-level=high`, `scripts/sbom.sh` (inspect the diff against the last
   release's SBOM), `mix hex.build --unpack` (see known blocker below).
6. **Tag**: `git tag -s v<version> && git push origin v<version>`.
7. **Watch `release.yml`**: gates -> build (SBOM, attestation) -> draft GitHub
   release. Verify `gh attestation verify` on the artifacts.
8. **Publish to hex (manual)**: approve the `hex-publish` environment review
   in the Actions UI. Requires environment secret `HEX_API_KEY`; the job only
   exists when the hex tarball built.
9. Publish the draft GitHub release.

## One-time repository setup

- Create environment `hex-publish` with required reviewers; put `HEX_API_KEY`
  there (not a repo secret).
- Enable Dependabot security updates and private vulnerability reporting.
- Protect `v*` tags.

## Known blocker

`mix hex.build` fails with "Dependencies excluded from the package (only Hex
packages can be dependencies): ash_r2rml, ash_a2a". Until both are published to
hex, the release produces source tarball + SBOM + attestation only and the
publish job is skipped (fail-closed: `hex_built` must be `true`).
`package/0` `files:` are otherwise correct: `lib` (incl.
`lib/ash_surface/projectors/js/zod_guard.ex`), `priv` (incl.
`priv/static/*.mjs`), `mix.exs`, `README.md`, `AGENTS.md`, `LICENSE`,
`CHANGELOG.md`, `SECURITY.md`.
