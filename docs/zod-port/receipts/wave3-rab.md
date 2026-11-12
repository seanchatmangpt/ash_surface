# wave3-rab

Standing: PASS

Lane RAB: fix `Introspector.common_suffix/1` char-trim latent bug (disclosed in wave3-rx).
Subject: HEAD e3b5d7ffe plus uncommitted tree (introspector.ex is untracked).

## Reference

`~/ash_typescript` `router_introspector.ex` `longest_common_suffix` has the same
grapheme-wise defect, so no lawful reference behaviour exists beyond the stated intent
(scope prefix = the `as:` scope segments). Lawful behaviour adopted: whole-segment suffix on
`_`-split helpers. Divergence from reference, witnessed by the new courts.

## Fix

`lib/ash_surface/compiler/route_schema/introspector.ex`: `common_suffix/1` returns a segment
list; `scope_prefix/2` drops the last N segments and joins the rest with `_`. Also removes the
repeated-trim behaviour of `String.trim_trailing/2`.

## Courts (new describe "segment-wise scope prefix derivation", 7 tests)

alpha/zeta; shared trailing char (`ab`/`b`); unscoped beside scoped (`""`/`x`); `p` vs `p_q`;
identical helpers -> typed `ambiguous_mount`; trailing slash + `:id`; nested scope repeating a
suffix segment (`api_auth`). Existing tests untouched.

## Red proof (scratch, no repo copy: topology guard refused rsync of the repo)

`/tmp/rab_mut.ex` = introspector with the char-trim restored (marked SHIM-COURT), loaded over
the compiled module via `mix do run -r /tmp/rab_mut.ex + test <file>` (MIX_ENV=test): rc=2,
19 tests 3 failures (alpha/zeta -> `alph`/`zet`; `ab`/`b` -> `a`/``; trailing/param).
Real file sha256 before and after: c36d0ddf4f4a59d3a463eb68503bed1937cb87c1fcdd3e985147c132341756e3
(never modified by the mutation). Output `/tmp/rab_red.txt`. UNVERIFIED: the identical-path,
`p`/`p_q`, unscoped and nested courts pass under the mutation too (non-discriminating
regression guards).

## Gates (MIX_BUILD_ROOT=_build-rab)

- `mix test test/ash_surface/ported/typed_controller`: rc=0 un-piped, 115 tests, 0 failures,
  13 skipped. Compile warning: IdenticalPathRouter's duplicate clause (intentional).
- `mix ash_surface.parity.tests`: rc=0, unaccounted=0 broken=0.
