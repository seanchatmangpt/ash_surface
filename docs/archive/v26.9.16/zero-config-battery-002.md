# zero-config-battery-002: v2 zero-config proof script
status: DONE
created: 2026-09-17T03:20:00Z
## Mission
(Relaunch of rate-limited v40.) scripts/zero_config_v2.sh: full battery in a fresh LOCAL clone (reuse scripts/zero_config_check.sh pattern): env -i PATH HOME, git clone local, mix deps.get, mix test, npm install, npm test, plus mix test.zero if present. Guard: FAIL if any test/ file reads env vars (System.get_env outside documented allowlist). Final line ZERO_CONFIG_OK. Run it; record exits.
## Acceptance
- bash scripts/zero_config_v2.sh -> 0, ZERO_CONFIG_OK printed
- History records every exit code
## History
2026-09-16T19:26:45Z | ALIVE | exp/v40 6c4ba94c34394a22bb148c7ce310d7ddbadfe0ef (base 282f3ca) | bash scripts/zero_config_v2.sh -> 0, ZERO_CONFIG_OK; EXIT[env-read guard]=0 EXIT[mix deps.get]=0 EXIT[npm install]=0 EXIT[mix test]=0 (308 passed) EXIT[npm test]=0 (175/175 JS) EXIT[mix test.zero]=0 (present; scrubbed test.all re-run green); guard falsified on fixtures (SECRET_TOKEN+opaque flagged, HOME allowed); bash -n=0 shellcheck=0; run twice, second against exact committed tree | none — remaining: ledger paydown of scripts/zero_config_*.sh into a pack template (tracked in HANDWRITTEN.md)
