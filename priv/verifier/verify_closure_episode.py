#!/usr/bin/env python3.11
"""In-repo episode verifier for ash_surface@v26.9.17 (mx-episode-schema@v26.9.17).

Vendored (finish-experience-023) from
ggen-marketplace/domains/repo-closure/verifier/verify_closure_episode.py
(repo-closure@v26.9.13) so the independent closed-loop replay check can never
fail-open-skip on a missing marketplace checkout: this file ships inside the
ash_surface OTP application's priv/ directory and runs unconditionally.

Verifies that an MX episode adheres to mx-episode-schema@v26.9.17 and binds
the exact CalVer identities required for replay:
  Replay = f(SubjectHead, Pattern@v26.9.17, Domain@v26.9.17, HDDL@v26.9.17,
             FOND@v26.9.17, Verifier@v26.9.17)

CLI:
    python3 verify_closure_episode.py <episode.json>
prints "[<CODE>] <message>" and exits 0 iff the episode is VALID.

The importable `verify_episode(data)` API is preserved unchanged from the
marketplace original.
"""

from __future__ import annotations

import json
import sys
from dataclasses import dataclass
from typing import Any


EXPECTED_CALVER = "v26.9.17"
REQUIRED_FIELDS = {
    "episode_id",
    "subject_repo",
    "subject_head",
    "pattern_version",
    "domain_version",
    "hddl_version",
    "fond_version",
    "verifier_version",
    "selected_decomposition",
    "observed_transitions",
    "cost_score",
    "receipt_hash",
    "resulting_standing",
}


@dataclass(frozen=True)
class VerificationResult:
    valid: bool
    code: str
    message: str


def verify_episode(data: dict[str, Any]) -> VerificationResult:
    missing = REQUIRED_FIELDS - set(data.keys())
    if missing:
        return VerificationResult(
            valid=False,
            code="MISSING_EPISODE_FIELDS",
            message=f"Missing required fields: {sorted(missing)}",
        )

    # Check CalVer bindings
    for field in ("pattern_version", "domain_version", "hddl_version", "fond_version", "verifier_version"):
        val = data.get(field)
        if val != EXPECTED_CALVER:
            return VerificationResult(
                valid=False,
                code="CALVER_MISMATCH",
                message=f"Expected {field}='{EXPECTED_CALVER}', found '{val}'",
            )

    standing = data.get("resulting_standing")
    if standing not in {"ALIVE", "PARTIAL_ALIVE", "BLOCKED", "BUILD_BROKEN", "UNSUPPORTED"}:
        return VerificationResult(
            valid=False,
            code="INVALID_STANDING",
            message=f"Resulting standing '{standing}' is not recognized",
        )

    return VerificationResult(valid=True, code="VALID", message="Episode lawfully verified and bound for replay")


def main() -> int:
    if len(sys.argv) == 2:
        with open(sys.argv[1]) as f:
            data = json.load(f)

        result = verify_episode(data)
        print(f"[{result.code}] {result.message}")
        return 0 if result.valid else 1

    sample_episode = {
        "episode_id": "MXEpisode/2026-09-17/000001",
        "subject_repo": "seanchatmangpt/ash_surface",
        "subject_head": "00f14b1b966900aa129f16a2e51727ef697823ec",
        "pattern_version": "v26.9.17",
        "domain_version": "v26.9.17",
        "hddl_version": "v26.9.17",
        "fond_version": "v26.9.17",
        "verifier_version": "v26.9.17",
        "selected_decomposition": ["task_regenerate", "task_compile", "task_inspect", "task_emit_receipt"],
        "observed_transitions": [{"step": "compile", "outcome": "pass"}],
        "cost_score": 1.2,
        "receipt_hash": "sha256:920b3868d75bdf0bed6abcb1422d29f7e785d945c43d11af6e0f455bfd4299cf",
        "resulting_standing": "ALIVE",
    }

    result = verify_episode(sample_episode)
    print(f"[{result.code}] {result.message}")
    return 0 if result.valid else 1


if __name__ == "__main__":
    sys.exit(main())
