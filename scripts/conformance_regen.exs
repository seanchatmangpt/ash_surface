# Regenerates the AshSurface conformance corpus (conformance/vectors/*.json and
# conformance/MANIFEST.json) from the REAL Elixir implementation.
#
#     MIX_ENV=test mix run scripts/conformance_regen.exs
#
# MIX_ENV=test is required only because the contract fixtures use the test-support
# Ash resource `AshSurface.Fixtures.VolunteerMilestone`.
#
# INPUTS are authored here; every EXPECTED value is produced by
# `AshSurface.Conformance.Runner` driving the public implementation — never
# typed by hand. Output is deterministic (no clocks, no randomness, canonical
# key-sorted JSON, one vector per line): re-running yields byte-identical files.

Code.require_file(Path.expand("../conformance/elixir/runner.exs", __DIR__))

defmodule ConformanceRegen do
  alias AshSurface.CanonicalJSON
  alias AshSurface.Conformance.Runner
  alias AshSurface.IR
  alias AshSurface.IR.Codec

  # CONFORMANCE_OUT redirects the whole corpus (vectors + MANIFEST) to a scratch dir
  # for trial regenerations; unset = the canonical conformance/ directory.
  @conf System.get_env("CONFORMANCE_OUT") || Path.expand("../conformance", __DIR__)
  @out Path.join(@conf, "vectors")

  @transports ["http", "phoenix_channel"]
  @abbr %{"http" => "h", "phoenix_channel" => "c"}

  def main do
    File.mkdir_p!(@out)
    Enum.each(Path.wildcard(Path.join(@out, "*.json")), &File.rm!/1)

    files = [
      {"transport_selection", transport_selection()},
      {"transport_facts_admission", transport_facts_admission()},
      {"canonical_json", canonical_json()},
      {"surface_contract_digest", surface_contract_digest()},
      {"surface_contract_refusal", surface_contract_refusal()},
      {"receipt_digest", receipt_digest()},
      {"receipt_binding", receipt_binding()},
      {"refusal_vocabulary", refusal_vocabulary()},
      {"reconcile_status", reconcile_status()},
      {"ir_codec", ir_codec()},
      {"transport_outcome", transport_outcome()},
      {"constraints", constraints()},
      {"filter_operators", filter_operators()},
      {"query_envelope", query_envelope()},
      {"selection_admission", selection_admission()},
      {"relationship_loads", relationship_loads()},
      {"calculation_envelope", calculation_envelope()},
      {"identity_get", identity_get()},
      {"error_envelope", error_envelope()},
      {"union_schema", union_schema()},
      {"transport_wire", transport_wire()},
      {"field_name_emission", field_name_emission()}
    ]

    entries =
      for {kind, vectors} <- files do
        ids = Enum.map(vectors, & &1["id"])
        if ids != Enum.uniq(ids), do: raise("duplicate vector ids in #{kind}")
        vectors = Enum.map(vectors, &realize(kind, &1))
        write_file(kind, vectors)
      end

    manifest = %{
      "corpus" => "ash_surface-conformance",
      "corpusVersion" => Runner.corpus_version(),
      "hashAlgorithm" => "sha256",
      "lawVersion" => AshSurface.schema_version(),
      "vectorCount" => entries |> Enum.map(& &1["vectorCount"]) |> Enum.sum(),
      "files" => entries
    }

    File.write!(
      Path.join(@conf, "MANIFEST.json"),
      CanonicalJSON.encode(manifest) <> "\n"
    )

    IO.puts("conformance: #{manifest["vectorCount"]} vectors in #{length(entries)} files")
  end

  # -- constraints (lane L14) ---------------------------------------------------------
  #
# Input = the schema section's discovery shape (string-keyed): one action,
# one constrained argument per vector unless the vector is explicitly about
# composition, key quoting, multiple arguments, or a malformed discovery.
# Expected (fragment rendering only — no value evaluation; that half is
# BLOCKED, see receipts/L14.md) is minted by the real implementation through
# Runner.run("constraints", _) -> AshSurface.Compiler.Schema.build/2.

  defp constraints do
    [
      # enum (one_of)
      v("c/enum-string", "one_of strings renders z.enum",
        disc(%{"kind" => "string"}, %{"one_of" => ["alpha", "beta"]})),
      v("c/enum-number", "one_of numbers renders z.enum",
        disc(%{"kind" => "integer"}, %{"one_of" => [1, 2, 3]})),
      v("c/enum-mixed", "one_of mixed literal types renders z.enum",
        disc(%{"kind" => "string"}, %{"one_of" => ["x", 1, true]})),
      v("c/enum-empty", "empty one_of renders nothing (byte-identical to unconstrained)",
        disc(%{"kind" => "string"}, %{"one_of" => []})),
      # numeric bounds
      v("c/min-integer", "integer min renders .min",
        disc(%{"kind" => "integer"}, %{"min" => 1})),
      v("c/max-float", "float max renders .max",
        disc(%{"kind" => "float"}, %{"max" => 99.5})),
      v("c/min-max-integer", "integer min+max renders both in chain order",
        disc(%{"kind" => "integer"}, %{"min" => 1, "max" => 10})),
      v("c/min-on-string-kind", "numeric min on a string kind is dropped",
        disc(%{"kind" => "string"}, %{"min" => 3})),
      v("c/min-non-number", "non-number min is ignored",
        disc(%{"kind" => "integer"}, %{"min" => "3"})),
      # string length bounds
      v("c/min-length-string", "string min_length renders .min",
        disc(%{"kind" => "string"}, %{"min_length" => 1})),
      v("c/max-length-string", "string max_length renders .max",
        disc(%{"kind" => "string"}, %{"max_length" => 64})),
      v("c/min-length-non-integer", "non-integer min_length is ignored",
        disc(%{"kind" => "string"}, %{"min_length" => 1.5})),
      v("c/min-length-on-integer-kind", "min_length on an integer kind is dropped",
        disc(%{"kind" => "integer"}, %{"min_length" => 2})),
      # regex (match)
      v("c/match-plain", "string match renders .regex",
        disc(%{"kind" => "string"}, %{"match" => "^[a-z]+$"})),
      v("c/match-slash", "match containing / renders an escaped slash (valid JS regex literal)",
        disc(%{"kind" => "string"}, %{"match" => "a/b"}),
        "ZodType escapes ONLY an unescaped `/` (renders regex(/a\\/b/)); backslash pairs pass through untouched, so the literal is valid JS and matches the expo.ex byte-mirror."),
      v("c/match-backslash", "match containing backslash is preserved (not doubled)",
        disc(%{"kind" => "string"}, %{"match" => "\\d+"}),
        "Backslash pairs pass through untouched: `\\d+` renders regex(/\\d+/), NOT a doubled `\\\\d+`."),
      v("c/match-on-integer-kind", "match on an integer kind is dropped",
        disc(%{"kind" => "integer"}, %{"match" => "^\\d+$"})),
      # composition
      # -- w3-04: ZodType wave-2 rules -------------------------------------------------
      v("c/gt-lt-integer", "greater_than/less_than render .gt/.lt after min/max",
        disc(%{"kind" => "integer"}, %{"min" => 0, "max" => 100, "greater_than" => 1, "less_than" => 99})),
      v("c/gt-float", "float greater_than renders .gt",
        disc(%{"kind" => "float"}, %{"greater_than" => 0.5})),
      v("c/lt-on-string-kind", "less_than on a string kind is dropped",
        disc(%{"kind" => "string"}, %{"less_than" => 5})),
      v("c/array-min-max-length", "array cardinality: min_length/max_length apply after z.array(..)",
        disc(%{"kind" => "array", "items" => %{"kind" => "string"}}, %{"min_length" => 1, "max_length" => 3})),
      v("c/array-no-items", "array without items renders z.array(z.unknown()) plus cardinality",
        disc(%{"kind" => "array"}, %{"max_length" => 2})),
      v("c/array-nested-items", "nested array items render recursively (array of arrays of uuid)",
        disc(%{"kind" => "array", "items" => %{"type" => %{"kind" => "array", "items" => %{"kind" => "uuid"}}}}, %{})),
      v("c/array-item-definition", "array item given as a full definition carries its own constraints and nullability",
        disc(%{"kind" => "array", "items" => %{"type" => %{"kind" => "string"}, "constraints" => %{"min_length" => 2}, "allow_nil?" => true}}, %{})),
      v("c/allow-empty-false", "string allow_empty?: false renders .min(1)",
        disc(%{"kind" => "string"}, %{"allow_empty?" => false})),
      v("c/allow-empty-false-min-length", "allow_empty?: false keeps a larger explicit min_length",
        disc(%{"kind" => "string"}, %{"allow_empty?" => false, "min_length" => 3})),
      v("c/allow-empty-false-min-length-zero", "allow_empty?: false lifts min_length 0 to 1",
        disc(%{"kind" => "string"}, %{"allow_empty?" => false, "min_length" => 0})),
      v("c/allow-empty-true", "allow_empty? true adds nothing",
        disc(%{"kind" => "string"}, %{"allow_empty?" => true})),
      v("c/allow-empty-on-integer", "allow_empty? on a non-string kind is dropped",
        disc(%{"kind" => "integer"}, %{"allow_empty?" => false})),
      v("c/regex-flags", "match_flags render sorted unique i/m/s",
        disc(%{"kind" => "string"}, %{"match" => "^a", "match_flags" => "smi"})),
      v("c/regex-flags-filtered", "match_flags outside i/m/s are dropped, duplicates collapse",
        disc(%{"kind" => "string"}, %{"match" => "^a", "match_flags" => "iixg"})),
      v("c/regex-flags-without-match", "match_flags without match render nothing",
        disc(%{"kind" => "string"}, %{"match_flags" => "i"})),
      v("c/regex-pcre-lookbehind", "PCRE-only lookbehind pattern is DROPPED (no .regex emitted)",
        disc(%{"kind" => "string"}, %{"match" => "(?<=a)b"})),
      v("c/regex-pcre-possessive", "PCRE possessive quantifier is dropped",
        disc(%{"kind" => "string"}, %{"match" => "a++b"})),
      v("c/regex-pcre-atomic", "PCRE atomic group is dropped",
        disc(%{"kind" => "string"}, %{"match" => "(?>a)b"})),
      v("c/regex-pcre-anchor-A", "PCRE \\A anchor is dropped",
        disc(%{"kind" => "string"}, %{"match" => "\\Aabc"})),
      v("c/regex-pcre-unicode-prop", "PCRE \\p{..} property is dropped",
        disc(%{"kind" => "string"}, %{"match" => "\\p{L}+"})),
      v("c/regex-dollar-multiline", "with flag m a trailing $ is kept as-is",
        disc(%{"kind" => "string"}, %{"match" => "^a$", "match_flags" => "m"})),
      v("c/regex-dollar-in-class", "$ inside a character class is literal and untouched",
        disc(%{"kind" => "string"}, %{"match" => "[$]a"})),
      v("c/regex-escaped-dollar", "an escaped \\$ is untouched",
        disc(%{"kind" => "string"}, %{"match" => "a\\$"})),
      v("c/regex-posix-class-dropped", "a POSIX [[:class:]] is PCRE-only and dropped",
        disc(%{"kind" => "string"}, %{"match" => "[[:alpha:]]+"})),
      v("c/regex-named-group-kept", "a named group (?<n>..) is JS-valid and kept",
        disc(%{"kind" => "string"}, %{"match" => "(?<year>\\d{4})"})),
      v("c/regex-lazy-kept", "a lazy quantifier is kept",
        disc(%{"kind" => "string"}, %{"match" => "a+?b"})),
      v("c/regex-empty-dropped", "an empty pattern is dropped",
        disc(%{"kind" => "string"}, %{"match" => ""})),
      v("c/regex-unbalanced-open-dropped", "an unclosed group is dropped",
        disc(%{"kind" => "string"}, %{"match" => "(a"})),
      v("c/regex-unbalanced-close-dropped", "an unmatched ) is dropped",
        disc(%{"kind" => "string"}, %{"match" => "a)"})),
      v("c/regex-nothing-to-repeat-dropped", "a leading quantifier is dropped",
        disc(%{"kind" => "string"}, %{"match" => "*a"})),
      v("c/regex-raw-newline-dropped", "a raw line terminator in the source is dropped",
        disc(%{"kind" => "string"}, %{"match" => "a\nb"})),
      v("c/regex-pcre-z-escape-dropped", "PCRE \\z is dropped",
        disc(%{"kind" => "string"}, %{"match" => "a\\z"})),
      v("c/regex-unterminated-class-dropped", "an unterminated class is dropped",
        disc(%{"kind" => "string"}, %{"match" => "[abc"})),
      v("c/regex-js-safe-lookahead", "a JS-safe lookahead is kept",
        disc(%{"kind" => "string"}, %{"match" => "a(?=b)"})),
      v("c/regex-escaped-slash-preserved", "an already-escaped slash is not double-escaped",
        disc(%{"kind" => "string"}, %{"match" => "a\\/b"})),
      v("c/regex-slash-after-backslash-pair", "slash after an escaped backslash IS escaped",
        disc(%{"kind" => "string"}, %{"match" => "a\\\\/b"})),
      v("c/optional-flag", "optional: true renders .optional()",
        %{"actions" => [%{"id" => "Conformance.Resource#act", "arguments" => [%{"name" => "value", "type" => %{"kind" => "string"}, "optional" => true}]}]}),
      v("c/required-false", "required?: false renders .optional()",
        %{"actions" => [%{"id" => "Conformance.Resource#act", "arguments" => [%{"name" => "value", "type" => %{"kind" => "string"}, "required?" => false}]}]}),
      v("c/default-key", "a default key renders .optional()",
        %{"actions" => [%{"id" => "Conformance.Resource#act", "arguments" => [%{"name" => "value", "type" => %{"kind" => "integer"}, "default" => 5}]}]}),
      v("c/has-default", "has_default: true renders .optional()",
        %{"actions" => [%{"id" => "Conformance.Resource#act", "arguments" => [%{"name" => "value", "type" => %{"kind" => "integer"}, "has_default" => true}]}]}),
      v("c/nullable-then-optional", "allow_nil? plus default renders .nullable().optional()",
        %{"actions" => [%{"id" => "Conformance.Resource#act", "arguments" => [%{"name" => "value", "type" => %{"kind" => "string"}, "allow_nil?" => true, "default" => "x"}]}]}),
      v("c/allow-nil-alias", "allow_nil (no ?) renders .nullable()",
        %{"actions" => [%{"id" => "Conformance.Resource#act", "arguments" => [%{"name" => "value", "type" => %{"kind" => "string"}, "allow_nil" => true}]}]}),
      v("c/ci-string-length", "ci_string takes string length and regex constraints",
        disc(%{"kind" => "ci_string"}, %{"min_length" => 2, "max_length" => 8, "match" => "^[a-z]+$"})),
      v("c/binary-length", "binary takes length constraints",
        disc(%{"kind" => "binary"}, %{"max_length" => 16})),
      v("c/float-integral-min", "integral float min renders in canonical JS spelling (1, not 1.0)",
        disc(%{"kind" => "float"}, %{"min" => 1.0})),
      v("c/float-exponent-max", "large float max renders in canonical JS spelling (100000000000000000000)",
        disc(%{"kind" => "float"}, %{"max" => 1.0e20})),
      v("c/float-exponent-21", "1e21 renders 1e+21", disc(%{"kind" => "float"}, %{"max" => 1.0e21})),
      v("c/float-negative-zero", "-0.0 renders 0", disc(%{"kind" => "float"}, %{"min" => -0.0})),
      v("c/float-small-exponent", "1.0e-7 renders 1e-7", disc(%{"kind" => "float"}, %{"min" => 1.0e-7})),
      v("c/float-fraction-max", "ordinary fractional float renders identically in both languages",
        disc(%{"kind" => "float"}, %{"max" => 2.5})),
      v("c/kind-uuid-v7", "uuid_v7 renders z.uuid()", disc(%{"kind" => "uuid_v7"}, %{})),
      v("c/kind-time-usec", "time_usec renders z.iso.time()", disc(%{"kind" => "time_usec"}, %{})),
      v("c/kind-duration-name", "duration_name renders z.string()", disc(%{"kind" => "duration_name"}, %{})),
      v("c/kind-url-encoded-binary", "url_encoded_binary renders z.string()", disc(%{"kind" => "url_encoded_binary"}, %{})),
      v("c/kind-module", "module renders z.string()", disc(%{"kind" => "module"}, %{})),
      v("c/kind-file", "file renders z.any()", disc(%{"kind" => "file"}, %{})),
      v("c/kind-function", "function renders z.any()", disc(%{"kind" => "function"}, %{})),
      v("c/kind-any", "any renders z.any()", disc(%{"kind" => "any"}, %{})),
      v("c/kind-keyword", "keyword renders a string-keyed record", disc(%{"kind" => "keyword"}, %{})),
      v("c/kind-tuple", "tuple renders a string-keyed record", disc(%{"kind" => "tuple"}, %{})),
      v("c/kind-struct", "struct renders a string-keyed record", disc(%{"kind" => "struct"}, %{})),
      v("c/kind-unmapped", "an unmapped kind falls back to z.unknown() (not z.unknown().optional())",
        disc(%{"kind" => "no_such_kind"}, %{})),
      v("c/no-type-fallback", "a definition with neither type nor subtype_of renders z.unknown()",
        %{"actions" => [%{"id" => "Conformance.Resource#act", "arguments" => [%{"name" => "value"}]}]}),
      v("c/enum-values", "enum kind renders a sorted z.enum of its values",
        disc(%{"kind" => "enum", "values" => ["pear", "apple", "fig"]}, %{})),
      v("c/enum-values-empty", "enum kind with no values renders z.string()",
        disc(%{"kind" => "enum", "values" => []}, %{})),
      v("c/enum-values-dedup", "enum values are de-duplicated and sorted",
        disc(%{"kind" => "enum", "values" => ["b", "a", "b"]}, %{})),
      v("c/one-of-numeric-dedup", "numeric one_of de-duplicates and sorts into a literal union",
        disc(%{"kind" => "integer"}, %{"one_of" => [3, 1, 3, 2]})),
      v("c/one-of-single-numeric", "single numeric one_of renders one literal",
        disc(%{"kind" => "integer"}, %{"one_of" => [7]})),
      v("c/full-chain", "one_of + min_length + max_length + match compose in frozen order",
        disc(%{"kind" => "string"}, %{
          "match" => "^[a-z]+$",
          "max_length" => 10,
          "min_length" => 1,
          "one_of" => ["alpha", "beta", "gamma"]
        })),
      v("c/allow-nil", "constraints compose before .optional().nullable()",
        disc(%{"kind" => "string", "allow_nil?" => true}, %{"min_length" => 2})),
      v("c/baseline-unconstrained", "no constraints leaves the fragment byte-identical to unconstrained",
        disc(%{"kind" => "string"}, %{})),
      v("c/newtype-subtype-constraints", "NewType subtype_of + subtype_constraints ride the same chain",
        %{
          "actions" => [
            %{
              "id" => "Conformance.Resource#act",
              "arguments" => [
                %{
                  "name" => "value",
                  "subtype_of" => "string",
                  "subtype_constraints" => %{"one_of" => ["a", "b"], "min_length" => 1}
                }
              ]
            }
          ]
        }),
      v("c/quoted-key", "non-identifier argument name emits a quoted object key",
        %{
          "actions" => [
            %{
              "id" => "Conformance.Resource#act",
              "arguments" => [
                %{"name" => "default?", "type" => %{"kind" => "boolean"}}
              ]
            }
          ]
        }),
      v("c/multi-argument", "arguments render in discovery order",
        %{
          "actions" => [
            %{
              "id" => "Conformance.Resource#act",
              "arguments" => [
                %{"name" => "zulu", "type" => %{"kind" => "string"}, "constraints" => %{"min_length" => 1}},
                %{"name" => "alpha", "type" => %{"kind" => "integer"}, "constraints" => %{"min" => 0}}
              ]
            }
          ]
        }),
      # error shapes (reuse of the section's typed refusals)
      v("c/error-action-without-id", "action without id is a typed refusal",
        %{"actions" => [%{"arguments" => []}]}),
      v("c/error-arguments-not-a-list", "arguments not a list is a typed refusal",
        %{"actions" => [%{"id" => "R#a", "arguments" => %{"name" => "x"}}]})
    ]
  end

  defp disc(type, constraints) do
    arg =
      %{"name" => "value", "type" => type}
      |> Map.put("constraints", constraints)

    %{
      "actions" => [
        %{
          "id" => "Conformance.Resource#act",
          "arguments" => [arg]
        }
      ]
    }
  end

  # -- w3-04 schema-renderer kinds ------------------------------------------------------
  #
  # Inputs are authored; `expected` = {zod expression(s), probe verdicts} minted by
  # Runner.run/2 (real renderer + real zod execution via node). Probes are authored
  # values; verdicts are never typed by hand.

  defp p(value), do: %{"value" => value}
  defp pt(target, value), do: %{"target" => target, "value" => value}

  defp fin(name, kind, extra \\ %{}),
    do: Map.merge(%{"name" => name, "type" => %{"kind" => kind}}, extra)

  defp filter_operators do
    f = fn id, desc, inputs, opts, probes ->
      v("fo/" <> id, desc, %{"inputs" => inputs, "opts" => opts, "probes" => probes})
    end

    str = [fin("title", "string")]
    int = [fin("age", "integer")]

    [
      f.("string-eq", "string field admits eq/contains/in; rejects numeric value and unknown op",
        str, %{"max_depth" => 0},
        [p(%{"field" => "title", "op" => "eq", "value" => "a"}),
         p(%{"field" => "title", "op" => "contains", "value" => "a"}),
         p(%{"field" => "title", "op" => "in", "value" => ["a", "b"]}),
         p(%{"field" => "title", "op" => "eq", "value" => 1}),
         p(%{"field" => "title", "op" => "gt", "value" => "a"}),
         p(%{"field" => "other", "op" => "eq", "value" => "a"})]),
      f.("integer-ordered", "integer field admits gt/lte, rejects contains",
        int, %{"max_depth" => 0},
        [p(%{"field" => "age", "op" => "gt", "value" => 3}),
         p(%{"field" => "age", "op" => "lte", "value" => 3}),
         p(%{"field" => "age", "op" => "contains", "value" => 3}),
         p(%{"field" => "age", "op" => "eq", "value" => "3"})]),
      f.("boolean-ops", "boolean field admits eq/neq/in only",
        [fin("done", "boolean")], %{"max_depth" => 0},
        [p(%{"field" => "done", "op" => "eq", "value" => true}),
         p(%{"field" => "done", "op" => "in", "value" => [true, false]}),
         p(%{"field" => "done", "op" => "gt", "value" => true})]),
      f.("uuid-ops", "uuid field admits eq/neq/in with uuid values",
        [fin("id", "uuid")], %{"max_depth" => 0},
        [p(%{"field" => "id", "op" => "eq", "value" => "123e4567-e89b-42d3-a456-426614174000"}),
         p(%{"field" => "id", "op" => "eq", "value" => "not-a-uuid"}),
         p(%{"field" => "id", "op" => "gt", "value" => "123e4567-e89b-42d3-a456-426614174000"})]),
      f.("ci-string-ordered", "ci_string adds ordered operators to the string set",
        [fin("handle", "ci_string")], %{"max_depth" => 0},
        [p(%{"field" => "handle", "op" => "gte", "value" => "a"}),
         p(%{"field" => "handle", "op" => "starts_with", "value" => "a"})]),
      f.("date-ordered", "date-like kinds admit ordered operators over iso values",
        [fin("due", "date")], %{"max_depth" => 0},
        [p(%{"field" => "due", "op" => "lt", "value" => "2026-01-02"}),
         p(%{"field" => "due", "op" => "lt", "value" => "tomorrow"})]),
      f.("datetime-in", "utc_datetime in takes an array of iso datetimes",
        [fin("at", "utc_datetime")], %{"max_depth" => 0},
        [p(%{"field" => "at", "op" => "in", "value" => ["2026-01-02T03:04:05Z"]}),
         p(%{"field" => "at", "op" => "in", "value" => "2026-01-02T03:04:05Z"})]),
      f.("atom-kind", "atom kind admits the ordered set over strings",
        [fin("state", "atom")], %{"max_depth" => 0},
        [p(%{"field" => "state", "op" => "eq", "value" => "open"}),
         p(%{"field" => "state", "op" => "eq", "value" => 1})]),
      f.("array-has", "array field admits has (element) and has_any (array of elements)",
        [fin("tags", "array", %{"items" => %{"kind" => "string"}})], %{"max_depth" => 0},
        [p(%{"field" => "tags", "op" => "has", "value" => "x"}),
         p(%{"field" => "tags", "op" => "has_any", "value" => ["x", "y"]}),
         p(%{"field" => "tags", "op" => "has", "value" => 7}),
         p(%{"field" => "tags", "op" => "eq", "value" => "x"})]),
      f.("array-has-no-items", "array without item type uses z.unknown() elements",
        [fin("tags", "array")], %{"max_depth" => 0},
        [p(%{"field" => "tags", "op" => "has", "value" => 7})]),
      f.("unknown-kind", "an unknown kind falls back to eq/neq/in over z.unknown()",
        [fin("blob", "no_such_kind")], %{"max_depth" => 0},
        [p(%{"field" => "blob", "op" => "eq", "value" => %{"a" => 1}}),
         p(%{"field" => "blob", "op" => "gt", "value" => 1})]),
      f.("nullable-is-nil", "allow_nil? adds is_nil with a boolean value",
        [fin("note", "string", %{"allow_nil?" => true})], %{"max_depth" => 0},
        [p(%{"field" => "note", "op" => "is_nil", "value" => true}),
         p(%{"field" => "note", "op" => "is_nil", "value" => "yes"})]),
      f.("not-nullable-no-is-nil", "a non-nullable field has no is_nil operator",
        str, %{"max_depth" => 0},
        [p(%{"field" => "title", "op" => "is_nil", "value" => true})]),
      f.("explicit-operators", "an explicit operators list replaces the catalog default",
        [fin("title", "string", %{"operators" => ["eq"]})], %{"max_depth" => 0},
        [p(%{"field" => "title", "op" => "eq", "value" => "a"}),
         p(%{"field" => "title", "op" => "contains", "value" => "a"})]),
      f.("ash-operator-names", "Ash operator spellings map to catalog keys (== -> eq, <= -> lte)",
        [fin("age", "integer", %{"operators" => ["==", "<="]})], %{"max_depth" => 0},
        [p(%{"field" => "age", "op" => "eq", "value" => 1}),
         p(%{"field" => "age", "op" => "lte", "value" => 1}),
         p(%{"field" => "age", "op" => "gt", "value" => 1})]),
      f.("filterable-false", "filterable: false removes the field (and leaves the next one)",
        [fin("secret", "string", %{"filterable" => false}), fin("title", "string")], %{"max_depth" => 0},
        [p(%{"field" => "secret", "op" => "eq", "value" => "a"}),
         p(%{"field" => "title", "op" => "eq", "value" => "a"})]),
      f.("only-unfilterable", "no filterable field is a typed error",
        [fin("secret", "string", %{"filterable" => false})], %{"max_depth" => 0}, []),
      f.("depth-1-and-or-not", "depth 1 nests and/or/not around leaf filters",
        str, %{"max_depth" => 1},
        [p(%{"op" => "and", "value" => [%{"field" => "title", "op" => "eq", "value" => "a"}]}),
         p(%{"op" => "or", "value" => [%{"field" => "title", "op" => "eq", "value" => "a"}, %{"field" => "title", "op" => "neq", "value" => "b"}]}),
         p(%{"op" => "not", "value" => %{"field" => "title", "op" => "eq", "value" => "a"}}),
         p(%{"op" => "not", "value" => [%{"field" => "title", "op" => "eq", "value" => "a"}]}),
         p(%{"op" => "and", "value" => [%{"op" => "and", "value" => [%{"field" => "title", "op" => "eq", "value" => "a"}]}]})]),
      f.("depth-0-no-connectives", "depth 0 admits leaves only",
        str, %{"max_depth" => 0},
        [p(%{"op" => "and", "value" => [%{"field" => "title", "op" => "eq", "value" => "a"}]})]),
      f.("connectives-subset", "a connectives subset renders only those wrappers",
        str, %{"max_depth" => 1, "connectives" => ["not"]},
        [p(%{"op" => "not", "value" => %{"field" => "title", "op" => "eq", "value" => "a"}}),
         p(%{"op" => "and", "value" => [%{"field" => "title", "op" => "eq", "value" => "a"}]})]),
      f.("invalid-max-depth", "max_depth beyond the cap is a typed error",
        str, %{"max_depth" => 4}, []),
      f.("unknown-connectives", "an unknown connective is a typed error",
        str, %{"connectives" => ["xor"]}, []),
      f.("relationship-related", "a relationship input renders op related over the destination filter",
        [fin("title", "string"),
         %{"name" => "author", "type" => %{"kind" => "uuid"},
           "relationship" => %{"filter_inputs" => [fin("name", "string")]}}], %{"max_depth" => 0},
        [p(%{"field" => "author", "op" => "related", "value" => %{"field" => "name", "op" => "eq", "value" => "n"}}),
         p(%{"field" => "author", "op" => "related", "value" => %{"field" => "name", "op" => "eq", "value" => 1}})]),
      f.("missing-name", "an input without a name is a typed error",
        [%{"type" => %{"kind" => "string"}}], %{}, []),
      f.("missing-type", "an input without a type is a typed error",
        [%{"name" => "x"}], %{}, []),
      f.("not-a-list", "inputs that are not a list are a typed error", %{"name" => "x"}, %{}, [])
    ]
  end

  defp query_envelope do
    q = fn id, desc, render, args, probes ->
      v("qe/" <> id, desc, %{"render" => render, "args" => args, "probes" => probes})
    end

    rec = "z.object({id: z.string()}).strict()"

    [
      q.("sort-plus-minus", "sort admits +/- prefixes over admitted fields, comma separated",
        "sort", %{"fields" => ["name", "age"]},
        [p("name"), p("+name"), p("-age"), p("name,-age"), p("+name,-age,age"), p("secret"), p(""), p("name,"), p("-+name")]),
      q.("sort-double-prefix", "sort admits ++ and -- (ash_typescript sort modes)",
        "sort", %{"fields" => ["name", "age"]},
        [p("++name"), p("--age"), p("++name,--age,-name"), p("+++name"), p("---name")]),
      q.("sort-array-form", "array?: true admits a string or an array of strings",
        "sort", %{"fields" => ["name"], "array?" => true},
        [p("-name"), p(["name", "--name"]), p(["secret"]), p([]), p(1)]),
      q.("sort-empty-field-list", "an empty field list is refused by the renderer",
        "sort", %{"fields" => [], "array?" => false}, []),
      q.("sort-non-identifier", "a non-identifier field name is refused, never escaped",
        "sort", %{"fields" => ["na me"]}, []),
      q.("pagination-offset", "offset pagination: limit bounded, offset non-negative, strict",
        "pagination", %{"offset?" => true, "required?" => true},
        [p(%{"limit" => 10}), p(%{"limit" => 10, "offset" => 0}), p(%{"limit" => 0}), p(%{"limit" => 501}), p(%{"limit" => 10, "offset" => -1}), p(%{"limit" => 10, "after" => "x"}), p(%{})]),
      q.("pagination-keyset", "keyset pagination: after/before strings",
        "pagination", %{"keyset?" => true, "required?" => true},
        [p(%{"limit" => 5, "after" => "c"}), p(%{"limit" => 5, "before" => "c"}), p(%{"limit" => 5, "offset" => 1})]),
      q.("pagination-mixed", "offset and keyset together render a two-arm union",
        "pagination", %{"offset?" => true, "keyset?" => true, "required?" => true},
        [p(%{"limit" => 5, "offset" => 1}), p(%{"limit" => 5, "after" => "c"}), p(%{"limit" => 5, "offset" => 1, "after" => "c"})]),
      q.("pagination-optional", "not required?: the whole envelope is optional",
        "pagination", %{"offset?" => true},
        [p(nil), p(%{"limit" => 5})]),
      q.("pagination-countable", "countable? adds count: boolean",
        "pagination", %{"offset?" => true, "keyset?" => false, "required?" => true, "countable?" => true},
        [p(%{"limit" => 5, "count" => true}), p(%{"limit" => 5, "count" => "yes"})]),
      q.("pagination-max-limit", "a caller max_limit replaces the fallback bound",
        "pagination", %{"offset?" => true, "required?" => true, "max_limit" => 25},
        [p(%{"limit" => 25}), p(%{"limit" => 26})]),
      q.("pagination-default-limit", "required + default_limit? makes limit optional",
        "pagination", %{"offset?" => true, "required?" => true, "default_limit?" => true},
        [p(%{}), p(%{"limit" => 5})]),
      q.("pagination-unsupported", "neither offset nor keyset is a typed error",
        "pagination", %{"required?" => true}, []),
      q.("params-read", "read params: sort (array form) and page, targets probed separately",
        "query_params", %{"read?" => true, "enable_sort?" => true, "sortable_fields" => ["name", "age"], "pagination" => %{"offset?" => true, "required?" => true}},
        [pt("sort", "name"), pt("sort", ["name", "-age"]), pt("sort", "secret"), pt("page", %{"limit" => 3}), pt("page", %{"limit" => 0})]),
      q.("params-get-action", "a get action yields neither sort nor page",
        "query_params", %{"read?" => true, "get?" => true, "enable_sort?" => true, "sortable_fields" => ["name"], "pagination" => %{"offset?" => true}}, []),
      q.("params-sort-disabled", "enable_sort? false yields no sort",
        "query_params", %{"read?" => true, "enable_sort?" => false, "sortable_fields" => ["name"]}, []),
      q.("offset-result", "offset page result envelope", "offset_result", %{"record" => rec},
        [p(%{"results" => [%{"id" => "a"}], "hasMore" => false, "limit" => 5, "offset" => 0, "type" => "offset"}),
         p(%{"results" => [%{"id" => "a"}], "hasMore" => false, "limit" => 5, "offset" => 0, "type" => "keyset"}),
         p(%{"results" => [%{"id" => 1}], "hasMore" => false, "limit" => 5, "offset" => 0, "type" => "offset"}),
         p(%{"results" => [], "hasMore" => true, "limit" => 5, "offset" => 5, "count" => nil, "type" => "offset"})]),
      q.("keyset-result", "keyset page result envelope", "keyset_result", %{"record" => rec},
        [p(%{"results" => [], "hasMore" => false, "limit" => 5, "after" => nil, "before" => nil, "previousPage" => "", "nextPage" => "", "type" => "keyset"}),
         p(%{"results" => [], "hasMore" => false, "limit" => 5, "type" => "keyset"})]),
      q.("page-result-optional", "not required?: a bare array OR a page is admitted",
        "page_result", %{"record" => rec, "offset?" => true},
        [p([%{"id" => "a"}]), p(%{"results" => [], "hasMore" => false, "limit" => 5, "offset" => 0, "type" => "offset"}), p("x")]),
      q.("page-result-mixed-required", "mixed required: only the two page arms",
        "page_result", %{"record" => rec, "offset?" => true, "keyset?" => true, "required?" => true},
        [p([%{"id" => "a"}]), p(%{"results" => [], "hasMore" => false, "limit" => 5, "offset" => 0, "type" => "offset"})]),
      q.("page-result-unsupported", "page result with neither flag is a typed error",
        "page_result", %{"record" => rec}, []),
      q.("typed-input", "typed input envelope: parts optional unless required",
        "typed_input", %{"parts" => %{"input" => "z.object({a: z.string()}).strict()", "page" => "z.object({limit: z.number().int()}).strict()"}, "required" => ["input"]},
        [p(%{"input" => %{"a" => "x"}}), p(%{}), p(%{"input" => %{"a" => "x"}, "page" => %{"limit" => 3}}), p(%{"input" => %{"a" => "x"}, "extra" => 1})]),
      q.("get-input-sorted", "get input is a sorted strict object of required keys",
        "get_input", %{"keys" => [["org_id", "z.uuid()"], ["id", "z.uuid()"]]},
        [p(%{"id" => "123e4567-e89b-42d3-a456-426614174000", "org_id" => "123e4567-e89b-42d3-a456-426614174000"}), p(%{"id" => "123e4567-e89b-42d3-a456-426614174000"})]),
      q.("get-input-bad-key", "a non-identifier key is a typed error",
        "get_input", %{"keys" => [["bad key", "z.string()"]]}, []),
      q.("get-result-nullable", "nullable? renders .nullable()", "get_result", %{"record" => rec, "nullable?" => true},
        [p(nil), p(%{"id" => "a"})]),
      q.("get-result-required", "non-nullable get result rejects null", "get_result", %{"record" => rec},
        [p(nil), p(%{"id" => "a"})])
    ]
  end

  defp selection_admission do
    s = fn id, desc, admitted, denied, opts, probes ->
      v("sa/" <> id, desc, %{"admitted" => admitted, "denied" => denied, "opts" => opts, "probes" => probes})
    end

    comments = %{"name" => "comments", "destination" => "Comment", "cardinality" => "many", "primitive_fields" => ["id", "body"],
                 "relationships" => [%{"name" => "likes", "destination" => "Like", "cardinality" => "many", "primitive_fields" => ["id"]}]}

    [
      s.("fields-enum", "selection is a strict object over an enum of admitted fields",
        ["id", "title", "body"], [], %{},
        [p(%{"fields" => ["id", "title"]}), p(%{"fields" => []}), p(%{"fields" => ["secret"]}), p(%{"fields" => ["id"], "extra" => 1}), p(%{})]),
      s.("denied-subtracted", "denied fields are removed from the admitted set",
        ["id", "title", "secret"], ["secret"], %{},
        [p(%{"fields" => ["title"]}), p(%{"fields" => ["secret"]})]),
      s.("all-denied-never", "a denial that empties the set renders z.array(z.never())",
        ["a"], ["a"], %{},
        [p(%{"fields" => []}), p(%{"fields" => ["a"]})]),
      s.("empty-admitted", "an empty admitted set renders z.array(z.never())", [], [], %{},
        [p(%{"fields" => []}), p(%{"fields" => ["a"]})]),
      s.("duplicates-collapse", "duplicate admitted fields collapse", ["a", "a", "b"], [], %{},
        [p(%{"fields" => ["a", "b"]})]),
      s.("non-identifier-names", "non-identifier field names are JSON-escaped literals",
        ["na me", "q\"uote"], [], %{},
        [p(%{"fields" => ["na me"]}), p(%{"fields" => ["q\"uote"]}), p(%{"fields" => ["name"]})]),
      s.("non-binary-field", "a non-binary admitted field is a typed error", ["a", 1], [], %{}, []),
      s.("non-binary-denied", "a non-binary denied field is a typed error", ["a"], [1], %{}, []),
      s.("relationship-load", "relationships nest as a load key",
        ["id"], [], %{"relationships" => [comments]},
        [p(%{"fields" => ["id"], "load" => %{"comments" => %{"fields" => ["id"]}}}),
         p(%{"fields" => ["id"], "load" => %{"nope" => %{"fields" => ["id"]}}}),
         p(%{"fields" => ["id"]})]),
      s.("denied-loads-prefix", "denying a path removes it and its subtree",
        ["id"], [], %{"relationships" => [comments], "denied_loads" => ["comments.likes"]},
        [p(%{"fields" => ["id"], "load" => %{"comments" => %{"fields" => ["id"]}}}),
         p(%{"fields" => ["id"], "load" => %{"comments" => %{"fields" => ["id"], "load" => %{"likes" => %{"fields" => ["id"]}}}}})]),
      s.("denied-loads-root", "denying a root relationship removes its subtree entirely",
        ["id"], [], %{"relationships" => [comments], "denied_loads" => ["comments"]},
        [p(%{"fields" => ["id"], "load" => %{"comments" => %{"fields" => ["id"]}}}),
         p(%{"fields" => ["id"]})]),
      s.("allowed-loads", "allow-listing keeps listed paths, ancestors and subtrees",
        ["id"], [], %{"relationships" => [comments], "allowed_loads" => ["comments.likes"]},
        [p(%{"fields" => ["id"], "load" => %{"comments" => %{"fields" => ["id"], "load" => %{"likes" => %{"fields" => ["id"]}}}}})]),
      s.("calculations-nested", "calculation facts nest as calculations",
        ["id"], [], %{"calculations" => [%{"name" => "full_name", "arguments" => [], "return_kind" => "string"}]},
        [p(%{"fields" => ["id"], "calculations" => %{"full_name" => %{}}}),
         p(%{"fields" => ["id"], "calculations" => %{"nope" => %{}}})]),
      s.("aggregates-names", "aggregate names render as an enum array",
        ["id"], [], %{"aggregates" => [%{"name" => "comment_count", "kind" => "count"}]},
        [p(%{"fields" => ["id"], "aggregates" => ["comment_count"]}),
         p(%{"fields" => ["id"], "aggregates" => ["nope"]})])
    ]
  end

  defp relationship_loads do
    r = fn id, desc, rels, depth, probes ->
      v("rl/" <> id, desc, %{"relationships" => rels, "max_depth" => depth, "probes" => probes})
    end

    one = %{"name" => "author", "destination" => "User", "cardinality" => "one", "primitive_fields" => ["id", "name"]}
    many = %{"name" => "comments", "destination" => "Comment", "cardinality" => "many", "primitive_fields" => ["id", "body"]}

    [
      r.("one-fields", "cardinality one: fields enum plus optional load; fields .min(1)",
        [one], 1,
        [p(%{"author" => %{"fields" => ["id"]}}), p(%{"author" => %{"fields" => []}}), p(%{"author" => %{"fields" => ["secret"]}}), p(%{"author" => true}), p(%{"nope" => true}), p(nil), p(%{})]),
      r.("many-envelope", "cardinality many: filter/sort/limit/offset arm and page arm are exclusive",
        [many], 1,
        [p(%{"comments" => %{"fields" => ["id"], "limit" => 5, "offset" => 0}}),
         p(%{"comments" => %{"fields" => ["id"], "page" => %{"limit" => 5}}}),
         p(%{"comments" => %{"fields" => ["id"], "limit" => 5, "page" => %{"limit" => 5}}}),
         p(%{"comments" => %{"fields" => ["id"], "limit" => 0}}),
         p(%{"comments" => %{"fields" => ["id"], "sort" => ["-id"]}}),
         p(%{"comments" => %{"fields" => ["id"], "sort" => "id", "count" => true}})]),
      r.("pagination-offset", "pagination: offset renders only the limit/offset arm",
        [Map.put(many, "pagination", "offset")], 1,
        [p(%{"comments" => %{"fields" => ["id"], "limit" => 5}}), p(%{"comments" => %{"fields" => ["id"], "page" => %{"limit" => 5}}})]),
      r.("pagination-none", "pagination: none drops the pagination members",
        [Map.put(many, "pagination", "none")], 1,
        [p(%{"comments" => %{"fields" => ["id"]}}), p(%{"comments" => %{"fields" => ["id"], "limit" => 5}})]),
      r.("filterable-sortable-false", "filterable/sortable false omit filter/sort",
        [Map.merge(many, %{"filterable" => false, "sortable" => false})], 1,
        [p(%{"comments" => %{"fields" => ["id"], "filter" => %{}}}), p(%{"comments" => %{"fields" => ["id"], "sort" => "id"}}), p(%{"comments" => %{"fields" => ["id"]}})]),
      r.("exposed-false", "exposed: false omits the relationship from load keys",
        [Map.put(one, "exposed", false), many], 1,
        [p(%{"author" => true}), p(%{"comments" => true})]),
      r.("nested-depth-2", "nested relationships expand to max_depth",
        [Map.put(many, "relationships", [one])], 2,
        [p(%{"comments" => %{"fields" => ["id"], "load" => %{"author" => %{"fields" => ["id"]}}}}),
         p(%{"comments" => %{"fields" => ["id"], "load" => %{"author" => %{"fields" => ["id"], "load" => %{"x" => true}}}}})]),
      r.("depth-0", "max_depth 0 admits no nested load",
        [Map.put(many, "relationships", [one])], 0,
        [p(%{"comments" => %{"fields" => ["id"], "load" => %{"author" => %{"fields" => ["id"]}}}}),
         p(%{"comments" => %{"fields" => ["id"]}})]),
      r.("literal-true-shorthand", "the literal true shorthand loads everything by default",
        [one], 1, [p(%{"author" => true}), p(%{"author" => false})]),
      r.("invalid-pagination", "an unknown pagination fact is a typed error",
        [Map.put(many, "pagination", "weird")], 1, []),
      r.("not-a-list", "relationships that are not a list are a typed error", %{"name" => "x"}, 1, [])
    ]
  end

  defp calculation_envelope do
    c = fn id, desc, render, facts, probes ->
      v("ce/" <> id, desc, %{"render" => render, "facts" => facts, "probes" => probes})
    end

    full = %{"name" => "full_name", "arguments" => [%{"name" => "prefix", "kind" => "string", "constraints" => %{"min_length" => 1}}], "return_kind" => "string"}
    noargs = %{"name" => "score", "arguments" => [], "return_kind" => "integer"}

    [
      c.("calc-args", "calculation load: known name, strict args, constraints honored",
        "calculation", [full],
        [p(%{"full_name" => %{"args" => %{"prefix" => "Dr"}}}), p(%{"full_name" => %{"args" => %{"prefix" => ""}}}), p(%{"full_name" => %{"args" => %{"extra" => 1}}}), p(%{"nope" => %{}}), p(%{"full_name" => %{}})]),
      c.("calc-required-arg", "a required argument makes args required",
        "calculation", [full],
        [p(%{"full_name" => %{}}), p(%{"full_name" => %{"args" => %{"prefix" => "x"}}})]),
      c.("calc-no-args", "a zero-argument calculation validates with args omitted",
        "calculation", [noargs],
        [p(%{"score" => %{}}), p(%{"score" => %{"args" => %{}}}), p(%{"score" => %{"args" => %{"a" => 1}}})]),
      c.("calc-optional-arg", "an allow_nil argument is optional",
        "calculation", [%{"name" => "opt", "arguments" => [%{"name" => "n", "kind" => "integer", "allow_nil?" => true}], "return_kind" => "string"}],
        [p(%{"opt" => %{}}), p(%{"opt" => %{"args" => %{}}})]),
      c.("calc-multiple", "several calculations share one record over a name enum",
        "calculation", [full, noargs],
        [p(%{"full_name" => %{"args" => %{"prefix" => "x"}}, "score" => %{}}), p(%{"other" => %{}})]),
      c.("calc-empty", "an empty calculation list is a typed error", "calculation", [], []),
      c.("calc-bad-name", "a non-binary calculation name is a typed error", "calculation", [%{"name" => 1, "arguments" => [], "return_kind" => "string"}], []),
      c.("results", "result schemas: return_kind with allow_nil? nullability",
        "results", [%{"name" => "full_name", "return_kind" => "string", "allow_nil?" => true}, %{"name" => "score", "return_kind" => "integer"}],
        [pt("full_name", nil), pt("full_name", "x"), pt("score", nil), pt("score", 3), pt("score", 1.5)]),
      c.("aggregates-kinds", "aggregate result schemas: count never null, sum nullable",
        "aggregates", [%{"name" => "n", "kind" => "count"}, %{"name" => "total", "kind" => "sum", "field" => "amount"}],
        [pt("n", 3), pt("n", nil), pt("total", nil), pt("total", 3)]),
      c.("aggregates-unknown-kind", "an unknown aggregate kind is a typed error",
        "aggregates", [%{"name" => "x", "kind" => "bogus"}], [])
    ]
  end

  defp identity_get do
    i = fn id, desc, identities, pk, probes ->
      v("ig/" <> id, desc, %{"render" => "get", "identities" => identities, "primary_key" => pk, "probes" => probes})
    end

    t = fn id, desc, mt, probes ->
      v("ig/" <> id, desc, %{"render" => "tenant", "multitenancy" => mt, "probes" => probes})
    end

    email = %{"name" => "email", "keys" => [%{"name" => "email", "type" => %{"kind" => "string"}}]}
    pk = %{"name" => "by_id", "keys" => [%{"name" => "id", "type" => %{"kind" => "uuid"}}]}
    uuid = "123e4567-e89b-42d3-a456-426614174000"

    [
      i.("identity-strict", "an identity is a strict object over its key fragments",
        [email], ["id"],
        [pt("email", %{"email" => "a@b.c"}), pt("email", %{"email" => 1}), pt("email", %{"email" => "a", "extra" => 1}), pt("email", %{})]),
      i.("primary-key-alias", "an identity equal to the primary key is admitted as primary_key",
        [pk], ["id"],
        [pt("primary_key", %{"id" => uuid}), pt("primary_key", %{"id" => "nope"})]),
      i.("composite-key-order-insensitive", "primary-key aliasing is order-insensitive for composite keys",
        [%{"name" => "x", "keys" => [%{"name" => "b", "type" => %{"kind" => "string"}}, %{"name" => "a", "type" => %{"kind" => "string"}}]}], ["a", "b"],
        [pt("primary_key", %{"a" => "1", "b" => "2"}), pt("primary_key", %{"a" => "1"})]),
      i.("nullable-key", "allow_nil? on a key renders .nullable() only",
        [%{"name" => "n", "keys" => [%{"name" => "k", "type" => %{"kind" => "string"}, "allow_nil?" => true}]}], ["id"],
        [pt("n", %{"k" => nil}), pt("n", %{})]),
      i.("non-scalar-skipped", "identities with structured key kinds are skipped",
        [%{"name" => "m", "keys" => [%{"name" => "k", "type" => %{"kind" => "map"}}]}, email], ["id"],
        [pt("email", %{"email" => "a"})]),
      i.("only-non-scalar", "no admissible identity is a typed error",
        [%{"name" => "m", "keys" => [%{"name" => "k", "type" => %{"kind" => "array"}}]}], ["id"], []),
      i.("empty-identities", "an empty identity list is a typed error", [], ["id"], []),
      t.("tenant-attribute", "an attribute tenant parameter is a required non-empty string",
        %{"strategy" => "attribute", "global?" => false},
        [p("t1"), p(""), p(nil), p(1)]),
      t.("tenant-context-optional", "require_tenant_parameters: false makes the tenant optional",
        %{"strategy" => "context", "global?" => false, "require_tenant_parameters" => false},
        [p(nil), p("t1"), p("")]),
      t.("tenant-global", "a global resource has no tenant parameter",
        %{"strategy" => "attribute", "global?" => true}, []),
      t.("tenant-none", "no multitenancy strategy has no tenant parameter",
        %{"strategy" => nil}, [])
    ]
  end

  defp error_envelope do
    types = AshSurface.IR.ErrorShape.types()

    base_probe = fn type, extra ->
      p(Map.merge(%{"type" => type, "message" => "m", "shortMessage" => "s", "vars" => %{}, "fields" => [], "path" => []}, extra))
    end

    per_type =
      for t <- types do
        v("ee/variant/" <> t, "variant for #{t}: its literal type admits, any other type is refused",
          %{"render" => "variant", "type" => t,
            "probes" => [base_probe.(t, %{}), base_probe.(t, %{"details" => %{"k" => 1}}), base_probe.("not_" <> t, %{}), base_probe.(t, %{"extra" => 1})]})
      end

    [
      v("ee/types-closed-enum", "the closed error vocabulary is exactly 20 types, unknown_error the catch-all",
        %{"render" => "types", "probes" => []}),
      v("ee/normalize-known", "a known type normalizes to itself", %{"render" => "normalize", "type" => "forbidden", "probes" => []}),
      v("ee/normalize-unknown", "an unknown type normalizes to unknown_error", %{"render" => "normalize", "type" => "bogus_type", "probes" => []}),
      v("ee/normalize-non-binary", "a non-binary type normalizes to unknown_error", %{"render" => "normalize", "type" => 7, "probes" => []}),
      v("ee/union-all-types", "the error union admits every one of the 20 types",
        %{"render" => "union", "probes" => Enum.map(types, &base_probe.(&1, %{}))}),
      v("ee/union-refuses-unknown-type", "the union refuses a type outside the closed enum and structural drift",
        %{"render" => "union", "probes" => [base_probe.("bogus_type", %{}), p(%{"type" => "forbidden"}), p(%{}), p("x"), base_probe.("forbidden", %{"error_id" => "e1"})]}),
      v("ee/union-snake-case", "formatter snake_case renames keys (short_message, not shortMessage)",
        %{"render" => "union", "formatter" => "snake_case",
          "probes" => [p(%{"type" => "forbidden", "message" => "m", "short_message" => "s", "vars" => %{}, "fields" => [], "path" => []}), base_probe.("forbidden", %{})]}),
      v("ee/union-pascal-case", "formatter pascal_case renames keys (Type, ShortMessage)",
        %{"render" => "union", "formatter" => "pascal_case",
          "probes" => [p(%{"Type" => "forbidden", "Message" => "m", "ShortMessage" => "s", "Vars" => %{}, "Fields" => [], "Path" => []}), base_probe.("forbidden", %{})]}),
      v("ee/field-errors", "field errors: sorted de-duplicated fields mapping to optional message arrays",
        %{"render" => "field_errors", "fields" => ["title", "body", "title"],
          "probes" => [p(%{"title" => ["required"]}), p(%{}), p(%{"title" => "required"}), p(%{"other" => []})]}),
      v("ee/carry", "error carry: errors union plus optional fieldErrors",
        %{"render" => "carry", "fields" => ["title"],
          "probes" => [p(%{"errors" => [%{"type" => "required", "message" => "m", "shortMessage" => "s", "vars" => %{}, "fields" => ["title"], "path" => []}], "fieldErrors" => %{"title" => ["required"]}}),
                       p(%{"errors" => []}), p(%{"fieldErrors" => %{}})]})
    ] ++ per_type
  end

  defp union_schema do
    u = fn id, desc, members, opts, probes ->
      v("us/" <> id, desc, %{"render" => "members", "members" => members, "opts" => opts, "probes" => probes})
    end

    mem = fn name, type, extra -> Map.merge(%{"name" => name, "type" => type}, extra) end

    [
      u.("members-keyed", "member-keyed union: exactly one single-key strict object",
        [mem.("text", "string", %{}), mem.("count", "integer", %{})], %{},
        [p(%{"text" => "a"}), p(%{"count" => 3}), p(%{"text" => 3}), p(%{"text" => "a", "count" => 3}), p(%{}), p(%{"other" => "a"}), p("a")]),
      u.("empty-members-any", "zero members render z.any()", [], %{}, [p(1), p(nil), p(%{"a" => 1})]),
      u.("tagged-map-with-tag", "tag/tag_value adds a literal tag field (map_with_tag storage)",
        [mem.("circle", %{"kind" => "float"}, %{"tag" => "kind", "tag_value" => "circle"})], %{},
        [p(%{"circle" => 1.5, "kind" => "circle"}), p(%{"circle" => 1.5, "kind" => "square"}), p(%{"circle" => 1.5})]),
      u.("type-and-value", "storage type_and_value renders {discriminator: literal, value: frag}",
        [mem.("a", "string", %{"tag_value" => "a"}), mem.("b", "integer", %{"tag_value" => "b"})], %{"storage" => "type_and_value"},
        [p(%{"type" => "a", "value" => "x"}), p(%{"type" => "b", "value" => 2}), p(%{"type" => "b", "value" => "x"}), p(%{"type" => "c", "value" => 1}), p(%{"value" => "x"})]),
      u.("custom-discriminator", "a configurable discriminator key",
        [mem.("a", "string", %{"tag_value" => "a"})], %{"storage" => "type_and_value", "discriminator" => "kind"},
        [p(%{"kind" => "a", "value" => "x"}), p(%{"type" => "a", "value" => "x"})]),
      u.("tag-overrides-discriminator", "a member tag names the field, overriding the discriminator option",
        [mem.("a", "string", %{"tag" => "which", "tag_value" => "a"})], %{"storage" => "type_and_value", "discriminator" => "kind"},
        [p(%{"which" => "a", "value" => "x"}), p(%{"kind" => "a", "value" => "x"})]),
      u.("constrained-member", "a member definition keeps its constraint chain",
        [mem.("name", %{"type" => %{"kind" => "string"}, "constraints" => %{"min_length" => 2}}, %{})], %{},
        [p(%{"name" => "ab"}), p(%{"name" => "a"})]),
      u.("array-member", "an array member renders z.array of its items",
        [mem.("ids", %{"type" => %{"kind" => "array", "items" => %{"kind" => "uuid"}}}, %{})], %{},
        [p(%{"ids" => ["123e4567-e89b-42d3-a456-426614174000"]}), p(%{"ids" => ["x"]}), p(%{"ids" => []})]),
      u.("nested-union", "a nested union renders recursively",
        [mem.("inner", %{"type" => %{"kind" => "union", "members" => [mem.("x", "string", %{})]}}, %{})], %{},
        [p(%{"inner" => %{"x" => "a"}}), p(%{"inner" => %{"y" => "a"}})]),
      u.("quoted-names", "non-identifier member names are quoted keys",
        [mem.("my-key", "string", %{})], %{},
        [p(%{"my-key" => "a"}), p(%{"mykey" => "a"})]),
      u.("depth-exceeded", "nesting beyond max_depth is a typed error",
        [mem.("inner", %{"type" => %{"kind" => "union", "members" => [mem.("x", "string", %{})]}}, %{})], %{"max_depth" => 1}, []),
      u.("not-a-list", "members that are not a list are a typed error", %{"name" => "x"}, %{}, [])
    ]
  end

  defp transport_wire do
    w = fn id, desc, transport, fault, notes ->
      v("tw/" <> id, desc, %{"transport" => transport, "fault" => fault}, notes)
    end

    [
      w.("http/adapter-throws-after-dispatch", "an HTTP adapter that throws after dispatch is UNKNOWN_AFTER_DISPATCH with fallback closed",
        "http", "adapter_throws_after_dispatch", "The other declared transport MUST NOT be invoked."),
      w.("channel/adapter-throws-after-dispatch", "a channel adapter that throws after dispatch is UNKNOWN_AFTER_DISPATCH with fallback closed",
        "phoenix_channel", "adapter_throws_after_dispatch", "The other declared transport MUST NOT be invoked."),
      w.("http/non-2xx", "an HTTP non-2xx reply after dispatch closes fallback", "http", "http_non_2xx", "Status is not a typed refusal: the outcome is unknown."),
      w.("http/network-failure", "an HTTP network failure after dispatch closes fallback", "http", "http_network_failure", ""),
      w.("http/invalid-body", "an HTTP non-JSON body after dispatch closes fallback", "http", "http_invalid_body", ""),
      w.("channel/timeout", "a channel push timeout is UNKNOWN_AFTER_DISPATCH with fallback closed", "phoenix_channel", "channel_timeout", "A timeout is never retried or replayed over HTTP."),
      w.("channel/error-reply", "a channel error reply after push closes fallback", "phoenix_channel", "channel_error_reply", ""),
      v("tw/http/csrf-header", "the CSRF header the transport sends is the one Plug.CSRFProtection reads, and without it the request is refused",
        %{"transport" => "http", "fault" => "csrf_header"},
        "Minted against the real Plug.CSRFProtection; the JS side proves its transport sends exactly that header to a real HTTP server and none when csrf is disabled.")
    ]
  end

  # -- vector plumbing --------------------------------------------------------------

  defp v(id, description, input, notes \\ "", level \\ "MUST"),
    do: %{
      "id" => id,
      "description" => description,
      "input" => input,
      "notes" => notes,
      "level" => level
    }

  defp realize(kind, vector) do
    input = Runner.jsonify(vector["input"])
    Map.put(vector, "input", input) |> Map.put("expected", Runner.run(kind, input))
  end

  defp write_file(kind, vectors) do
    path = Path.join(@out, kind <> ".json")

    body =
      Enum.map_join(vectors, ",\n", fn vector -> "  " <> CanonicalJSON.encode(vector) end)

    header =
      ~s({"corpusVersion":#{Jason.encode!(Runner.corpus_version())},"kind":#{Jason.encode!(kind)},"vectors":[\n)

    bytes = header <> body <> "\n]}\n"
    File.write!(path, bytes)

    %{
      "path" => "vectors/" <> kind <> ".json",
      "kind" => kind,
      "levels" => vectors |> Enum.frequencies_by(& &1["level"]),
      "vectorCount" => length(vectors),
      "sha256" => :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
    }
  end

  # -- transport_selection -------------------------------------------------------------

  defp facts_scenarios do
    h = "http"
    c = "phoenix_channel"

    [
      {"none", nil},
      {"null", %{"transportFacts" => nil}},
      {"allnil", %{"transportFacts" => %{h => %{"cost" => nil}, c => %{}}}},
      {"cost-h-low", %{"transportFacts" => %{h => %{"cost" => "low"}, c => %{"cost" => "high"}}}},
      {"cost-c-low", %{"transportFacts" => %{h => %{"cost" => "high"}, c => %{"cost" => "low"}}}},
      {"cost-tie-medium",
       %{"transportFacts" => %{h => %{"cost" => "medium"}, c => %{"cost" => "medium"}}}},
      {"cost-medium-vs-low",
       %{"transportFacts" => %{h => %{"cost" => "medium"}, c => %{"cost" => "low"}}}},
      {"latency-only",
       %{"transportFacts" => %{h => %{"latency" => "high"}, c => %{"latency" => "low"}}}},
      {"conflict-cost-vs-latency",
       %{
         "transportFacts" => %{
           h => %{"cost" => "low", "latency" => "high"},
           c => %{"cost" => "high", "latency" => "low"}
         }
       }},
      {"privacy-higher-wins",
       %{"transportFacts" => %{h => %{"privacy" => "low"}, c => %{"privacy" => "high"}}}},
      {"partial-only-h", %{"transportFacts" => %{h => %{"cost" => "low"}}}},
      {"all-medium-tie",
       %{
         "transportFacts" => %{
           h => %{"cost" => "medium", "latency" => "medium", "privacy" => "medium"},
           c => %{"cost" => "medium", "latency" => "medium", "privacy" => "medium"}
         }
       }},
      {"dominance-via-privacy",
       %{
         "transportFacts" => %{
           h => %{"cost" => "medium", "latency" => "low", "privacy" => "low"},
           c => %{"cost" => "medium", "latency" => "low", "privacy" => "high"}
         }
       }}
    ]
  end

  defp ordered_sublists(declared) do
    subsets = for mask <- 0..(Integer.pow(2, length(declared)) - 1), do: subset(declared, mask)
    subsets |> Enum.flat_map(&permutations/1) |> Enum.uniq()
  end

  defp subset(list, mask),
    do:
      list
      |> Enum.with_index()
      |> Enum.filter(fn {_x, i} -> Bitwise.band(mask, Bitwise.bsl(1, i)) != 0 end)
      |> Enum.map(&elem(&1, 0))

  defp permutations([]), do: [[]]
  defp permutations(list), do: for(x <- list, rest <- permutations(list -- [x]), do: [x | rest])

  defp abbr(list), do: list |> Enum.map(&Map.fetch!(@abbr, &1)) |> Enum.join(",")

  defp transport_selection do
    declared_sets = [["http"], ["phoenix_channel"], @transports, Enum.reverse(@transports)]

    exhaustive =
      for declared <- declared_sets,
          available <- ordered_sublists(declared),
          preferred <- @transports,
          {facts_name, profile} <- facts_scenarios() do
        input =
          %{
            "actionId" => "Conformance.Resource#act",
            "declared" => declared,
            "available" => available,
            "preferred" => preferred
          }
          |> then(&if(profile, do: Map.put(&1, "profile", profile), else: &1))

        order_parametric? =
          declared == Enum.reverse(@transports) or
            Enum.filter(declared, &(&1 in available)) != available

        v(
          "ts/d=#{abbr(declared)}/a=#{abbr(available)}/p=#{@abbr[preferred]}/f=#{facts_name}",
          "exhaustive small space: declared [#{abbr(declared)}], available [#{abbr(available)}], preferred #{preferred}, facts #{facts_name}",
          input,
          "Exhaustive-table row." <>
            if(order_parametric?,
              do:
                " Order-parametric (declared order [phoenix_channel, http], or available order differing from declared): MAY, required only of projections that let a caller state those orders.",
              else: ""
            ),
          if(order_parametric?, do: "MAY", else: "MUST")
        )
      end

    both = @transports

    base = %{
      "actionId" => "Conformance.Resource#act",
      "declared" => both,
      "available" => both,
      "preferred" => "http"
    }

    edges = [
      v(
        "ts/edge/empty-available",
        "no available transport is a typed refusal",
        %{base | "available" => []},
        "kind unsupported_transport"
      ),
      v(
        "ts/edge/empty-declared-empty-available",
        "empty declared and available",
        %{base | "declared" => [], "available" => []},
        "kind unsupported_transport"
      ),
      v(
        "ts/edge/duplicate-declared",
        "duplicate declared transport is refused, never deduplicated",
        %{base | "declared" => ["http", "http"], "available" => ["http"]}
      ),
      v("ts/edge/duplicate-available", "duplicate available transport is refused", %{
        base
        | "available" => ["http", "http"]
      }),
      v("ts/edge/unknown-declared", "unknown declared transport", %{
        base
        | "declared" => ["http", "smoke_signal"],
          "available" => ["http"]
      }),
      v("ts/edge/unknown-declared-only", "single unknown declared transport", %{
        base
        | "declared" => ["smoke_signal"],
          "available" => []
      }),
      v("ts/edge/unknown-available", "unknown available transport", %{
        base
        | "available" => ["smoke_signal"]
      }),
      v("ts/edge/unadmitted-available", "available outside declared", %{
        base
        | "declared" => ["http"],
          "available" => ["http", "phoenix_channel"]
      }),
      v("ts/edge/unknown-preferred", "unknown preferred transport", %{
        base
        | "preferred" => "carrier_pigeon"
      }),
      v(
        "ts/edge/no-action-id",
        "action id is carried verbatim; absent stays null",
        Map.delete(base, "actionId"),
        "JS clients always have an action id"
      ),
      v(
        "ts/edge/unknown-dimension",
        "unknown dimension name is refused",
        Map.put(base, "profile", %{"transportFacts" => %{"http" => %{"bandwidth" => "low"}}})
      ),
      v(
        "ts/edge/unknown-class",
        "unknown dimension class is refused",
        Map.put(base, "profile", %{"transportFacts" => %{"http" => %{"cost" => "free"}}})
      ),
      v(
        "ts/edge/unknown-facts-transport",
        "facts for an unknown transport are refused",
        Map.put(base, "profile", %{"transportFacts" => %{"smoke_signal" => %{"cost" => "low"}}})
      ),
      v(
        "ts/edge/facts-not-a-map",
        "transportFacts must be a map",
        Map.put(base, "profile", %{"transportFacts" => ["http"]})
      ),
      v(
        "ts/edge/transport-facts-not-a-map",
        "per-transport facts must be a map",
        Map.put(base, "profile", %{"transportFacts" => %{"http" => "low"}})
      ),
      v(
        "ts/edge/preference-never-picks-dominated",
        "preferred phoenix_channel is dominated on cost: frontier best wins",
        Map.merge(base, %{
          "preferred" => "phoenix_channel",
          "profile" => %{
            "transportFacts" => %{
              "http" => %{"cost" => "low", "latency" => "low"},
              "phoenix_channel" => %{"cost" => "high", "latency" => "low"}
            }
          }
        })
      ),
      v(
        "ts/edge/facts-for-unavailable",
        "facts on an unavailable transport do not resurrect it",
        Map.merge(base, %{
          "declared" => both,
          "available" => ["http"],
          "profile" => %{
            "transportFacts" => %{
              "http" => %{"cost" => "high"},
              "phoenix_channel" => %{"cost" => "low"}
            }
          }
        })
      )
    ]

    exhaustive ++ edges
  end

  defp transport_facts_admission do
    [
      v("tf/absent", "absent transportFacts is not delegated (empty), never defaulted", %{
        "profile" => %{}
      }),
      v("tf/null", "null transportFacts is not delegated", %{
        "profile" => %{"transportFacts" => nil}
      }),
      v("tf/http-cost-privacy", "binary-key facts normalize", %{
        "profile" => %{"transportFacts" => %{"http" => %{"cost" => "low", "privacy" => "high"}}}
      }),
      v("tf/nil-dimension-dropped", "nil-valued dimension is dropped as not delegated", %{
        "profile" => %{"transportFacts" => %{"http" => %{"cost" => nil, "latency" => "medium"}}}
      }),
      v("tf/empty-transport", "transport with no facts", %{
        "profile" => %{"transportFacts" => %{"phoenix_channel" => %{}}}
      }),
      v("tf/unknown-class", "unknown class refused", %{
        "profile" => %{"transportFacts" => %{"http" => %{"cost" => "free"}}}
      }),
      v("tf/unknown-dimension", "unknown dimension refused", %{
        "profile" => %{"transportFacts" => %{"http" => %{"speed" => "low"}}}
      }),
      v("tf/unknown-transport", "unknown transport refused", %{
        "profile" => %{"transportFacts" => %{"smtp" => %{"cost" => "low"}}}
      }),
      v("tf/facts-not-map", "facts must be a map", %{"profile" => %{"transportFacts" => "http"}}),
      v("tf/dimensions-not-map", "dimensions must be a map", %{
        "profile" => %{"transportFacts" => %{"http" => ["cost"]}}
      }),
      v(
        "tf/profile-not-map",
        "profile must be a map",
        %{"profile" => "http"},
        "JS clients always hold a profile record; NOT_APPLICABLE there."
      ),
      v("tf/class-case-sensitive", "class names are case sensitive", %{
        "profile" => %{"transportFacts" => %{"http" => %{"cost" => "LOW"}}}
      })
    ]
  end

  # -- canonical_json ------------------------------------------------------------------

  defp canonical_json do
    cases = [
      {"key-order", "keys sort ascending", ~s({"b":1,"a":2,"c":{"z":1,"y":2}})},
      {"key-order-reversed-twin", "insertion-order twin of key-order encodes identically",
       ~s({"c":{"y":2,"z":1},"a":2,"b":1})},
      {"list-order-semantic", "list order is preserved", ~s({"l":[3,1,2,{"b":1,"a":2}]})},
      {"empty-containers", "empty map and list", ~s({"m":{},"l":[],"n":null})},
      {"scalars", "null/true/false", ~s([null,true,false])},
      {"unicode-bmp", "non-ASCII is emitted verbatim (not \\u escaped)",
       ~s({"é":"héllo ✓","σ":"Σ"})},
      {"unicode-astral", "astral characters verbatim", ~s({"k":"🜂 \u{1F702}"})},
      {"key-sort-utf8-bytes",
       "UTF-8 byte order == code point order: U+FF5E (BMP) sorts BEFORE U+1F702 (astral)",
       ~s({"\u{1F702}":1,"～":2,"z":3})},
      {"key-sort-uppercase-first",
       "byte order: uppercase before lowercase, digits before letters",
       ~s({"a":1,"B":2,"1":3,"_":4})},
      {"key-sort-prefix", "shorter key sorts before its extension", ~s({"ab":1,"a":2,"abc":3})},
      {"escapes-control", "control characters are escaped",
       ~s({"s":"a\\n\\t\\r\\b\\f\\u0001\\u001f"})},
      {"escapes-quote-backslash", "quote and backslash escape", ~s({"s":"q\\"b\\\\"})},
      {"slash-not-escaped", "solidus is not escaped", ~s({"s":"a/b</script>"})},
      {"del-and-line-separators", "DEL and U+2028/2029 emitted verbatim",
       ~s({"s":"\\u007f\\u2028\\u2029"})},
      {"ints", "integers", ~s([0,-1,1,255,256,-2147483649,2147483648])},
      {"safe-int-ceiling", "2^53-1 is portable",
       ~s({"n":9007199254740991,"m":-9007199254740991})},
      {"non-integral-floats", "floats with a fractional part and short repr",
       ~s([0.125,-0.5,1.5,3.14159])},
      {"deep-nesting", "deeply nested mixed structure", ~s({"a":[{"b":[{"c":[1,{"d":null}]}]}]})},
      {"string-numbers-not-numbers", "numeric strings stay strings", ~s({"n":"1","m":"1.0"})}
    ]

    lexical = [
      {"duplicate-keys",
       "duplicate object keys are parser-defined (RFC 8259 leaves them undefined)",
       ~s({"a":1,"a":2})},
      {"integral-float",
       "1.0 keeps its float spelling in Elixir; JSON has no int/float distinction",
       ~s({"n":1.0})},
      {"integral-float-large", "100000.0", ~s({"n":100000.0})},
      {"exponent-float", "1e21 spelling is runtime-specific", ~s({"n":1e21})},
      {"small-exponent-float", "1.0e-7 spelling is runtime-specific", ~s({"n":1.0e-7})},
      {"beyond-safe-int", "integers beyond 2^53 are exact in Elixir, lossy in IEEE-754 parsers",
       ~s({"n":9007199254740993})},
      {"negative-zero-float", "-0.0", ~s({"n":-0.0})}
    ]

    Enum.map(cases, fn {name, desc, json} -> v("cj/#{name}", desc, %{"json" => json}) end) ++
      Enum.map(lexical, fn {name, desc, json} ->
        v(
          "cj/lexical/#{name}",
          desc,
          %{"json" => json},
          "Parser- or number-model-dependent canonical bytes (int/float distinction, float spelling, integers beyond 2^53, duplicate keys). The Elixir result is recorded; a projection whose parser or number model differs must declare a known divergence rather than certify.",
          "PENDING_DECISION"
        )
      end)
  end

  # -- surface contracts -----------------------------------------------------------------

  @vm "AshSurface.Fixtures.VolunteerMilestone"
  defp read_ep, do: %{"resource" => @vm, "action" => "read", "type" => "read"}
  defp record_ep, do: %{"resource" => @vm, "action" => "record", "type" => "create"}

  defp gen_contract(name, description, generation, notes \\ "", level \\ "MUST") do
    {:ok, surface} = Runner.build_surface(generation)

    v(
      "sc/#{name}",
      description,
      %{"contract" => surface.contract, "generation" => generation},
      notes,
      level
    )
  end

  defp surface_contract_digest do
    kiosk = %{
      "consumer" => "kiosk",
      "nλ" => 1,
      "glyphs" => ["α", "ω", "✓"],
      "ratio" => 0.125,
      "ok" => true,
      "gap" => nil,
      "floor" => -2_147_483_649
    }

    delegated = %{
      "audience" => "operators",
      "actions" => %{
        "#{@vm}#record" => %{
          "consumer" => "kiosk",
          "possibleRefusals" => ["REFUSED_NO_AUTHORITY", "REFUSED_GENERATOR_OWNED"],
          "quota" => 9_007_199_254_740_991
        }
      }
    }

    facts_profile = %{
      "actions" => %{
        "#{@vm}#record" => %{
          "transport" => "auto",
          "transportFacts" => %{
            "http" => %{"cost" => "low", "latency" => "medium"},
            "phoenix_channel" => %{"cost" => "high", "privacy" => "high"}
          },
          "evidenceRequired" => true
        }
      }
    }

    {:ok, c2} =
      Runner.build_surface(%{"entrypoints" => [read_ep(), record_ep()], "profile" => delegated})

    tampered_action =
      update_in(c2.contract, ["surface", "actions"], fn [first | rest] ->
        [put_in(first, ["profile", "consumer"], "tampered") | rest]
      end)

    tampered_manifest = put_in(c2.contract, ["manifest", "extra"], "smuggled")
    reordered = update_in(c2.contract, ["surface", "actions"], &Enum.reverse/1)

    [
      gen_contract("empty-manifest-profile", "empty manifest with a profile", %{
        "entrypoints" => [],
        "profile" => %{"tier" => "gold"}
      }),
      gen_contract("empty-manifest-empty-profile", "empty manifest, empty profile", %{
        "entrypoints" => []
      }),
      gen_contract(
        "c1-read-utf8-profile",
        "read-only contract, UTF-8 profile keys and numeric boundaries",
        %{"entrypoints" => [read_ep()], "profile" => kiosk}
      ),
      gen_contract("c2-read-record-delegated", "read+record with per-action delegated profile", %{
        "entrypoints" => [read_ep(), record_ep()],
        "profile" => delegated
      }),
      gen_contract(
        "c2-entrypoint-order-twin",
        "entrypoints supplied in the other order",
        %{"entrypoints" => [record_ep(), read_ep()], "profile" => delegated},
        "Digest identity must not depend on manifest construction order."
      ),
      gen_contract("c3-transport-facts", "action profile carrying delegated transportFacts", %{
        "entrypoints" => [read_ep(), record_ep()],
        "profile" => facts_profile
      }),
      v(
        "sc/tamper-action-profile",
        "one profile field changed after minting: digest MUST change",
        %{"contract" => tampered_action},
        "No generation: digest = canonical digest of the given contract."
      ),
      v("sc/tamper-manifest-smuggle", "extra manifest key: digest MUST change", %{
        "contract" => tampered_manifest
      }),
      v(
        "sc/action-list-order-semantic",
        "action list order is semantic content: reversing it changes the digest",
        %{"contract" => reordered}
      ),
      gen_contract(
        "lexical-integral-float",
        "profile value 2.0 (float) vs 2 (integer) digest differently in Elixir",
        %{"entrypoints" => [], "profile" => %{"ratio" => 2.0}},
        "JavaScript cannot represent 2.0 distinctly from 2, so its ETF twin digests the integer.",
        "PENDING_DECISION"
      )
    ]
  end

  defp surface_contract_refusal do
    [
      v("scr/unknown-action-profile", "profile keyed by an unknown action id", %{
        "generation" => %{"entrypoints" => [], "profile" => %{"actions" => %{"Nope#x" => %{}}}}
      }),
      v("scr/bad-refusal-code", "possibleRefusals must be REFUSED_-prefixed", %{
        "generation" => %{
          "entrypoints" => [read_ep()],
          "profile" => %{"actions" => %{"#{@vm}#read" => %{"possibleRefusals" => ["NOPE"]}}}
        }
      }),
      v("scr/bare-refused", "bare REFUSED is not a refusal code", %{
        "generation" => %{
          "entrypoints" => [read_ep()],
          "profile" => %{"actions" => %{"#{@vm}#read" => %{"possibleRefusals" => ["REFUSED"]}}}
        }
      }),
      v("scr/empty-reason-refused", "REFUSED_ with an empty reason is not a refusal code", %{
        "generation" => %{
          "entrypoints" => [read_ep()],
          "profile" => %{"actions" => %{"#{@vm}#read" => %{"possibleRefusals" => ["REFUSED_"]}}}
        }
      }),
      v("scr/refusals-not-strings", "possibleRefusals must be strings", %{
        "generation" => %{
          "entrypoints" => [read_ep()],
          "profile" => %{"actions" => %{"#{@vm}#read" => %{"possibleRefusals" => [1]}}}
        }
      }),
      v("scr/evidence-not-boolean", "evidenceRequired must be boolean", %{
        "generation" => %{
          "entrypoints" => [read_ep()],
          "profile" => %{"actions" => %{"#{@vm}#read" => %{"evidenceRequired" => "yes"}}}
        }
      }),
      v(
        "scr/unknown-dispatch-outcome-is-not-refusal",
        "UNKNOWN_AFTER_DISPATCH is a dispatch outcome, not a possible refusal",
        %{
          "generation" => %{
            "entrypoints" => [read_ep()],
            "profile" => %{
              "actions" => %{"#{@vm}#read" => %{"possibleRefusals" => ["UNKNOWN_AFTER_DISPATCH"]}}
            }
          }
        }
      ),
      v("scr/profile-not-map", "profile must be a map", %{
        "generation" => %{"entrypoints" => [], "profile" => "gold"}
      })
    ]
  end

  # -- receipts ---------------------------------------------------------------------------

  @covered ~w(actionId input consequence dispatchState selectedTransport timestamp)

  defp base_receipt do
    %{
      "actionId" => "#{@vm}#record",
      "input" => %{
        "member_id" => "m-1",
        "milestone_id" => "ms-9",
        "cost_physical" => 5,
        "reward_spiritual" => 10
      },
      "consequence" => %{"status" => "completed", "score" => 1.5},
      "dispatchState" => "applied",
      "selectedTransport" => "http",
      "timestamp" => "2026-09-17T06:30:00.000Z",
      "sequence" => 3
    }
  end

  defp minted(receipt) do
    hash = receipt |> Map.take(@covered) |> CanonicalJSON.sha256_hex()
    Map.put(receipt, "receiptHash", hash)
  end

  defp receipt_digest do
    payload = base_receipt() |> Map.take(@covered)

    twin =
      payload
      |> Map.to_list()
      |> Enum.reverse()
      |> then(
        &("{" <>
            Enum.map_join(&1, ",", fn {k, val} ->
              Jason.encode!(k) <> ":" <> CanonicalJSON.encode(val)
            end) <> "}")
      )

    [
      v(
        "rd/r1-runtime-shaped",
        "receipt hash law: sha256 of canonical JSON of the covered sections",
        %{"payloadJson" => Jason.encode!(payload)}
      ),
      v(
        "rd/r2-insertion-order-twin",
        "same content, reversed key order in the text: same digest",
        %{"payloadJson" => twin}
      ),
      v("rd/r3-unicode-action", "unicode action id and glyph input", %{
        "payloadJson" =>
          ~s({"actionId":"Σ🜂#witness","input":{"glyph":"✓"},"consequence":{"seen":true},"dispatchState":"applied","selectedTransport":"phoenix_channel","timestamp":"2026-09-17T06:30:00.000Z"})
      }),
      v("rd/r4-null-sections", "absent covered sections hash as null", %{
        "payloadJson" =>
          ~s({"actionId":"A#b","input":null,"consequence":null,"dispatchState":null,"selectedTransport":null,"timestamp":null})
      }),
      v(
        "rd/lexical-float-consequence",
        "consequence value 2.0 hashes with its float spelling",
        %{
          "payloadJson" =>
            ~s({"actionId":"A#b","input":{},"consequence":{"score":2.0},"dispatchState":"applied","selectedTransport":"http","timestamp":"2026-09-17T06:30:00.000Z"})
        },
        "A JavaScript runtime that parses and re-serializes the receipt mints 2, not 2.0: the receipts disagree. Elixir refuses such a receipt (REFUSED_RECEIPT_DIGEST_MISMATCH).",
        "PENDING_DECISION"
      )
    ]
  end

  defp receipt_binding do
    base = minted(base_receipt())
    alt_hash = base["receiptHash"]

    tamper = fn key, value -> Map.put(base, key, value) end

    bad_ts =
      Map.put(base_receipt(), "timestamp", "2026-09-17T07:30:00.000Z")
      |> Map.put("receiptHash", alt_hash)

    [
      v("rb/ok-bound", "receiptHash binds the covered sections: event projected, OBSERVE only", %{
        "receipt" => base
      }),
      v(
        "rb/ok-noncovered-field-changes",
        "fields outside the covered set do not affect binding",
        %{"receipt" => Map.merge(base, %{"commandId" => "cmd_other", "extra" => %{"a" => 1}})}
      ),
      v("rb/ok-receiptref-slot", "digest carried in receiptRef is bound as well", %{
        "receipt" => base |> Map.delete("receiptHash") |> Map.put("receiptRef", alt_hash)
      }),
      v(
        "rb/ok-do-authority-still-observe",
        "DO-authority receipt back-projects to an OBSERVE event",
        %{"receipt" => Map.merge(base, %{"doAuthority" => true, "authorityBoundary" => "DO"})}
      ),
      v("rb/ok-ir-subject-iri", "IR semantic.subject_iri wins the subject", %{
        "receipt" => base,
        "irAction" => %{
          "resource" => "R",
          "action" => "a",
          "semantic" => %{"subject_iri" => "zoe:KingdomNeed#need_42"}
        }
      }),
      v("rb/ok-ir-resource-action-fallback", "ash:<resource>#<action> fallback", %{
        "receipt" => base,
        "irAction" => %{"resource" => "AshSurfaceTest.Post", "action" => "create"}
      }),
      v("rb/ok-unicode-action", "unicode action id", %{
        "receipt" => minted(%{base_receipt() | "actionId" => "Σ🜂#witness"})
      }),
      v(
        "rb/ok-opaque-git-sha",
        "40-char git sha in receiptHash is an opaque reference, carried verbatim",
        %{"receipt" => tamper.("receiptHash", String.duplicate("a", 40))}
      ),
      v("rb/ok-opaque-63", "63-byte value is not digest-shaped: carried verbatim", %{
        "receipt" => tamper.("receiptHash", String.duplicate("a", 63))
      }),
      v("rb/ok-opaque-65", "65-byte value is not digest-shaped: carried verbatim", %{
        "receipt" => tamper.("receiptHash", String.duplicate("a", 65))
      }),
      v("rb/ok-no-digest", "no digest at all: receipt_ref is null", %{
        "receipt" => Map.delete(base, "receiptHash")
      }),
      v("rb/tamper-consequence", "consequence changed after minting", %{
        "receipt" => tamper.("consequence", %{"status" => "completed", "score" => 99})
      }),
      v("rb/tamper-input", "input changed after minting", %{
        "receipt" => tamper.("input", %{"member_id" => "m-2"})
      }),
      v("rb/tamper-transport", "selectedTransport changed after minting", %{
        "receipt" => tamper.("selectedTransport", "phoenix_channel")
      }),
      v("rb/tamper-dispatch-state", "dispatchState changed after minting", %{
        "receipt" => tamper.("dispatchState", "unknown_after_dispatch")
      }),
      v("rb/tamper-action-id", "actionId changed after minting", %{
        "receipt" => tamper.("actionId", "Other#action")
      }),
      v("rb/tamper-timestamp", "timestamp changed (still parseable) after minting", %{
        "receipt" => bad_ts
      }),
      v("rb/tamper-uppercase-digest", "uppercase hex fails to bind (fail closed)", %{
        "receipt" => tamper.("receiptHash", String.upcase(alt_hash))
      }),
      v("rb/tamper-zero-digest", "digest-shaped but arbitrary", %{
        "receipt" => tamper.("receiptHash", String.duplicate("0", 64))
      }),
      v("rb/tamper-receiptref-slot", "tampered digest moved to receiptRef still refuses", %{
        "receipt" =>
          base
          |> Map.delete("receiptHash")
          |> Map.merge(%{"receiptRef" => String.duplicate("0", 64)})
      }),
      v(
        "rb/tamper-second-slot",
        "valid receiptHash plus digest-shaped wrong receiptRef refuses",
        %{"receipt" => Map.put(base, "receiptRef", String.duplicate("f", 64))}
      ),
      v("rb/refuse-missing-timestamp", "no timestamp: REFUSED_MISSING_TIMESTAMP", %{
        "receipt" => Map.delete(base_receipt(), "timestamp")
      }),
      v("rb/refuse-unparseable-timestamp", "unparseable timestamp", %{
        "receipt" => Map.put(base_receipt(), "timestamp", "yesterday")
      }),
      v("rb/refuse-no-subject", "no resolvable subject: REFUSED_INVALID_SUBJECT", %{
        "receipt" => Map.delete(base_receipt(), "actionId")
      }),
      v("rb/ok-blank-subject-iri-falls-back", "blank subject_iri falls back to the action id", %{
        "receipt" => base,
        "irAction" => %{"semantic" => %{"subject_iri" => "  "}}
      }),
      v("rb/refuse-malformed-ir-action", "non-map irAction", %{
        "receipt" => base,
        "irAction" => "AshSurfaceTest.Post#create"
      }),
      v("rb/refuse-malformed-ir-semantic", "non-map semantic section", %{
        "receipt" => base,
        "irAction" => %{"semantic" => "x"}
      }),
      v(
        "rb/order-subject-before-digest",
        "refusal order: subject refuses before digest binding",
        %{"receipt" => base |> Map.delete("actionId")}
      ),
      v(
        "rb/order-timestamp-before-digest",
        "refusal order: timestamp refuses before digest binding",
        %{"receipt" => Map.delete(base, "timestamp")}
      ),
      v("rb/order-subject-before-timestamp", "refusal order: subject refuses before timestamp", %{
        "receipt" => base_receipt() |> Map.delete("actionId") |> Map.delete("timestamp")
      }),
      v(
        "rb/lexical-float-consequence",
        "float-valued consequence binds under the Elixir float spelling",
        %{"receipt" => minted(%{base_receipt() | "consequence" => %{"score" => 2.0}})},
        "Elixir mints/binds over \"2.0\"; a JS-minted receipt of the same value hashes \"2\".",
        "PENDING_DECISION"
      )
    ]
  end

  # -- refusal vocabulary -------------------------------------------------------------------

  defp refusal_vocabulary do
    strings = [
      {"named", "REFUSED_NO_AUTHORITY", "canonical named refusal"},
      {"named-lower-reason", "REFUSED_x", "reason case is free"},
      {"named-unicode-reason", "REFUSED_ÉTAT", "non-ASCII reason"},
      {"named-double-underscore", "REFUSED__", "underscore-only reason is still a reason"},
      {"bare", "REFUSED", "bare REFUSED names no reason: not a standing"},
      {"prefix-only", "REFUSED_", "empty reason: not a refusal"},
      {"lowercase", "refused_x", "prefix is case sensitive"},
      {"leading-space", " REFUSED_X", "no trimming"},
      {"trailing-space-reason", "REFUSED_X ", "trailing space is part of the reason"},
      {"space-reason", "REFUSED_ ", "a space is a (non-empty) reason"},
      {"base-alive", "ALIVE", "base standing: valid, not refused"},
      {"base-partial", "PARTIAL_ALIVE", "base standing"},
      {"base-blocked", "BLOCKED", "base standing"},
      {"base-build-broken", "BUILD_BROKEN", "base standing"},
      {"base-unsupported", "UNSUPPORTED", "base standing"},
      {"unknown", "UNKNOWN", "UNKNOWN is not a standing"},
      {"unknown-after-dispatch", "UNKNOWN_AFTER_DISPATCH", "a dispatch outcome, not a standing"},
      {"success-outcome", "SUCCESS", "a dispatch outcome, not a standing"},
      {"alive-lowercase", "alive", "standings are case sensitive"},
      {"empty", "", "empty string"},
      {"bogus", "BOGUS", "not in the vocabulary"}
    ]

    multiline = [
      {"newline-reason", "REFUSED_\nX", "reason begins with a newline"},
      {"cr-reason", "REFUSED_\r", "reason is a carriage return"},
      {"ls-reason", "REFUSED_\u2028", "reason is U+2028"},
      {"newline-only-reason", "REFUSED_\n", "reason is only a newline"},
      {"trailing-newline-reason", "REFUSED_X\nY", "newline after a first reason char"}
    ]

    nonstrings = [
      {"null", nil, "null"},
      {"number", 42, "number"},
      {"true", true, "boolean"},
      {"list", ["REFUSED_X"], "list"}
    ]

    Enum.map(strings, fn {n, s, d} -> v("rv/#{n}", d, %{"value" => s}) end) ++
      Enum.map(multiline, fn {n, s, d} ->
        v(
          "rv/multiline/#{n}",
          d,
          %{"value" => s},
          "Reason characters include line terminators; regex `.` does not match them without a dotall flag."
        )
      end) ++ Enum.map(nonstrings, fn {n, s, d} -> v("rv/nonstring/#{n}", d, %{"value" => s}) end)
  end

  # -- reconcile status ----------------------------------------------------------------------

  defp reconcile_status do
    [
      {"completed", %{"status" => "COMPLETED"}},
      {"not-observed", %{"status" => "NOT_OBSERVED"}},
      {"still-unknown", %{"status" => "STILL_UNKNOWN"}},
      {"passthrough-keys",
       %{"status" => "COMPLETED", "receipt" => %{"a" => 1}, "commandId" => "cmd_1"}},
      {"lowercase", %{"status" => "completed"}},
      {"unknown-status", %{"status" => "PENDING"}},
      {"success-is-not-a-status", %{"status" => "SUCCESS"}},
      {"unknown-after-dispatch-is-not-a-status", %{"status" => "UNKNOWN_AFTER_DISPATCH"}},
      {"padded", %{"status" => " COMPLETED"}},
      {"null-status", %{"status" => nil}},
      {"number-status", %{"status" => 1}},
      {"missing-status", %{"receipt" => %{}}},
      {"empty-object", %{}},
      {"list-verdict", ["COMPLETED"]},
      {"string-verdict", "COMPLETED"},
      {"null-verdict", nil}
    ]
    |> Enum.map(fn {name, verdict} ->
      v("rs/#{name}", "reconcile reply admission: #{name}", %{"verdict" => verdict})
    end)
  end

  # -- IR codec -----------------------------------------------------------------------------

  defp full_ir do
    %IR{
      version: "26.10.8",
      ash: %IR.Ash{
        resource: "Conformance.Post",
        action: "read",
        action_type: "read",
        inputs: [%{"name" => "id", "required" => true, "type" => "uuid"}],
        outputs: %{"fields" => ["id", "body"]},
        policies: [%{"name" => "can_read", "type" => "allow"}]
      },
      semantic: %IR.Semantic{
        subject_iri: "https://ash.surface/i/user",
        capability_iri: "https://ash.surface/c/post#read",
        shape_id: "shape:post:read:v1",
        ontology: "dfcm",
        predicates: %{"describes" => "post", "grants" => "observe"}
      },
      capability: %IR.Capability{
        capability_id: "cap:post:read",
        consequence_class: "OBSERVE",
        authority_required: false,
        receipt_required: true
      },
      presentation: %IR.Presentation{
        format: "compact",
        group: "content",
        label: "Posts",
        order: 1,
        widget: "table"
      },
      schema: %IR.Schema{
        aria: %{"label" => "Posts", "role" => "table"},
        input: %{"type" => "object", "properties" => %{"id" => %{"type" => "string"}}},
        output: %{"type" => "object", "properties" => %{"body" => %{"type" => "string"}}},
        zod: "z.object({ id: z.string().uuid() })"
      }
    }
  end

  defp ir_codec do
    full = full_ir() |> Codec.to_map() |> Runner.jsonify()
    sparse = %IR{} |> Codec.to_map() |> Runner.jsonify()

    presentation_only =
      %IR{presentation: %IR.Presentation{label: "Dumb screen"}}
      |> Codec.to_map()
      |> Runner.jsonify()

    false_leaves =
      %IR{capability: %IR.Capability{authority_required: false, receipt_required: false}}
      |> Codec.to_map()
      |> Runner.jsonify()

    empty_sections =
      %IR{presentation: %IR.Presentation{}, ash: %IR.Ash{}} |> Codec.to_map() |> Runner.jsonify()

    [
      v(
        "ir/full",
        "fully populated five-section IR",
        %{"map" => full},
        "Input is the canonical map; digest is over the same map."
      ),
      v("ir/sparse-all-nil", "all sections nil: null, never a fabricated empty map", %{
        "map" => sparse
      }),
      v("ir/presentation-only", "single present section, nil fields as null", %{
        "map" => presentation_only
      }),
      v("ir/false-leaves", "false leaves survive the round trip (not dropped as nil)", %{
        "map" => false_leaves
      }),
      v("ir/empty-present-sections", "present-but-empty sections differ from nil sections", %{
        "map" => empty_sections
      }),
      v(
        "ir/nil-vs-empty-digest-differs",
        "sparse vs empty-present digests differ (see ir/sparse-all-nil, ir/empty-present-sections)",
        %{"map" => Map.put(sparse, "ash", empty_sections["ash"])}
      ),
      v("ir/unknown-top-level-key-ignored", "forward tolerance: unknown top-level key ignored", %{
        "map" => Map.put(full, "futureSection", %{"x" => 1})
      }),
      v(
        "ir/carried-digest-ignored",
        "a carried digest is ignored in favor of the recomputed one",
        %{"map" => Map.put(full, "digest", String.duplicate("0", 64))}
      ),
      v(
        "ir/unknown-section-field-ignored",
        "forward tolerance: unknown section-internal field ignored",
        %{"map" => put_in(full, ["ash", "futureField"], "x")}
      ),
      v("ir/unicode-and-list-order", "list order is semantic; unicode preserved", %{
        "map" =>
          full
          |> put_in(["ash", "inputs"], [%{"name" => "z"}, %{"name" => "a"}])
          |> put_in(["presentation", "label"], "Σ🜂✓")
      }),
      v("ir/version-nil", "version may be null", %{"map" => Map.put(full, "version", nil)}),
      v("ir/missing-sections", "missing section keys are typed-rejected", %{
        "map" => Map.drop(full, ["ash", "schema"])
      }),
      v("ir/version-not-string", "version must be string or null", %{
        "map" => Map.put(full, "version", 26)
      }),
      v("ir/section-not-map", "section must be map or null", %{
        "map" => Map.put(full, "ash", "read")
      }),
      v("ir/section-list", "section as a list is rejected", %{
        "map" => Map.put(full, "semantic", [1])
      }),
      v("ir/not-a-map", "IR input must be a map", %{"map" => ["ash"]}),
      v("ir/deep-nested-values", "deep nested JSON leaves inside a section field", %{
        "map" =>
          put_in(full, ["schema", "input"], %{
            "a" => [1, 2.5, "x", nil, true, false, %{"b" => []}]
          })
      }),
      v("ir/safe-int-boundary", "safe-integer boundary inside a section field", %{
        "map" => put_in(full, ["presentation", "order"], 9_007_199_254_740_991)
      }),
      v("ir/negative-and-int32-boundaries", "int32 boundaries in an ETF-sensitive field", %{
        "map" => put_in(full, ["presentation", "order"], -2_147_483_649)
      })
    ]
  end

  # -- field_name_emission (lane RBV) ---------------------------------------------------
  #
  # Inputs authored here; expected minted by Runner.run("field_name_emission", _) ->
  # AshSurface.FieldName / EmittedKeys. The JS side re-derives from the reference rule
  # (ash_typescript helpers.ex:25-30: Macro.camelize + lowercase-first; KD-13).

  defp field_name_emission do
    names = [
      {"user-id", "user_id"},
      {"trailing-question", "is_ready?"},
      {"digit-segment", "line_1"},
      {"short-digit-segment", "p_1"},
      {"trailing-underscore", "x1_"},
      {"double-underscore", "a__b"},
      {"upper-acronym", "HTTP_code"},
      {"capital-first-segment", "Foo_bar"},
      {"underscore-upper", "a_B"},
      {"leading-underscore", "_x"},
      {"double-leading-underscore", "__x"},
      {"single-char", "x"},
      {"leading-digit", "1abc"},
      {"empty", ""},
      {"unicode", "über_straße"},
      {"unicode-after-underscore", "a_ß"},
      {"unicode-first", "é_a"},
      {"slash", "a/b"},
      {"digit-after-underscore", "a_1b"},
      {"very-long", String.duplicate("ab_", 100) <> "z"}
    ]

    formatters = ~w(camel_case snake_case pascal_case)

    emit =
      for f <- formatters, {slug, name} <- names do
        v("fn/emit/#{f}/#{slug}", "#{f} emitted key of #{inspect(String.slice(name, 0, 20))}",
          %{"op" => "emit", "formatter" => f, "name" => name})
      end

    collisions =
      [
        {"snake-vs-camel", "camel_case", ["foo_bar", "fooBar"]},
        {"a-b-vs-aB", "camel_case", ["a_b", "aB"]},
        {"double-underscore", "camel_case", ["a__b", "a_b"]},
        {"trailing-underscore", "camel_case", ["x1_", "x1"]},
        {"capital-segment", "camel_case", ["Foo_bar", "foo_bar"]},
        {"pascal", "pascal_case", ["foo_bar", "FooBar"]},
        {"leading-underscore-distinct", "camel_case", ["_x", "x"]},
        {"question-distinct", "camel_case", ["is_ready?", "is_ready"]},
        {"snake-distinct", "snake_case", ["user_id", "userId"]},
        {"exact-duplicate-is-not-collision", "camel_case", ["user_id", "user_id"]},
        {"three-way", "camel_case", ["a_b_c", "aBC", "a__b_c"]}
      ]
      |> Enum.map(fn {slug, f, ns} ->
        v("fn/collision/#{f}/#{slug}", "emitted-key collision law over #{inspect(ns)}",
          %{"op" => "collision", "formatter" => f, "names" => ns})
      end)

    inverse =
      [
        {"camel-ok", "camel_case", ["user_id", "is_ready?"], "userId"},
        {"camel-question-ok", "camel_case", ["user_id", "is_ready?"], "isReady?"},
        {"camel-question-stripped", "camel_case", ["user_id", "is_ready?"], "isReady"},
        {"camel-wrong-case", "camel_case", ["user_id"], "UserId"},
        {"camel-ambiguous", "camel_case", ["foo_bar", "fooBar"], "fooBar"},
        {"camel-ambiguous-double-underscore", "camel_case", ["a__b", "a_b"], "aB"},
        {"camel-leading-underscore", "camel_case", ["_x", "x"], "_x"},
        {"camel-leading-underscore-plain", "camel_case", ["_x", "x"], "x"},
        {"camel-empty-client", "camel_case", ["user_id"], ""},
        {"camel-unknown", "camel_case", ["user_id"], "nope"},
        {"snake-ok", "snake_case", ["user_id", "userId"], "user_id"},
        {"pascal-ok", "pascal_case", ["user_id"], "UserId"},
        {"pascal-camel-spelling", "pascal_case", ["user_id"], "userId"}
      ]
      |> Enum.map(fn {slug, f, adm, client} ->
        v("fn/inverse/#{f}/#{slug}", "admitted-set inverse of #{inspect(client)}",
          %{"op" => "inverse", "formatter" => f, "admitted" => adm, "client" => client})
      end)

    checked =
      for f <- ~w(camel_case pascal_case),
          {slug, name} <-
            Enum.filter(names, fn {s, _} ->
              s in ~w(user-id trailing-question double-underscore upper-acronym
                      capital-first-segment underscore-upper leading-underscore
                      trailing-underscore digit-segment)
            end) do
        v("fn/roundtrip/#{f}/#{slug}", "forward-path invertibility of #{inspect(name)}",
          %{"op" => "format_checked", "formatter" => f, "name" => name})
      end

    emit ++ collisions ++ inverse ++ checked
  end

  # -- transport outcome -----------------------------------------------------------------------

  defp transport_outcome do
    base = %{
      "actionId" => "Conformance.Resource#act",
      "declared" => @transports,
      "available" => @transports,
      "preferred" => "http"
    }

    pre = ~w(signal_aborted_before_dispatch invalid_command_id invalid_timeout)
    post = ~w(adapter_rejected deadline_exceeded abort_after_dispatch)

    Enum.map(pre, fn cause ->
      v(
        "to/pre/#{cause}",
        "failure before dispatch: nothing sent, fallback still open",
        Map.merge(base, %{"phase" => "pre_dispatch", "cause" => cause}),
        "Pre-dispatch refusal: no receipt of a dispatch, no dispatch outcome."
      )
    end) ++
      Enum.map(post, fn cause ->
        v(
          "to/post/#{cause}",
          "failure after dispatch: UNKNOWN_AFTER_DISPATCH, fallback closed, no replay over another transport",
          Map.merge(base, %{"phase" => "post_dispatch", "cause" => cause}),
          "The alternate admitted transport MUST NOT be invoked."
        )
      end) ++
      [
        v(
          "to/pre/no-available-transport",
          "no available transport is a typed pre-dispatch refusal",
          Map.merge(base, %{
            "phase" => "pre_dispatch",
            "cause" => "no_available_transport",
            "available" => []
          })
        ),
        v(
          "to/pre/fallback-to-declared-alternative",
          "preferred transport unavailable: pre-dispatch fallback to the other admitted one is lawful",
          Map.merge(base, %{
            "phase" => "pre_dispatch",
            "cause" => "adapter_unavailable",
            "available" => ["phoenix_channel"]
          })
        ),
        v(
          "to/post/after-fallback",
          "post-dispatch failure after a pre-dispatch fallback still closes fallback",
          Map.merge(base, %{
            "phase" => "post_dispatch",
            "cause" => "adapter_rejected",
            "available" => ["phoenix_channel"]
          })
        )
      ]
  end
end

ConformanceRegen.main()
