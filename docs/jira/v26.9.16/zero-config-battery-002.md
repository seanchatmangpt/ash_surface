# zero-config-battery-002: v2 zero-config proof script
status: OPEN
created: 2026-09-17T03:20:00Z
## Mission
(Relaunch of rate-limited v40.) scripts/zero_config_v2.sh: full battery in a fresh LOCAL clone (reuse scripts/zero_config_check.sh pattern): env -i PATH HOME, git clone local, mix deps.get, mix test, npm install, npm test, plus mix test.zero if present. Guard: FAIL if any test/ file reads env vars (System.get_env outside documented allowlist). Final line ZERO_CONFIG_OK. Run it; record exits.
## Acceptance
- bash scripts/zero_config_v2.sh -> 0, ZERO_CONFIG_OK printed
- History records every exit code
## History
