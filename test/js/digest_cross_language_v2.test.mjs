import test from "node:test";
import assert from "node:assert/strict";
import crypto from "node:crypto";
import { createClient } from "../../priv/static/ash_surface_runtime.mjs";

/**
 * Cross-language digest contract, round 2 — the IR-era re-pin of t26
 * (digest_cross_language.test.mjs, which pins the complete-contract encoding:
 * canonical tuple-list sorting, BIT_BINARY, atoms, integers, floats, lists).
 *
 * What this round pins that t26 does not: the digest subject is the runtime's
 * ACTUAL post-parse contract (`client.contract`), not the raw JSON handed to
 * createClient. The runtime normalizes through Zod before anything else sees
 * the contract:
 *
 *   - defaulted action fields (authorityBoundary, doAuthority,
 *     receiptRequired, evidenceRequired, possibleRefusals, per-action
 *     profile, surface.profile) are re-materialized by the runtime itself, so
 *     a contract JSON with those fields stripped still digests to the Elixir
 *     golden IFF the runtime's Zod defaults equal the Elixir-emitted values
 *     byte-for-byte (F4);
 *   - passthrough keeps IR-era envelope extensions — ontologyDigest,
 *     applicationReleaseIdentity, a surface `presentation` section, and
 *     per-action `irRef` keys, all accepted by the v26.9.17 schema — inside
 *     the digested term (F5).
 *
 * Fixtures (manifest-with-surface-envelope form, one Ash fixture resource,
 * distinct from t26's F1-F3 digests — asserted below):
 *
 *   F4 create-only manifest, empty profile. Golden from the real
 *      AshSurface.from_manifest/2 pipeline (s.digest).
 *   F5 read+record manifest whose profile pins ETF boundaries t26 left
 *      unpinned — 255/256 (SMALL_INTEGER/INTEGER), -2147483648/-2147483649
 *      (INTEGER/negative SMALL_BIG), -9876543210 (negative SMALL_BIG), 0.125
 *      and -0.5 (NEW_FLOAT), "" (zero-length BIT_BINARY), 4-byte UTF-8
 *      ("Σ🜂✓"), [] / {} in nested positions, literal true/false/nil list —
 *      extended with IR-era envelope keys. Golden from the same pipeline
 *      output digested by an exact replica of the private
 *      AshSurface.digest/1, asserted equal to the real pipeline digest on
 *      F4/F5-base/F6 during generation (mismatch aborts).
 *   F6 read+record manifest with per-action authority overrides
 *      (CONSTRUCT boundary, doAuthority/receiptRequired false,
 *      evidenceRequired true, refusal list, quota 9007199254740991 — the
 *      JSON-safe integer ceiling). Golden from the real pipeline.
 *
 * F4 was RE-FROZEN at v50 integration (2026-09-17): its pre-v10 fixture
 * carried locally derived authority facts (DO/true/true) on an empty
 * profile, which the v26.9.17 delegated-facts law (v10) removed on both
 * the Elixir and runtime sides. The re-freeze ran the SAME real pipeline
 * (AshSurface.from_manifest/2, empty profile) on the integrated tree and
 * froze s.digest plus the exact digested JSON byte-for-byte. The richer
 * manifest body (filter_capabilities et al.) is the current real
 * pipeline output.
 * Goldens were produced in this worktree (exp/v43 @ 282f3ca, OTP 28 /
 * stdlib 7.2, ash 3.33.x) on 2026-09-15 via `MIX_ENV=test mix run` calling
 * AshSurface.from_manifest/2 on the VolunteerMilestone fixture, freezing
 * s.digest (F4/F6) or replica-digest of the extended contract map (F5) plus
 * the exact digested JSON (embedded below, byte-for-byte).
 *
 * Falsifiers: any field mutation flips the digest; deep key-order
 * permutation never does.
 */

const GOLDENS = [
  {
    name: "F4 create-only contract, empty profile (zod defaults == Elixir defaults)",
    elixirDigest: "f29ff4f43a88e146f61b2c9f048b385d6f6b9c9d533f2fb94a863ac5eabee7b4",
    contractJson:
      '{"ashManifestSchemaVersion":"1.0.0","generatorIdentity":"ash_surface:v26.9.17","manifest":{"entrypoints":[{"action":{"get":false,"inputs":[{"allow_nil":false,"has_default":false,"name":"member_id","required":true,"sensitive":false,"type":{"allow_nil":null,"kind":"string","module":"Ash.Type.String","name":"String"}},{"allow_nil":false,"has_default":false,"name":"milestone_id","required":true,"sensitive":false,"type":{"allow_nil":null,"kind":"string","module":"Ash.Type.String","name":"String"}},{"allow_nil":false,"has_default":false,"name":"cost_physical","required":true,"sensitive":false,"type":{"allow_nil":null,"kind":"integer","module":"Ash.Type.Integer","name":"Integer"}},{"allow_nil":false,"has_default":false,"name":"reward_spiritual","required":true,"sensitive":false,"type":{"allow_nil":null,"kind":"integer","module":"Ash.Type.Integer","name":"Integer"}}],"metadata":[],"primary":false,"type":"create"},"resource":"AshSurface.Fixtures.VolunteerMilestone"}],"filter_capabilities":{"boolean_connectives":["and","or","not"],"custom_expressions":[],"functions":[{"description":"Subtracts the given interval or Duration from the current time in UTC.\\n\\nFor example:\\n   deleted_at > ago(7, :day)\\n   deleted_at > ago(Duration.new!(day: 7))\\n\\nDocumentation + available intervals inspired by the corresponding ecto interval implementation\\n","module":"Ash.Query.Function.Ago","name":"ago","predicate":false,"returns":{"kind":"concrete","type_ref":"Ash.Type.UtcDatetimeUsec"},"signatures":[{"args":[{"kind":"concrete","type_ref":"Ash.Type.Integer"},{"kind":"concrete","type_ref":"Ash.Type.DurationName"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.Duration"}]}]},{"description":"Gets an element in the list by index\\n","module":"Ash.Query.Function.At","name":"at","predicate":false,"returns":{"kind":"same"},"signatures":[{"args":[{"kind":"array","of":{"kind":"any"}},{"kind":"concrete","type_ref":"Ash.Type.Integer"}]}]},{"description":"Constructs a composite type in a way that is natively understood by the data layer\\n\\nTo do this, provide a tuple matching the format expected by the type in question.\\nCheck that type\'s documentation for this information.\\n","module":"Ash.Query.Function.CompositeType","name":"composite_type","predicate":false,"returns":{"kind":"any"},"signatures":[{"args":[{"kind":"any"},{"kind":"any"}]},{"args":[{"kind":"any"},{"kind":"any"},{"kind":"any"}]}]},{"description":"Returns true if the first string contains the second.\\n\\nCase insensitive strings are accounted for on either side.\\n\\n   contains(\\"foo\\", \\"fo\\")\\n   true\\n\\n   contains(%Ash.CiString{:string \\"foo\\"}, \\"FoO\\")\\n   true\\n\\n   contains(\\"foo\\", %Ash.CiString{:string \\"FOO\\"})\\n   true\\n","module":"Ash.Query.Function.Contains","name":"contains","predicate":true,"returns":{"kind":"concrete","type_ref":"Ash.Type.String"},"signatures":[{"args":[{"kind":"concrete","type_ref":"Ash.Type.String"},{"kind":"concrete","type_ref":"Ash.Type.String"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.String"},{"kind":"concrete","type_ref":"Ash.Type.CiString"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.CiString"},{"kind":"concrete","type_ref":"Ash.Type.String"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.CiString"},{"kind":"concrete","type_ref":"Ash.Type.CiString"}]}]},{"description":"Returns the count of nil.\\n\\n    count_nil([nil, 1, nil]) # 2\\n","module":"Ash.Query.Function.CountNils","name":"count_nils","predicate":false,"returns":{"kind":"concrete","type_ref":"Ash.Type.Integer"},"signatures":[{"args":[{"kind":"array","of":{"kind":"any"}}]}]},{"description":"Adds the given interval or Duration to the current time in UTC\\nAdds the given interval or Duration to the current time in UTC\\n\\nFor example:\\n   activates_at < date_add(today(), 7, :day)\\n   activates_at < date_add(today(), Duration.new!(day: 7))\\n   activates_at < date_add(today(), Duration.new!(day: 7))\\n\\nDocumentation + available intervals inspired by the corresponding ecto interval implementation\\n","module":"Ash.Query.Function.DateAdd","name":"date_add","predicate":false,"returns":{"kind":"concrete","type_ref":"Ash.Type.Date"},"signatures":[{"args":[{"kind":"concrete","type_ref":"Ash.Type.Date"},{"kind":"concrete","type_ref":"Ash.Type.Integer"},{"kind":"concrete","type_ref":"Ash.Type.DurationName"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.Date"},{"kind":"concrete","type_ref":"Ash.Type.Duration"}]}]},{"description":"Adds the given interval or Duration to the current time in UTC\\n\\nFor example:\\n   activates_at < datetime_add(now(), 7, :day)\\n   activates_at < datetime_add(now(), Duration.new!(day:7))\\n\\nDocumentation + available intervals inspired by the corresponding ecto interval implementation\\n","module":"Ash.Query.Function.DateTimeAdd","name":"datetime_add","predicate":false,"returns":{"kind":"concrete","type_ref":"Ash.Type.UtcDatetime"},"signatures":[{"args":[{"kind":"concrete","type_ref":"Ash.Type.UtcDatetime"},{"kind":"concrete","type_ref":"Ash.Type.Integer"},{"kind":"concrete","type_ref":"Ash.Type.DurationName"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.UtcDatetime"},{"kind":"concrete","type_ref":"Ash.Type.Duration"}]}]},{"description":"Adds the given interval from the current time in UTC.\\n\\nFor example:\\n   expires_at < from_now(7, :day)\\n\\nDocumentation + available intervals inspired by the corresponding ecto interval implementation\\n","module":"Ash.Query.Function.Fragment","name":"fragment","predicate":false,"returns":{"kind":"any"},"signatures":"var_args"},{"description":"Adds the given interval or Duration from the current time in UTC.\\n\\nFor example:\\n   expires_at < from_now(7, :day)\\n   expires_at < from_now(Duration.new!(day: 7))\\n\\nDocumentation + available intervals inspired by the corresponding ecto interval implementation\\n","module":"Ash.Query.Function.FromNow","name":"from_now","predicate":false,"returns":{"kind":"concrete","type_ref":"Ash.Type.UtcDatetime"},"signatures":[{"args":[{"kind":"concrete","type_ref":"Ash.Type.Integer"},{"kind":"concrete","type_ref":"Ash.Type.DurationName"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.Duration"}]}]},{"description":"Gets the value at the provided path in the value, which must be a map or embed.\\n\\nIf you are using a datalayer that provides a `type` function (like AshPostgres), it is a good idea to\\nwrap your call in that function, e.g `type(author[:bio][:title], :string)`, since data layers that depend\\non knowing types may not be able to infer the type from the path. Ash may eventually be able to figure out\\nthe type, in the case that the path consists of only embedded attributes.\\n\\nIf an atom key is provided, access is *indiscriminate* of atoms vs strings. The atom key is checked first.\\nIf a string key is provided, that is the only thing that is checked. If the value will or may be a struct, be sure to use atoms.\\n\\nThe data layer may handle this differently, for example, AshPostgres only checks\\nstrings at the data layer (because that\'s all it can be in the database anyway).\\n\\nAvailable in query expressions using bracket syntax, e.g `foo[:bar][:baz]`.\\n","module":"Ash.Query.Function.GetPath","name":"get_path","predicate":false,"returns":{"kind":"any"},"signatures":[{"args":[{"kind":"concrete","type_ref":"Ash.Type.Map"},{"kind":"array","of":{"kind":"any"}}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.Map"},{"kind":"any"}]}]},{"description":"Returns true if the second argument is found in the first\\n\\n   contains([1, 2, 3], 1)\\n   true\\n\\n   contains([1, 2, 3], 4)\\n   false\\n\\n   contains(nil, 1)\\n   nil\\n","module":"Ash.Query.Function.Has","name":"has","predicate":true,"returns":{"kind":"concrete","type_ref":"Ash.Type.Boolean"},"signatures":[{"args":[{"kind":"array","of":{"kind":"any"}},{"kind":"same"}]}]},{"description":"is_distinct_from(left, right)\\n\\nSQL\'s IS DISTINCT FROM operator.\\nUnlike `!=`, this operator treats NULL as a comparable value.\\n\\nWhen both sides cannot return NULL, this simplifies to `!=` for better performance.\\n","module":"Ash.Query.Function.IsDistinctFrom","name":"is_distinct_from","predicate":true,"returns":{"kind":"concrete","type_ref":"Ash.Type.Boolean"},"signatures":[{"args":[{"kind":"any"},{"kind":"same"}]}]},{"description":"true if the provided field is nil\\n","module":"Ash.Query.Function.IsNil","name":"is_nil","predicate":false,"returns":{"kind":"concrete","type_ref":"Ash.Type.Boolean"},"signatures":[{"args":[{"kind":"any"}]}]},{"description":"is_not_distinct_from(left, right)\\n\\nSQL\'s IS NOT DISTINCT FROM operator (NULL-safe equality).\\nUnlike `==`, this operator treats NULL as equal to NULL.\\n\\nWhen both sides cannot return NULL, this simplifies to `==` for better performance.\\n","module":"Ash.Query.Function.IsNotDistinctFrom","name":"is_not_distinct_from","predicate":true,"returns":{"kind":"concrete","type_ref":"Ash.Type.Boolean"},"signatures":[{"args":[{"kind":"any"},{"kind":"same"}]}]},{"description":"If predicate is truthy, then the second argument is returned, otherwise the third.\\n","module":"Ash.Query.Function.If","name":"if","predicate":false,"returns":{"kind":"same"},"signatures":[{"args":[{"kind":"concrete","type_ref":"Ash.Type.Boolean"},{"kind":"any"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.Boolean"},{"kind":"any"},{"kind":"same"}]}]},{"description":"Returns true if the two arguments intersect.\\n\\n   intersects([1, 2, 3], [1])\\n   true\\n\\n   intersects([1, 2, 3], [4])\\n   false\\n\\n   intersects([1], nil)\\n   nil\\n\\n   intersects(nil, [1])\\n   nil\\n","module":"Ash.Query.Function.Intersects","name":"intersects","predicate":true,"returns":{"kind":"concrete","type_ref":"Ash.Type.Boolean"},"signatures":[{"args":[{"kind":"array","of":{"kind":"any"}},{"kind":"array","of":{"kind":"same"}}]}]},{"description":"Runs the provided MFA and returns the result as a known value.\\n\\nEvaluated just before running the query.\\n","module":"Ash.Query.Function.Lazy","name":"lazy","predicate":false,"returns":{"kind":"any"},"signatures":[{"args":[{"kind":"any"}]}]},{"description":"Returns the length of a list attribute defined by the composite type `{:array, Type}`.\\n\\n    length(roles)\\n\\nIf the attribute allows nils:\\n\\n    length(roles || [])\\n\\n","module":"Ash.Query.Function.Length","name":"length","predicate":false,"returns":{"kind":"concrete","type_ref":"Ash.Type.Integer"},"signatures":[{"args":[{"kind":"array","of":{"kind":"any"}}]}]},{"description":"Negates the value\\n","module":"Ash.Query.Function.Minus","name":"-","predicate":false,"returns":{"kind":"same"},"signatures":[{"args":[{"kind":"any"}]}]},{"description":"Returns the current datetime\\n","module":"Ash.Query.Function.Now","name":"now","predicate":false,"returns":{"kind":"concrete","type_ref":"Ash.Type.UtcDatetimeUsec"},"signatures":[{"args":[]}]},{"description":"Returns true if two ranges are adjacent, meeting with no gap and no shared point.\\n\\nThe seam counts only when exactly one side includes it. Symmetric, and an empty\\nrange is adjacent to nothing.\\n\\n   range_adjacent(range1, range2)\\n","module":"Ash.Query.Function.RangeAdjacent","name":"range_adjacent","predicate":true,"returns":{"kind":"concrete","type_ref":"Ash.Type.Boolean"},"signatures":[{"args":[{"kind":"any"},{"kind":"same"}]}]},{"description":"Returns true if a range holds a value, which may be a point or another range.\\n\\nAn unbounded end holds everything beyond it, and an empty range holds no point. A\\nbound holds its own value only when it is inclusive.\\n\\n   range_contains(range, value)\\n","module":"Ash.Query.Function.RangeContains","name":"range_contains","predicate":true,"returns":{"kind":"concrete","type_ref":"Ash.Type.Boolean"},"signatures":[{"args":[{"kind":"any"},{"kind":"any"}]}]},{"description":"Returns a range\'s lower endpoint, of its inner type.\\n\\nNil where the range is unbounded at that end, and where it is empty.\\n\\n   range_lower(range)\\n","module":"Ash.Query.Function.RangeLower","name":"range_lower","predicate":false,"returns":{"kind":"any"},"signatures":[{"args":[{"kind":"any"}]}]},{"description":"Returns true if two ranges overlap (share at least one point).\\n\\nMaps to the Postgres range overlap operator `&&`, and answers in an expression what\\n`Ash.Range.intersects?/2` answers at runtime. Used, among other things, to relate\\ntwo temporal resources (`range_overlaps(parent(valid_at), valid_at)`).\\n\\n   range_overlaps(range1, range2)\\n","module":"Ash.Query.Function.RangeOverlaps","name":"range_overlaps","predicate":true,"returns":{"kind":"concrete","type_ref":"Ash.Type.Boolean"},"signatures":[{"args":[{"kind":"any"},{"kind":"same"}]}]},{"description":"Returns a range\'s upper endpoint, of its inner type.\\n\\nNil where the range is unbounded at that end, and where it is empty.\\n\\n   range_upper(range)\\n","module":"Ash.Query.Function.RangeUpper","name":"range_upper","predicate":false,"returns":{"kind":"any"},"signatures":[{"args":[{"kind":"any"}]}]},{"description":"If the predicate is truthy, the provided exception is raised with the provided values.\\n\\nThis exception is not \\"raised\\" in the Elixir sense, but the entire expression fails to\\nevaluate with the given error. Various data layers will handle this differently.\\n","module":"Ash.Query.Function.Error","name":"error","predicate":false,"returns":{"kind":"concrete","type_ref":"no_return"},"signatures":[{"args":[{"kind":"concrete","type_ref":"Ash.Type.Atom"},{"kind":"any"}]}]},{"description":"Rounds a float, decimal or integer to the given number of points\\n","module":"Ash.Query.Function.Rem","name":"rem","predicate":false,"returns":{"kind":"concrete","type_ref":"Ash.Type.Integer"},"signatures":[{"args":[{"kind":"concrete","type_ref":"Ash.Type.Integer"},{"kind":"concrete","type_ref":"Ash.Type.Integer"}]}]},{"description":"Rounds a float, decimal or integer to the given number of points\\n","module":"Ash.Query.Function.Round","name":"round","predicate":false,"returns":{"kind":"concrete","type_ref":"Ash.Type.Float"},"signatures":[{"args":[{"kind":"concrete","type_ref":"Ash.Type.Float"},{"kind":"concrete","type_ref":"Ash.Type.Integer"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.Decimal"},{"kind":"concrete","type_ref":"Ash.Type.Integer"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.Integer"},{"kind":"concrete","type_ref":"Ash.Type.Integer"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.Float"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.Decimal"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.Integer"}]}]},{"description":"Returns the current date.\\n","module":"Ash.Query.Function.Today","name":"today","predicate":false,"returns":{"kind":"concrete","type_ref":"Ash.Type.Date"},"signatures":[{"args":[]}]},{"description":"Casts the value to a given type. Can also be used to provide type hints to data layers, where appropriate.\\n","module":"Ash.Query.Function.Type","name":"type","predicate":false,"returns":"unknown","signatures":[{"args":[{"kind":"any"},{"kind":"any"}]},{"args":[{"kind":"any"},{"kind":"any"},{"kind":"any"}]}]},{"description":"Converts a date or datetime into the start of day\\n\\nAccepts an optional time zone, in the same format that can be passed to\\n`DateTime.new/3`.\\n\\nFor example:\\n   start_of_day(now()) < a_datetime()\\n   start_of_day(now(), \\"Europe/Copenhagen\\") < a_datetime()\\n","module":"Ash.Query.Function.StartOfDay","name":"start_of_day","predicate":false,"returns":{"kind":"concrete","type_ref":"Ash.Type.UtcDatetime"},"signatures":[{"args":[{"kind":"concrete","type_ref":"Ash.Type.DateTime"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.DateTime"},{"kind":"concrete","type_ref":"Ash.Type.String"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.Date"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.Date"},{"kind":"concrete","type_ref":"Ash.Type.String"}]}]},{"description":"Downcase a string\\n","module":"Ash.Query.Function.StringDowncase","name":"string_downcase","predicate":false,"returns":{"kind":"concrete","type_ref":"Ash.Type.String"},"signatures":[{"args":[{"kind":"concrete","type_ref":"Ash.Type.String"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.CiString"}]}]},{"description":"Returns true if the first string ends with the second.\\n\\nCase insensitive strings are accounted for on either side.\\n\\n   string_ends_with(\\"foo\\", \\"oo\\")\\n   true\\n\\n   string_ends_with(%Ash.CiString{string: \\"foo\\"}, \\"OO\\")\\n   true\\n\\n   string_ends_with(\\"foo\\", %Ash.CiString{string: \\"OO\\"})\\n   true\\n","module":"Ash.Query.Function.StringEndsWith","name":"string_ends_with","predicate":true,"returns":{"kind":"concrete","type_ref":"Ash.Type.Boolean"},"signatures":[{"args":[{"kind":"concrete","type_ref":"Ash.Type.String"},{"kind":"concrete","type_ref":"Ash.Type.String"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.String"},{"kind":"concrete","type_ref":"Ash.Type.CiString"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.CiString"},{"kind":"concrete","type_ref":"Ash.Type.String"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.CiString"},{"kind":"concrete","type_ref":"Ash.Type.CiString"}]}]},{"description":"Joins a list of values.\\n\\nIgnores `nil` values and concatenates the remaining non-nil values. An optional\\njoiner can be provided.\\n\\n    string_join([first_name, last_name], \\" \\")\\n\\n    string_join([item_a, item_b])\\n","module":"Ash.Query.Function.StringJoin","name":"string_join","predicate":false,"returns":{"kind":"concrete","type_ref":"Ash.Type.String"},"signatures":[{"args":[{"kind":"array","of":{"kind":"concrete","type_ref":"Ash.Type.String"}}]},{"args":[{"kind":"array","of":{"kind":"concrete","type_ref":"Ash.Type.String"}},{"kind":"concrete","type_ref":"Ash.Type.String"}]},{"args":[{"kind":"array","of":{"kind":"concrete","type_ref":"Ash.Type.String"}},{"kind":"concrete","type_ref":"Ash.Type.CiString"}]},{"args":[{"kind":"array","of":{"kind":"concrete","type_ref":"Ash.Type.CiString"}}]},{"args":[{"kind":"array","of":{"kind":"concrete","type_ref":"Ash.Type.CiString"}},{"kind":"concrete","type_ref":"Ash.Type.CiString"}]}]},{"description":"Returns the length of a string.\\n\\nWithout a unit argument, the length is counted in codepoints, unless the\\nbackwards-compatibility key `config :ash, :default_string_length_count` is set to\\n`:mixed`, in which case it is counted in graphemes (see the backwards compatibility\\nguide). An optional second argument selects a unit explicitly:\\n\\n- `:graphemes` - counts unicode graphemes, i.e `String.length/1`.\\n- `:codepoints` - counts unicode codepoints. This matches how most SQL data layers\\n  count the length of a string.\\n- `:bytes` - counts bytes, i.e `byte_size/1`.\\n\\nA single grapheme may be made up of an unbounded number of codepoints\\n(e.g. a base character followed by many combining marks), so counting graphemes\\nplaces no effective bound on the size of a value. Use `:codepoints` or `:bytes`\\nwhen the length is being used as a limit.\\n\\nData layers cannot count graphemes, so `:graphemes` is only supported where the\\nexpression is evaluated in Elixir. Note that `string_length/1` is translated to the\\ndata layer\'s native length function, which counts codepoints, regardless of the\\nconfigured default.\\n\\n    string_length(name)\\n    string_length(name, :bytes)\\n","module":"Ash.Query.Function.StringLength","name":"string_length","predicate":false,"returns":{"kind":"concrete","type_ref":"Ash.Type.Integer"},"signatures":[{"args":[{"kind":"concrete","type_ref":"Ash.Type.String"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.CiString"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.String"},{"constraints":"[one_of: [:graphemes, :codepoints, :bytes]]","kind":"concrete","type_ref":"Ash.Type.Atom"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.CiString"},{"constraints":"[one_of: [:graphemes, :codepoints, :bytes]]","kind":"concrete","type_ref":"Ash.Type.Atom"}]}]},{"description":"Returns the zero-based position of a substring within a string, nil if the string does not contain the substring.\\n\\nCase insensitive strings are accounted for on either side.\\n\\n   string_position(\\"foo\\", \\"fo\\")\\n   0\\n\\n   string_position(%Ash.CiString{string: \\"foo\\"}, \\"FoO\\")\\n   0\\n\\n   string_position(\\"foo\\", %Ash.CiString{string: \\"FOO\\"})\\n   0\\n","module":"Ash.Query.Function.StringPosition","name":"string_position","predicate":false,"returns":{"kind":"concrete","type_ref":"Ash.Type.Integer"},"signatures":[{"args":[{"kind":"concrete","type_ref":"Ash.Type.String"},{"kind":"concrete","type_ref":"Ash.Type.String"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.String"},{"kind":"concrete","type_ref":"Ash.Type.CiString"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.CiString"},{"kind":"concrete","type_ref":"Ash.Type.String"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.CiString"},{"kind":"concrete","type_ref":"Ash.Type.CiString"}]}]},{"description":"Split a string into a list of strings\\n\\nSplits a string on the given delimiter. The delimiter defaults to a single space. Also supports options.\\n\\nKeep in mind, this function does *not* support regexes the way that `String.split/3` does, only raw strings.\\n\\n    string_split(employee_code)\\n    string_split(full_name, \\"foo\\")\\n    string_split(full_name, \\"foo\\", trim?: true)\\n\\n## Options\\n\\n* `:trim?` (`t:boolean/0`) - Whether or not to trim empty strings from the beginning or end of the result. Equivalent to the `trim` option to `String.split/3` The default value is `false`.\\n\\n\\n","module":"Ash.Query.Function.StringSplit","name":"string_split","predicate":false,"returns":{"kind":"concrete","type_ref":"Ash.Type.String"},"signatures":[{"args":[{"kind":"concrete","type_ref":"Ash.Type.String"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.String"},{"kind":"concrete","type_ref":"Ash.Type.String"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.String"},{"kind":"concrete","type_ref":"Ash.Type.String"},{"constraints":"[fields: [trim?: [type: :boolean, default: false, doc: \\"Whether or not to trim empty strings from the beginning or end of the result. Equivalent to the `trim` option to `String.split/3`\\"]]]","kind":"concrete","type_ref":"Ash.Type.Keyword"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.CiString"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.CiString"},{"kind":"concrete","type_ref":"Ash.Type.String"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.CiString"},{"kind":"concrete","type_ref":"Ash.Type.CiString"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.CiString"},{"kind":"concrete","type_ref":"Ash.Type.String"},{"constraints":"[fields: [trim?: [type: :boolean, default: false, doc: \\"Whether or not to trim empty strings from the beginning or end of the result. Equivalent to the `trim` option to `String.split/3`\\"]]]","kind":"concrete","type_ref":"Ash.Type.Keyword"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.CiString"},{"kind":"concrete","type_ref":"Ash.Type.CiString"},{"constraints":"[fields: [trim?: [type: :boolean, default: false, doc: \\"Whether or not to trim empty strings from the beginning or end of the result. Equivalent to the `trim` option to `String.split/3`\\"]]]","kind":"concrete","type_ref":"Ash.Type.Keyword"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.String"},{"kind":"concrete","type_ref":"Ash.Type.CiString"},{"constraints":"[fields: [trim?: [type: :boolean, default: false, doc: \\"Whether or not to trim empty strings from the beginning or end of the result. Equivalent to the `trim` option to `String.split/3`\\"]]]","kind":"concrete","type_ref":"Ash.Type.Keyword"}]}]},{"description":"Returns true if the first string starts with the second.\\n\\nCase insensitive strings are accounted for on either side.\\n\\n   string_starts_with(\\"foo\\", \\"fo\\")\\n   true\\n\\n   string_starts_with(%Ash.CiString{string: \\"foo\\"}, \\"FoO\\")\\n   false\\n\\n   string_starts_with(%Ash.CiString{string: \\"foo\\"}, \\"Fo\\")\\n   true\\n","module":"Ash.Query.Function.StringStartsWith","name":"string_starts_with","predicate":true,"returns":{"kind":"concrete","type_ref":"Ash.Type.Boolean"},"signatures":[{"args":[{"kind":"concrete","type_ref":"Ash.Type.String"},{"kind":"concrete","type_ref":"Ash.Type.String"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.String"},{"kind":"concrete","type_ref":"Ash.Type.CiString"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.CiString"},{"kind":"concrete","type_ref":"Ash.Type.String"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.CiString"},{"kind":"concrete","type_ref":"Ash.Type.CiString"}]}]},{"description":"Trims whitespace from a string\\n","module":"Ash.Query.Function.StringTrim","name":"string_trim","predicate":false,"returns":{"kind":"concrete","type_ref":"Ash.Type.String"},"signatures":[{"args":[{"kind":"concrete","type_ref":"Ash.Type.String"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.CiString"}]}]}],"operators":[{"aliases":[],"description":"left is_nil true/false\\n\\nThis predicate matches if the left is nil when the right is `true` or if the\\nleft is not nil when the right is `false`\\n","module":"Ash.Query.Operator.IsNil","name":"is_nil","predicate":true,"returns":{"kind":"concrete","type_ref":"Ash.Type.Boolean"},"signatures":[{"args":[{"kind":"any"},{"kind":"concrete","type_ref":"Ash.Type.Boolean"}]}]},{"aliases":["eq"],"description":"left == right\\n\\nThe simplest operator, matches if the left and right are equal.\\n\\nFor comparison, this compares as mutually exclusive with other equality\\nand `is_nil` checks that have the same reference on the left side\\n","module":"Ash.Query.Operator.Eq","name":"==","predicate":true,"returns":{"kind":"concrete","type_ref":"Ash.Type.Boolean"},"signatures":[{"args":[{"kind":"any"}]},{"args":[{"kind":"same"}]}]},{"aliases":["not_eq"],"description":"left != right\\n\\nIn comparison, simplifies to `not(left == right)`\\n","module":"Ash.Query.Operator.NotEq","name":"!=","predicate":true,"returns":{"kind":"concrete","type_ref":"Ash.Type.Boolean"},"signatures":[{"args":[{"kind":"same"}]},{"args":[{"kind":"any"}]}]},{"aliases":[],"description":"left in [1, 2, 3]\\n\\nthis predicate matches if the left is in the list on the right\\n\\nFor comparison, this simplifies to a set of \\"or equals\\", e.g\\n`{:or, {:or, {:or, left == 1}, left == 2}, left == 3}`\\n","module":"Ash.Query.Operator.In","name":"in","predicate":true,"returns":{"kind":"concrete","type_ref":"Ash.Type.Boolean"},"signatures":[{"args":[{"kind":"any"},{"kind":"array","of":{"kind":"same"}}]}]},{"aliases":["less_than"],"description":"left < right\\n\\nDoes not simplify, but is used as the simplification value for\\n`Ash.Query.Operator.LessThanOrEqual`, `Ash.Query.Operator.GreaterThan` and\\n`Ash.Query.Operator.GreaterThanOrEqual`.\\n\\nWhen comparing predicates, it is mutually exclusive with `Ash.Query.Operator.IsNil`.\\nAdditionally, it compares as mutually inclusive with any `Ash.Query.Operator.Eq` and\\nany `Ash.Query.Operator.LessThan` who\'s right sides are less than it, and mutually\\nexclusive with any `Ash.Query.Operator.Eq` or `Ash.Query.Operator.GreaterThan` who\'s\\nright side\'s are greater than or equal to it.\\n","module":"Ash.Query.Operator.LessThan","name":"<","predicate":true,"returns":{"kind":"concrete","type_ref":"Ash.Type.Boolean"},"signatures":[{"args":[{"kind":"same"}]},{"args":[{"kind":"any"}]}]},{"aliases":["greater_than"],"description":"left > right\\n\\nIn comparison, simplifies to `not(left < right + 1)`, so it will never need to be compared against.\\n","module":"Ash.Query.Operator.GreaterThan","name":">","predicate":true,"returns":{"kind":"concrete","type_ref":"Ash.Type.Boolean"},"signatures":[{"args":[{"kind":"same"}]},{"args":[{"kind":"any"}]}]},{"aliases":["less_than_or_equal"],"description":"left <= right\\n\\nIn comparison, simplifies to `left < right + 1`, so it will never need to be compared against.\\n","module":"Ash.Query.Operator.LessThanOrEqual","name":"<=","predicate":true,"returns":{"kind":"concrete","type_ref":"Ash.Type.Boolean"},"signatures":[{"args":[{"kind":"same"}]},{"args":[{"kind":"any"}]}]},{"aliases":["greater_than_or_equal"],"description":"left >= right\\n\\nIn comparison, simplifies to `not(left < right)`, so it will never need to be compared against.\\n","module":"Ash.Query.Operator.GreaterThanOrEqual","name":">=","predicate":true,"returns":{"kind":"concrete","type_ref":"Ash.Type.Boolean"},"signatures":[{"args":[{"kind":"same"}]},{"args":[{"kind":"any"}]}]},{"aliases":["and"],"module":"Ash.Query.Operator.Basic.And","name":"&&","predicate":false,"returns":{"kind":"same"},"signatures":[{"args":[{"kind":"same"},{"kind":"any"}]}]},{"aliases":["or"],"module":"Ash.Query.Operator.Basic.Or","name":"||","predicate":false,"returns":{"kind":"same"},"signatures":[{"args":[{"kind":"same"},{"kind":"any"}]}]},{"aliases":["concat"],"module":"Ash.Query.Operator.Basic.Concat","name":"<>","predicate":false,"returns":{"kind":"concrete","type_ref":"Ash.Type.String"},"signatures":[{"args":[{"kind":"concrete","type_ref":"Ash.Type.String"},{"kind":"concrete","type_ref":"Ash.Type.String"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.CiString"},{"kind":"concrete","type_ref":"Ash.Type.CiString"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.String"},{"kind":"concrete","type_ref":"Ash.Type.CiString"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.CiString"},{"kind":"concrete","type_ref":"Ash.Type.String"}]}]},{"aliases":["div"],"module":"Ash.Query.Operator.Basic.Div","name":"/","predicate":false,"returns":{"kind":"concrete","type_ref":"Ash.Type.Float"},"signatures":[{"args":[{"kind":"concrete","type_ref":"Ash.Type.Float"},{"kind":"concrete","type_ref":"Ash.Type.Float"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.Decimal"},{"kind":"concrete","type_ref":"Ash.Type.Decimal"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.Float"},{"kind":"concrete","type_ref":"Ash.Type.Decimal"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.Decimal"},{"kind":"concrete","type_ref":"Ash.Type.Float"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.Integer"},{"kind":"concrete","type_ref":"Ash.Type.Integer"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.Integer"},{"kind":"concrete","type_ref":"Ash.Type.Float"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.Integer"},{"kind":"concrete","type_ref":"Ash.Type.Decimal"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.Float"},{"kind":"concrete","type_ref":"Ash.Type.Integer"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.Decimal"},{"kind":"concrete","type_ref":"Ash.Type.Integer"}]}]},{"aliases":["minus"],"module":"Ash.Query.Operator.Basic.Minus","name":"-","predicate":false,"returns":{"kind":"same"},"signatures":[{"args":[{"kind":"same"},{"kind":"any"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.Duration"},{"kind":"concrete","type_ref":"Ash.Type.Duration"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.Date"},{"kind":"concrete","type_ref":"Ash.Type.Duration"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.Date"},{"kind":"concrete","type_ref":"Ash.Type.Date"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.DateTime"},{"kind":"concrete","type_ref":"Ash.Type.Duration"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.DateTime"},{"kind":"concrete","type_ref":"Ash.Type.DateTime"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.UtcDatetime"},{"kind":"concrete","type_ref":"Ash.Type.Duration"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.UtcDatetime"},{"kind":"concrete","type_ref":"Ash.Type.UtcDatetime"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.UtcDatetimeUsec"},{"kind":"concrete","type_ref":"Ash.Type.Duration"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.UtcDatetimeUsec"},{"kind":"concrete","type_ref":"Ash.Type.UtcDatetimeUsec"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.NaiveDatetime"},{"kind":"concrete","type_ref":"Ash.Type.Duration"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.NaiveDatetime"},{"kind":"concrete","type_ref":"Ash.Type.NaiveDatetime"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.Time"},{"kind":"concrete","type_ref":"Ash.Type.Duration"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.Time"},{"kind":"concrete","type_ref":"Ash.Type.Time"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.TimeUsec"},{"kind":"concrete","type_ref":"Ash.Type.Duration"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.TimeUsec"},{"kind":"concrete","type_ref":"Ash.Type.TimeUsec"}]}]},{"aliases":["times"],"module":"Ash.Query.Operator.Basic.Times","name":"*","predicate":false,"returns":{"kind":"same"},"signatures":[{"args":[{"kind":"same"},{"kind":"any"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.Duration"},{"kind":"concrete","type_ref":"Ash.Type.Integer"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.Integer"},{"kind":"concrete","type_ref":"Ash.Type.Duration"}]}]},{"aliases":["plus"],"module":"Ash.Query.Operator.Basic.Plus","name":"+","predicate":false,"returns":{"kind":"same"},"signatures":[{"args":[{"kind":"same"},{"kind":"any"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.Duration"},{"kind":"concrete","type_ref":"Ash.Type.Duration"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.Date"},{"kind":"concrete","type_ref":"Ash.Type.Duration"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.Duration"},{"kind":"concrete","type_ref":"Ash.Type.Date"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.DateTime"},{"kind":"concrete","type_ref":"Ash.Type.Duration"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.Duration"},{"kind":"concrete","type_ref":"Ash.Type.DateTime"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.UtcDatetime"},{"kind":"concrete","type_ref":"Ash.Type.Duration"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.Duration"},{"kind":"concrete","type_ref":"Ash.Type.UtcDatetime"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.UtcDatetimeUsec"},{"kind":"concrete","type_ref":"Ash.Type.Duration"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.Duration"},{"kind":"concrete","type_ref":"Ash.Type.UtcDatetimeUsec"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.NaiveDatetime"},{"kind":"concrete","type_ref":"Ash.Type.Duration"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.Duration"},{"kind":"concrete","type_ref":"Ash.Type.NaiveDatetime"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.Time"},{"kind":"concrete","type_ref":"Ash.Type.Duration"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.Duration"},{"kind":"concrete","type_ref":"Ash.Type.Time"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.TimeUsec"},{"kind":"concrete","type_ref":"Ash.Type.Duration"}]},{"args":[{"kind":"concrete","type_ref":"Ash.Type.Duration"},{"kind":"concrete","type_ref":"Ash.Type.TimeUsec"}]}]}],"predicate_custom_expressions":[],"predicate_functions":["contains","has","is_distinct_from","is_not_distinct_from","intersects","range_adjacent","range_contains","range_overlaps","string_ends_with","string_starts_with"],"predicate_operators":["is_nil","==","!=","in","<",">","<=",">="]},"resources":[{"embedded":false,"fields":{"cost_physical":{"allow_nil":false,"filter_custom_expressions":[],"filter_functions":[{"name":"is_distinct_from","rhs":"same"},{"name":"is_not_distinct_from","rhs":"same"},{"name":"range_adjacent","rhs":"same"},{"name":"range_contains","rhs":"any"},{"name":"range_overlaps","rhs":"same"}],"filter_operators":[{"name":"is_nil","rhs":{"concrete":"Ash.Type.Boolean"}},{"name":"==","rhs":"same"},{"name":"!=","rhs":"same"},{"name":"in","rhs":{"array":"same"}},{"name":"<","rhs":"same"},{"name":">","rhs":"same"},{"name":"<=","rhs":"same"},{"name":">=","rhs":"same"}],"filterable":true,"has_default":false,"kind":"attribute","primary_key":false,"select_by_default":true,"sensitive":false,"sortable":true,"type":{"allow_nil":null,"kind":"integer","module":"Ash.Type.Integer","name":"Integer"},"writable":true},"id":{"allow_nil":false,"filter_custom_expressions":[],"filter_functions":[{"name":"is_distinct_from","rhs":"same"},{"name":"is_not_distinct_from","rhs":"same"},{"name":"range_adjacent","rhs":"same"},{"name":"range_contains","rhs":"any"},{"name":"range_overlaps","rhs":"same"}],"filter_operators":[{"name":"is_nil","rhs":{"concrete":"Ash.Type.Boolean"}},{"name":"==","rhs":"same"},{"name":"!=","rhs":"same"},{"name":"in","rhs":{"array":"same"}},{"name":"<","rhs":"same"},{"name":">","rhs":"same"},{"name":"<=","rhs":"same"},{"name":">=","rhs":"same"}],"filterable":true,"has_default":true,"kind":"attribute","primary_key":true,"select_by_default":true,"sensitive":false,"sortable":true,"type":{"allow_nil":null,"kind":"uuid","module":"Ash.Type.UUID","name":"UUID"},"writable":false},"member_id":{"allow_nil":false,"filter_custom_expressions":[],"filter_functions":[{"name":"contains","rhs":{"concrete":"Ash.Type.String"}},{"name":"is_distinct_from","rhs":"same"},{"name":"is_not_distinct_from","rhs":"same"},{"name":"range_adjacent","rhs":"same"},{"name":"range_contains","rhs":"any"},{"name":"range_overlaps","rhs":"same"},{"name":"string_ends_with","rhs":{"concrete":"Ash.Type.String"}},{"name":"string_starts_with","rhs":{"concrete":"Ash.Type.String"}}],"filter_operators":[{"name":"is_nil","rhs":{"concrete":"Ash.Type.Boolean"}},{"name":"==","rhs":"same"},{"name":"!=","rhs":"same"},{"name":"in","rhs":{"array":"same"}},{"name":"<","rhs":"same"},{"name":">","rhs":"same"},{"name":"<=","rhs":"same"},{"name":">=","rhs":"same"}],"filterable":true,"has_default":false,"kind":"attribute","primary_key":false,"select_by_default":true,"sensitive":false,"sortable":true,"type":{"allow_nil":null,"kind":"string","module":"Ash.Type.String","name":"String"},"writable":true},"milestone_id":{"allow_nil":false,"filter_custom_expressions":[],"filter_functions":[{"name":"contains","rhs":{"concrete":"Ash.Type.String"}},{"name":"is_distinct_from","rhs":"same"},{"name":"is_not_distinct_from","rhs":"same"},{"name":"range_adjacent","rhs":"same"},{"name":"range_contains","rhs":"any"},{"name":"range_overlaps","rhs":"same"},{"name":"string_ends_with","rhs":{"concrete":"Ash.Type.String"}},{"name":"string_starts_with","rhs":{"concrete":"Ash.Type.String"}}],"filter_operators":[{"name":"is_nil","rhs":{"concrete":"Ash.Type.Boolean"}},{"name":"==","rhs":"same"},{"name":"!=","rhs":"same"},{"name":"in","rhs":{"array":"same"}},{"name":"<","rhs":"same"},{"name":">","rhs":"same"},{"name":"<=","rhs":"same"},{"name":">=","rhs":"same"}],"filterable":true,"has_default":false,"kind":"attribute","primary_key":false,"select_by_default":true,"sensitive":false,"sortable":true,"type":{"allow_nil":null,"kind":"string","module":"Ash.Type.String","name":"String"},"writable":true},"reward_spiritual":{"allow_nil":false,"filter_custom_expressions":[],"filter_functions":[{"name":"is_distinct_from","rhs":"same"},{"name":"is_not_distinct_from","rhs":"same"},{"name":"range_adjacent","rhs":"same"},{"name":"range_contains","rhs":"any"},{"name":"range_overlaps","rhs":"same"}],"filter_operators":[{"name":"is_nil","rhs":{"concrete":"Ash.Type.Boolean"}},{"name":"==","rhs":"same"},{"name":"!=","rhs":"same"},{"name":"in","rhs":{"array":"same"}},{"name":"<","rhs":"same"},{"name":">","rhs":"same"},{"name":"<=","rhs":"same"},{"name":">=","rhs":"same"}],"filterable":true,"has_default":false,"kind":"attribute","primary_key":false,"select_by_default":true,"sensitive":false,"sortable":true,"type":{"allow_nil":null,"kind":"integer","module":"Ash.Type.Integer","name":"Integer"},"writable":true},"status":{"allow_nil":true,"filter_custom_expressions":[],"filter_functions":[{"name":"contains","rhs":{"concrete":"Ash.Type.String"}},{"name":"is_distinct_from","rhs":"same"},{"name":"is_not_distinct_from","rhs":"same"},{"name":"range_adjacent","rhs":"same"},{"name":"range_contains","rhs":"any"},{"name":"range_overlaps","rhs":"same"},{"name":"string_ends_with","rhs":{"concrete":"Ash.Type.String"}},{"name":"string_starts_with","rhs":{"concrete":"Ash.Type.String"}}],"filter_operators":[{"name":"is_nil","rhs":{"concrete":"Ash.Type.Boolean"}},{"name":"==","rhs":"same"},{"name":"!=","rhs":"same"},{"name":"in","rhs":{"array":"same"}},{"name":"<","rhs":"same"},{"name":">","rhs":"same"},{"name":"<=","rhs":"same"},{"name":">=","rhs":"same"}],"filterable":true,"has_default":true,"kind":"attribute","primary_key":false,"select_by_default":true,"sensitive":false,"sortable":true,"type":{"allow_nil":null,"kind":"string","module":"Ash.Type.String","name":"String"},"writable":true}},"module":"AshSurface.Fixtures.VolunteerMilestone","name":"VolunteerMilestone","primary_key":["id"],"relationships":{}}],"schema_version":"1.0.0","sort_capabilities":{"directions":["asc","desc","asc_nils_first","asc_nils_last","desc_nils_first","desc_nils_last"]},"types":[]},"manifestDigest":"16c773c875e188774bdf159744864cd4b5eaf86d7f68c66d89c40a72ba5a0665","marketplaceIdentity":"ggen-marketplace:v26.9.17","surface":{"actions":[{"action":"record","authorityBoundary":null,"doAuthority":null,"evidenceRequired":false,"id":"AshSurface.Fixtures.VolunteerMilestone#record","possibleRefusals":[],"profile":{},"receiptRequired":null,"resource":"AshSurface.Fixtures.VolunteerMilestone","semanticId":null}],"profile":{}},"surfaceSchemaVersion":"26.9.17"}',
  },
  {
    name: "F5 IR-era envelope extensions + ETF boundary values through passthrough",
    elixirDigest: "6bb3092a3b5aa86248cd79e67294473b007d8ef4d10b59585b3d32ea4b36b13f",
    contractJson:
      '{"applicationReleaseIdentity":"ash-surface-wt/v43@282f3ca","ashManifestSchemaVersion":"1.0.0","generatorIdentity":"ash_surface:v26.9.17","manifest":{"entrypoints":[{"action":{"get":null,"inputs":[],"metadata":[],"primary":null,"type":"read"},"resource":"AshSurface.Fixtures.VolunteerMilestone"},{"action":{"get":null,"inputs":[],"metadata":[],"primary":null,"type":"create"},"resource":"AshSurface.Fixtures.VolunteerMilestone"}],"resources":[],"schema_version":"1.0.0","types":[]},"manifestDigest":"af93be319ad1444518422a97f02f345dfba8e076445ec77d18e69e530d3e477a","marketplaceIdentity":"ggen-marketplace:v26.9.17","ontologyDigest":"85e9ee6c4aca8091953e325969b78199363c6add1e2d95e0b070d234cbd9f887","surface":{"actions":[{"action":"read","authorityBoundary":"OBSERVE","doAuthority":false,"evidenceRequired":false,"id":"AshSurface.Fixtures.VolunteerMilestone#read","possibleRefusals":[],"profile":{},"receiptRequired":true,"resource":"AshSurface.Fixtures.VolunteerMilestone","semanticId":"ash:AshSurface.Fixtures.VolunteerMilestone#read"},{"action":"record","authorityBoundary":"DO","doAuthority":true,"evidenceRequired":false,"id":"AshSurface.Fixtures.VolunteerMilestone#record","irRef":"ir:26.9.17:record","possibleRefusals":[],"profile":{},"receiptRequired":true,"resource":"AshSurface.Fixtures.VolunteerMilestone","semanticId":"ash:AshSurface.Fixtures.VolunteerMilestone#record"}],"presentation":{"irRef":"ir:26.9.17:surface","sections":["identity","authority"]},"profile":{"bounds":{"i8max":255,"i8max1":256,"int32min":-2147483648,"int32min1":-2147483649,"negbig":-9876543210},"empty":{"list":[],"map":{}},"flags":[true,false,null],"floats":[0.125,-0.5],"glyph":"Σ🜂✓","note":""}},"surfaceSchemaVersion":"26.9.17"}',
  },
  {
    name: "F6 per-action authority overrides (CONSTRUCT, refusals, safe-int ceiling)",
    elixirDigest: "3ff07988feec581c25b4b8670bffa48b28b8f2d6fadcd01887f6e60a0f446469",
    contractJson:
      '{"ashManifestSchemaVersion":"1.0.0","generatorIdentity":"ash_surface:v26.9.17","manifest":{"entrypoints":[{"action":{"get":null,"inputs":[],"metadata":[],"primary":null,"type":"read"},"resource":"AshSurface.Fixtures.VolunteerMilestone"},{"action":{"get":null,"inputs":[],"metadata":[],"primary":null,"type":"create"},"resource":"AshSurface.Fixtures.VolunteerMilestone"}],"resources":[],"schema_version":"1.0.0","types":[]},"manifestDigest":"af93be319ad1444518422a97f02f345dfba8e076445ec77d18e69e530d3e477a","marketplaceIdentity":"ggen-marketplace:v26.9.17","surface":{"actions":[{"action":"read","authorityBoundary":"OBSERVE","doAuthority":false,"evidenceRequired":false,"id":"AshSurface.Fixtures.VolunteerMilestone#read","possibleRefusals":[],"profile":{},"receiptRequired":true,"resource":"AshSurface.Fixtures.VolunteerMilestone","semanticId":"ash:AshSurface.Fixtures.VolunteerMilestone#read"},{"action":"record","authorityBoundary":"CONSTRUCT","doAuthority":false,"evidenceRequired":true,"id":"AshSurface.Fixtures.VolunteerMilestone#record","possibleRefusals":["REFUSED_NO_AUTHORITY"],"profile":{"authorityBoundary":"CONSTRUCT","doAuthority":false,"evidenceRequired":true,"possibleRefusals":["REFUSED_NO_AUTHORITY"],"quota":9007199254740991,"receiptRequired":false},"receiptRequired":false,"resource":"AshSurface.Fixtures.VolunteerMilestone","semanticId":"ash:AshSurface.Fixtures.VolunteerMilestone#record"}],"profile":{"tier":"v43"}},"surfaceSchemaVersion":"26.9.17"}',
  },
];

/** t26's pinned digests; the v2 fixtures must deepen, never re-pin them. */
const T26_DIGESTS = new Set([
  "1d2f78480ad8261b83dd7182fc84aa54aa833f58fc813939a713c16d9d9f2d5f",
  "ddb95be74b2ce5b78fbe5ce8d14807d2af75426083cb0623abb587ff827cbbf1",
  "c4f7b471c2ae774ccc97d9ec64c7c9476ac291d4e88efcd3f0bfd8d94524e0b0",
]);

/** Marker for map entries, which canonical_term/1 turns into 2-tuples. */
class EtfTuple {
  constructor(elements) {
    this.elements = elements;
  }
}

function byUtf8Bytes(a, b) {
  return Buffer.compare(Buffer.from(a, "utf8"), Buffer.from(b, "utf8"));
}

/** Mirrors AshSurface.canonical_term/1: lists map element-wise, maps become
 * key-sorted lists of {string_key, value} tuples, leaves pass through. */
function canonicalTerm(value) {
  if (Array.isArray(value)) return value.map(canonicalTerm);
  if (value !== null && typeof value === "object") {
    return Object.keys(value)
      .sort(byUtf8Bytes)
      .map((key) => new EtfTuple([key, canonicalTerm(value[key])]));
  }
  return value;
}

function encodeBinary(value, chunks) {
  const bytes = Buffer.from(value, "utf8");
  const length = Buffer.alloc(4);
  length.writeUInt32BE(bytes.length);
  chunks.push(Buffer.from([0x6d]), length, bytes);
}

function encodeSmallAtomUtf8(name, chunks) {
  const bytes = Buffer.from(name, "utf8");
  if (bytes.length > 255) throw new Error(`atom too long for SMALL_ATOM_UTF8: ${name}`);
  chunks.push(Buffer.from([0x77, bytes.length]), bytes);
}

function encodeInteger(value, chunks) {
  if (value >= 0 && value <= 255) {
    chunks.push(Buffer.from([0x61, value]));
  } else if (value >= -2147483648 && value <= 2147483647) {
    const buffer = Buffer.alloc(5);
    buffer[0] = 0x62;
    buffer.writeInt32BE(value, 1);
    chunks.push(buffer);
  } else {
    const magnitude = BigInt(value < 0 ? -value : value);
    const digits = [];
    for (let mag = magnitude; mag > 0n; mag >>= 8n) digits.push(Number(mag & 0xffn));
    chunks.push(Buffer.from([0x6e, digits.length, value < 0 ? 1 : 0]), Buffer.from(digits));
  }
}

function encodeTerm(value, chunks) {
  if (value === null) return encodeSmallAtomUtf8("nil", chunks);
  if (value === true) return encodeSmallAtomUtf8("true", chunks);
  if (value === false) return encodeSmallAtomUtf8("false", chunks);
  if (typeof value === "string") return encodeBinary(value, chunks);
  if (typeof value === "number") {
    if (Number.isInteger(value) && Number.isSafeInteger(value)) return encodeInteger(value, chunks);
    const buffer = Buffer.alloc(9);
    buffer[0] = 0x46;
    buffer.writeDoubleBE(value, 1);
    chunks.push(buffer);
    return;
  }
  if (value instanceof EtfTuple) {
    chunks.push(Buffer.from([0x68, value.elements.length]));
    for (const element of value.elements) encodeTerm(element, chunks);
    return;
  }
  if (Array.isArray(value)) {
    if (value.length === 0) {
      chunks.push(Buffer.from([0x6a]));
      return;
    }
    const length = Buffer.alloc(4);
    length.writeUInt32BE(value.length);
    chunks.push(Buffer.from([0x6c]), length);
    for (const element of value) encodeTerm(element, chunks);
    chunks.push(Buffer.from([0x6a]));
    return;
  }
  throw new Error(`value is not part of the canonical contract term space: ${typeof value}`);
}

/** SHA-256 over :erlang.term_to_binary/1 encoding of the canonical term. */
function contractDigest(contract) {
  const chunks = [Buffer.from([0x83])];
  encodeTerm(canonicalTerm(contract), chunks);
  return crypto.createHash("sha256").update(Buffer.concat(chunks)).digest("hex");
}

/** Reverses key insertion order at every object depth (arrays mapped through). */
function reverseKeyOrder(value) {
  if (Array.isArray(value)) return value.map(reverseKeyOrder);
  if (value !== null && typeof value === "object") {
    const reversed = {};
    for (const key of Object.keys(value).reverse()) reversed[key] = reverseKeyOrder(value[key]);
    return reversed;
  }
  return value;
}

function clientFor(fixture, transform = (contract) => contract) {
  return createClient({ contract: transform(JSON.parse(fixture.contractJson)) });
}

test("runtime-held contract digest equals the Elixir-computed golden for every fixture", () => {
  for (const fixture of GOLDENS) {
    const client = clientFor(fixture);
    assert.equal(client.runtimeVersion, "26.9.17", `${fixture.name}: runtime version`);
    assert.equal(contractDigest(client.contract), fixture.elixirDigest, fixture.name);
  }
});

test("golden digests are 64-character lowercase hex, pairwise distinct, and none re-pins t26", () => {
  const seen = new Set();
  for (const fixture of GOLDENS) {
    assert.match(fixture.elixirDigest, /^[0-9a-f]{64}$/, fixture.name);
    assert.equal(T26_DIGESTS.has(fixture.elixirDigest), false, `${fixture.name}: duplicates t26`);
    assert.equal(seen.has(fixture.elixirDigest), false, `${fixture.name}: duplicates another v2 fixture`);
    seen.add(fixture.elixirDigest);
  }
});

test("F4: the digest subject is the runtime-normalized contract, not the raw JSON", () => {
  const fixture = GOLDENS[0];
  // Strip every action/surface field the Zod schema defaults; the runtime
  // must re-materialize exactly the values Elixir emitted (the fields whose
  // Elixir defaults equal the Zod defaults), leaving the digest untouched.
  const stripped = (contract) => {
    delete contract.surface.profile;
    for (const action of contract.surface.actions) {
      delete action.authorityBoundary;
      delete action.doAuthority;
      delete action.receiptRequired;
      delete action.evidenceRequired;
      delete action.possibleRefusals;
      delete action.profile;
    }
    return contract;
  };

  const client = clientFor(fixture, stripped);
  assert.equal(
    contractDigest(client.contract),
    fixture.elixirDigest,
    "stripped contract re-normalized by the runtime must digest to the golden",
  );
  // Normalization is a fixpoint here: the complete JSON digests identically.
  assert.equal(contractDigest(clientFor(fixture).contract), fixture.elixirDigest);
});

test("F5: IR-era envelope extensions survive passthrough and participate in the digest", () => {
  const fixture = GOLDENS[1];
  const client = clientFor(fixture);

  assert.equal(client.contract.ontologyDigest, JSON.parse(fixture.contractJson).ontologyDigest);
  assert.equal(
    client.contract.applicationReleaseIdentity,
    "ash-surface-wt/v43@282f3ca",
    "optional envelope identity key kept by passthrough",
  );
  assert.deepEqual(client.contract.surface.presentation, {
    irRef: "ir:26.9.17:surface",
    sections: ["identity", "authority"],
  });
  assert.equal(
    client.contract.surface.actions.find((a) => a.action === "record").irRef,
    "ir:26.9.17:record",
    "per-action passthrough key kept in the digested contract",
  );

  // Removing one envelope extension flips the digest: it was inside the term.
  const withoutOntology = clientFor(fixture, (contract) => {
    delete contract.ontologyDigest;
    return contract;
  });
  assert.notEqual(contractDigest(withoutOntology.contract), fixture.elixirDigest);
});

test("digest is stable under deep key-order permutation for every fixture", () => {
  for (const fixture of GOLDENS) {
    const client = clientFor(fixture, reverseKeyOrder);
    assert.equal(contractDigest(client.contract), fixture.elixirDigest, fixture.name);
  }
});

test("a single field mutation flips the digest for every fixture", () => {
  const mutations = [
    (contract) => {
      const digest = contract.manifestDigest;
      contract.manifestDigest = digest.slice(0, -1) + (digest.endsWith("a") ? "b" : "a");
    },
    (contract) => {
      contract.surface.profile.glyph = "Σ🜂✗";
    },
    (contract) => {
      const record = contract.surface.actions.find((a) => a.action === "record");
      record.doAuthority = true;
    },
  ];

  for (const [index, fixture] of GOLDENS.entries()) {
    const client = clientFor(fixture, (contract) => {
      mutations[index](contract);
      return contract;
    });
    assert.notEqual(contractDigest(client.contract), fixture.elixirDigest, fixture.name);
  }
});
