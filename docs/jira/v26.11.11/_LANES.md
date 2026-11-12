# Lanes

Lane partition ledger for v26.11.11 (one canonical checkout; lanes own disjoint
files, coordinator owns git transitions). Statuses are a snapshot at L25 write
time, re-read from receipts on disk — landed lanes show their receipt Standing.

Lane status is NOT restated here. Standing per lane = the `Standing:` line of its receipt
(`docs/zod-port/receipts/`); capability status = `PARITY-REGISTER.md`.

| lane | owned files | receipt |
|---|---|---|
| L01 | constraint intake (ash_truth.ex) | receipts/L01.md |
| L02 | IR contract (compiler.ex, ir.ex, codec.ex) | receipts/L02.md |
| L04 | zod fragments (schema.ex, zod_type.ex) | receipts/L04.md |
| L05 | expo mirror (expo.ex) | receipts/L05.md |
| L06 | zodguard courts | receipts/L06.md |
| L07 | safeParse envelope (js.ex) | receipts/L07.md |
| L08 | runtime issues (.mjs) | receipts/L08.md |
| L09 | filter operators | receipts/L09.md |
| L10 | query envelopes | receipts/L10.md |
| L11 | selection admission | receipts/L11.md |
| L14 | conformance constraints vectors | receipts/L14.md |
| L16 | fragment courts | receipts/L16.md |
| L17 | safeparse courts | receipts/L17.md |
| L18 | overview/comparison/changelog docs | receipts/L18.md |
| L20 | relationships/loads | receipts/L20.md |
| L21 | unions | receipts/L21.md |
| L22 | calculations/aggregates | receipts/L22.md |
| L23 | identities/tenant | receipts/L23.md |
| L24 | parity register | receipts/L24.md |
| L25 | index + ledger | receipts/L25.md |

Wave 2/3 lanes (`wave2-*`, `wave3-*`, `lane-NN`) are indexed in `docs/zod-port/CONTRACT.md`.

## Shared-file seams

- **schema.ex ↔ expo.ex twin law**: the zod fragment projection and the expo
  mirror must stay structurally twinned; edits to one require a disclosure in
  both lanes' receipts.
- **vocabulary.ex Elixir ↔ JS twin**: the operator/type vocabulary exists on
  both sides of the projection; a change on one side must name the other
  lane's receipt (same-checkout-fanout collision-disclosure law).
