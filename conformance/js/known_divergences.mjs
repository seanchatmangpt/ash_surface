// Vector ids on which the JavaScript side is KNOWN to disagree with the Elixir
// implementation, with the exact JavaScript output pinned.
//
// Each entry is an assertion, not an exemption: the vector must still disagree, and
// with exactly this output. If the disagreement disappears (someone fixes it) or
// changes shape, the replay goes RED and the entry must be removed or updated.
// Every entry is a cross-language bug or an undecided spec point; see
// docs/CONFORMANCE.md ("Known divergences").
//
// jsActual values were captured by executing the JS replay (not typed by hand).
export const KNOWN_DIVERGENCES = Object.freeze({
  "cj/lexical/duplicate-keys": {
    "reason": "duplicate object keys are parser-defined: Jason keeps the FIRST occurrence, JSON.parse the LAST (RFC 8259 leaves it undefined), so the same text canonicalizes differently",
    "jsActual": {
      "canonical": "{\"a\":2}",
      "sha256": "7e8059f495589fcd981232cc11d00b00da3802c01d688fa1cf1f6bed6e5bb33c"
    }
  },
  "cj/lexical/integral-float": {
    "reason": "JavaScript numbers have no int/float distinction and JSON.stringify spelling differs from Erlang/Jason float spelling (1 vs 1.0, 1e+21 vs 1.0e21, 100000 vs 1.0e5, 0 vs -0.0)",
    "jsActual": {
      "canonical": "{\"n\":1}",
      "sha256": "2bfd14f43d17fc7cea24e0917a8879b4b2f880b8baeec1b9d90fbaad655e71bd"
    }
  },
  "cj/lexical/integral-float-large": {
    "reason": "JavaScript numbers have no int/float distinction and JSON.stringify spelling differs from Erlang/Jason float spelling (1 vs 1.0, 1e+21 vs 1.0e21, 100000 vs 1.0e5, 0 vs -0.0)",
    "jsActual": {
      "canonical": "{\"n\":100000}",
      "sha256": "f8c9d862b09bd554858591decf634c11cc1d013869a58adcb3d62166abd79da0"
    }
  },
  "cj/lexical/exponent-float": {
    "reason": "JavaScript numbers have no int/float distinction and JSON.stringify spelling differs from Erlang/Jason float spelling (1 vs 1.0, 1e+21 vs 1.0e21, 100000 vs 1.0e5, 0 vs -0.0)",
    "jsActual": {
      "canonical": "{\"n\":1e+21}",
      "sha256": "f1ee2b60ee95a3170fdc07a577e5f3514ced26867443d69da265acadead81007"
    }
  },
  "cj/lexical/small-exponent-float": {
    "reason": "JavaScript numbers have no int/float distinction and JSON.stringify spelling differs from Erlang/Jason float spelling (1 vs 1.0, 1e+21 vs 1.0e21, 100000 vs 1.0e5, 0 vs -0.0)",
    "jsActual": {
      "canonical": "{\"n\":1e-7}",
      "sha256": "747d6d23b64d1b2d579adb832b44de31c91c875bbef7a8e397f5d183a746b54b"
    }
  },
  "cj/lexical/beyond-safe-int": {
    "reason": "JSON.parse rounds integers beyond 2^53-1 to the nearest double; Elixir keeps them exact",
    "jsActual": {
      "canonical": "{\"n\":9007199254740992}",
      "sha256": "66c87d9cb3014e05a11baa97df62282d89d425f22ee15816577c84534e2ef1bb"
    }
  },
  "cj/lexical/negative-zero-float": {
    "reason": "JavaScript numbers have no int/float distinction and JSON.stringify spelling differs from Erlang/Jason float spelling (1 vs 1.0, 1e+21 vs 1.0e21, 100000 vs 1.0e5, 0 vs -0.0)",
    "jsActual": {
      "canonical": "{\"n\":0}",
      "sha256": "f3013f933b9fb80ab6d995e7ad9da36f683837ba1d81e950c943d40111eac2f0"
    }
  },
  "sc/lexical-integral-float": {
    "reason": "contract value 2.0 parses to the JS number 2, which the ETF twin digests as an integer; Elixir digests the float 2.0 (jsActual re-captured after the v26.10.7 bump: the JS-side digest includes surfaceSchemaVersion)",
    "jsActual": {
      "digest": "ba9b36c377411c8c135c5581df256a97def4f55590340b9438d7159d385c5f9c"
    }
  },
  "rd/lexical-float-consequence": {
    "reason": "consequence value 2.0 re-serializes as 2 in JS; the receipt hash is over different bytes than Elixir's",
    "jsActual": {
      "sha256": "1c21b9a442c5e15ee1ffb5dde267359533d8d74077a863897d5c3bfe900127c0"
    }
  },
  "rb/lexical-float-consequence": {
    "reason": "a receipt whose hash Elixir minted over 2.0 does not bind when JS re-serializes the consequence as 2 (and vice versa: a JS-minted hash over 2 is REFUSED_RECEIPT_DIGEST_MISMATCH in Elixir when the wire value was 2.0)",
    "jsActual": {
      "binding": "mismatch",
      "eventAdmitted": true,
      "stateDigest": "e1fe6b2424af00caa025b7fa54a45187f113ee3219e2576f5da79fccee51995e",
      "receiptRef": "909bf95cae41667ceb97fa13280ce6ca22fef229c0ef9f22f356d1fdcc62fe8a"
    }
  }
});
