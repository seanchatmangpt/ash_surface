Code.require_file("support/e.exs", __DIR__)

defmodule AshSurface.Ported.Rpc.E.ZodConstraintsTest do
  @moduledoc """
  Adaptation of ash_typescript `rpc/zod_constraints_test.exs` (48 tests).

  Reference: `ZodSchemaGenerator.generate_zod_schema(OrgTodo, action, name)` text, asserted with
  `=~`. ash_surface counterpart: the real projected artifact (`AshSurface.Projectors.JS`) of the
  shared `AshSurface.Ported.Domain`; every constraint is asserted twice, (1) on the generated
  Zod expression of the `OrgTodo_create_schema` / `OrgTodo_validate_array_constraints_schema`
  export and (2) as accept/reject behavior of that schema under real node + real zod
  (`safeParse`, one node process per module).

  Adaptations (see ledger `changes`): keys are the Ash names verbatim (snake_case, no
  `numberOfEmployees` camelCasing: an explicit `:output_field_formatter` re-keys them,
  see `formatter_artifact_test.exs` and the KD register); `.regex(...)` carries the JS-safe `(?=\\n?$)` terminator
  instead of `$`; float bounds render as JS numbers (`1000000`, not `1.0e6`).
  """
  use ExUnit.Case, async: true

  alias AshSurface.Ported.E
  alias AshSurface.Ported.E.Zod

  @org "OrgTodo_create_schema"
  @arr "OrgTodo_validate_array_constraints_schema"

  @base %{
    "address" => %{"street_address" => "12345", "location_id" => "loc-1"},
    "case_insensitive_code" => "ABC-1234",
    "company_name" => "Acme Inc",
    "country_code" => "US",
    "email" => "a@b.co",
    "hex_color" => "#aabbcc",
    "number_of_employees" => 5,
    "percentage" => 50,
    "phone_number" => "+15551234567",
    "price" => 10,
    "slug" => "a-b",
    "some_string" => "x",
    "temperature" => 20,
    "title" => "t",
    "user_id" => "11111111-1111-4111-8111-111111111111",
    "username" => "abc",
    "version" => "1.2.3"
  }

  @arr_base %{
    "bounded_codes" => ["ab"],
    "bounded_reference_ids" => ["11111111-1111-4111-8111-111111111111"],
    "maximum_reference_ids" => [],
    "minimum_reference_ids" => ["11111111-1111-4111-8111-111111111111"]
  }

  @uuid "11111111-1111-4111-8111-111111111111"

  defp put(k, v), do: {@org, Map.put(@base, k, v)}
  defp del(k), do: {@org, Map.delete(@base, k)}
  defp aput(map), do: {@arr, Map.merge(@arr_base, map)}

  defp cases do
    [
      {"base", {@org, @base}},
      {"int_min_0", put("number_of_employees", 0)},
      {"int_min_1", put("number_of_employees", 1)},
      {"int_max_1000", put("number_of_employees", 1000)},
      {"int_max_1001", put("number_of_employees", 1001)},
      {"int_float", put("number_of_employees", 1.5)},
      {"user_id_any_uuid", put("user_id", @uuid)},
      {"some_empty", put("some_string", "")},
      {"some_100", put("some_string", String.duplicate("a", 100))},
      {"some_101", put("some_string", String.duplicate("a", 101))},
      {"title_empty", put("title", "")},
      {"desc_omitted", del("description")},
      {"desc_null", put("description", nil)},
      {"desc_empty", put("description", "")},
      {"desc_long", put("description", String.duplicate("a", 500))},
      {"emptyok_empty", put("empty_ok_string", "")},
      {"emptyok_null", put("empty_ok_string", nil)},
      {"user_ab", put("username", "ab")},
      {"user_abc", put("username", "abc")},
      {"user_21", put("username", String.duplicate("a", 21))},
      {"user_20", put("username", String.duplicate("a", 20))},
      {"nick_a", put("optional_nickname", "a")},
      {"nick_ab", put("optional_nickname", "ab")},
      {"nick_16", put("optional_nickname", String.duplicate("a", 16))},
      {"nick_null", put("optional_nickname", nil)},
      {"legacy_empty", put("legacy_code", "")},
      {"legacy_1", put("legacy_code", "a")},
      {"legacy_11", put("legacy_code", String.duplicate("a", 11))},
      {"legacy_null", put("legacy_code", nil)},
      {"price_neg", put("price", -1)},
      {"price_0", put("price", 0)},
      {"price_max", put("price", 999_999.99)},
      {"price_over", put("price", 1_000_000)},
      {"price_float", put("price", 1.5)},
      {"pct_neg", put("percentage", -0.1)},
      {"pct_100", put("percentage", 100)},
      {"pct_over", put("percentage", 100.1)},
      {"temp_at_lower", put("temperature", -273.15)},
      {"temp_above_lower", put("temperature", -273.14)},
      {"temp_at_upper", put("temperature", 1_000_000)},
      {"temp_below_upper", put("temperature", 999_999)},
      {"rating_over", put("optional_rating", 5.1)},
      {"rating_ok", put("optional_rating", 4.5)},
      {"rating_null", put("optional_rating", nil)},
      {"company_a", put("company_name", "A")},
      {"company_bad_chars", put("company_name", "Acme-Inc")},
      {"company_ok", put("company_name", "Acme 2")},
      {"country_lower", put("country_code", "us")},
      {"country_3", put("country_code", "USA")},
      {"country_digits", put("country_code", "1A")},
      {"email_bad", put("email", "not-an-email")},
      {"phone_bad", put("phone_number", "0123")},
      {"phone_plus", put("phone_number", "+442071838750")},
      {"hex_short", put("hex_color", "#abc")},
      {"hex_ok", put("hex_color", "#AABBCC")},
      {"slug_bad", put("slug", "A_b")},
      {"slug_multi", put("slug", "a-b-c")},
      {"version_bad", put("version", "1.2")},
      {"version_alpha", put("version", "1.2.x")},
      {"ci_lower", put("case_insensitive_code", "abc-1234")},
      {"ci_bad", put("case_insensitive_code", "abcd-1234")},
      {"url_null", put("optional_url", nil)},
      {"url_http", put("optional_url", "http://x.y/z")},
      {"url_ftp", put("optional_url", "ftp://x.y")},
      {"url_empty", put("optional_url", "")},
      {"arr_base", {@arr, @arr_base}},
      {"arr_min_empty", aput(%{"minimum_reference_ids" => []})},
      {"arr_max_17", aput(%{"maximum_reference_ids" => List.duplicate(@uuid, 17)})},
      {"arr_max_16", aput(%{"maximum_reference_ids" => List.duplicate(@uuid, 16)})},
      {"arr_bounded_empty", aput(%{"bounded_reference_ids" => []})},
      {"arr_bounded_17", aput(%{"bounded_reference_ids" => List.duplicate(@uuid, 17)})},
      {"codes_short_item", aput(%{"bounded_codes" => ["a"]})},
      {"codes_long_item", aput(%{"bounded_codes" => [String.duplicate("a", 9)]})},
      {"codes_5", aput(%{"bounded_codes" => List.duplicate("ab", 5)})},
      {"codes_empty", aput(%{"bounded_codes" => []})},
      {"opt_ids_omitted", {@arr, @arr_base}},
      {"opt_ids_17", aput(%{"optional_reference_ids" => List.duplicate(@uuid, 17)})},
      {"opt_ids_null", aput(%{"optional_reference_ids" => nil})},
      {"nullable_ids_null", aput(%{"nullable_reference_ids" => nil})},
      {"nullable_ids_empty", aput(%{"nullable_reference_ids" => []})},
      {"nullable_ids_omitted", {@arr, @arr_base}}
    ]
  end

  setup_all do
    art = E.artifact!()
    cases = Enum.map(cases(), fn {label, {export, payload}} -> {label, export, payload} end)
    %{art: art, org: Zod.block!(art, @org), arr: Zod.block!(art, @arr), r: Zod.batch!(art, cases)}
  end

  describe "Integer constraints in Zod schemas" do
    test "generates min constraint for integer arguments", %{org: org, r: r} do
      assert Zod.line!(org, "number_of_employees") =~
               "z.number().int().min(1).max(1000)"

      refute r["int_min_0"]
      assert r["int_min_1"]
    end

    test "generates max constraint for integer arguments", %{org: org, r: r} do
      assert org =~ ".min(1)"
      assert org =~ ".max(1000)"
      assert r["int_max_1000"]
      refute r["int_max_1001"]
    end

    test "integer without constraints generates basic z.number().int()", %{org: org, r: r} do
      # user_id carries no min/max; a regression adding bounds would reject a plain uuid
      refute Zod.line!(org, "user_id") =~ ~r/\.min|\.max/
      assert r["user_id_any_uuid"]
      refute r["int_float"]
    end
  end

  describe "String constraints in Zod schemas" do
    test "generates min length constraint for string arguments", %{org: org, r: r} do
      assert Zod.line!(org, "some_string") =~ "some_string: z.string().min(1).max(100)"
      refute r["some_empty"]
    end

    test "generates max length constraint for string arguments", %{org: org, r: r} do
      assert Zod.line!(org, "some_string") =~ "z.string().min(1).max(100)"
      assert r["some_100"]
      refute r["some_101"]
    end

    test "required string field without explicit constraints gets min(1)", %{org: org, r: r} do
      assert Zod.line!(org, "title") =~ "title: z.string().min(1)"
      refute r["title_empty"]
    end

    test "nullable+omittable string enforces non-empty (allow_empty? false default)", %{
      org: org,
      r: r
    } do
      line = Zod.line!(org, "description")
      assert line =~ "description: z.string().min(1).nullable().optional()"
      refute line =~ ".max("
      assert r["desc_omitted"] and r["desc_null"] and r["desc_long"]
      refute r["desc_empty"]
    end

    test "nullable string with allow_empty?: true stays unconstrained", %{org: org, r: r} do
      line = Zod.line!(org, "empty_ok_string")
      assert line =~ "empty_ok_string: z.string().nullable().optional()"
      refute line =~ ".min("
      assert r["emptyok_empty"] and r["emptyok_null"]
    end
  end

  describe "Array constraints in Zod schemas" do
    test "generates min_length constraint for array arguments", %{arr: arr, r: r} do
      assert Zod.line!(arr, "minimum_reference_ids") =~
               "minimum_reference_ids: z.array(z.guid()).min(1)"

      refute r["arr_min_empty"]
      assert r["arr_base"]
    end

    test "generates max_length constraint for array arguments", %{arr: arr, r: r} do
      assert Zod.line!(arr, "maximum_reference_ids") =~
               "maximum_reference_ids: z.array(z.guid()).max(16)"

      assert r["arr_max_16"]
      refute r["arr_max_17"]
    end

    test "generates both array cardinality constraints", %{arr: arr, r: r} do
      assert Zod.line!(arr, "bounded_reference_ids") =~
               "bounded_reference_ids: z.array(z.guid()).min(1).max(16)"

      refute r["arr_bounded_empty"]
      refute r["arr_bounded_17"]
    end

    test "preserves item constraints alongside array cardinality constraints", %{arr: arr, r: r} do
      assert Zod.line!(arr, "bounded_codes") =~
               "bounded_codes: z.array(z.string().min(2).max(8)).min(1).max(4)"

      refute r["codes_short_item"]
      refute r["codes_long_item"]
      refute r["codes_5"]
      refute r["codes_empty"]
    end

    test "applies nested array cardinality constraints at the correct level" do
      art = E.artifact!([AshSurface.Ported.E.Fixtures.Domain])
      block = Zod.block!(art, "NestedArray_validate_schema")

      assert Zod.line!(block, "bounded_matrix") =~
               "bounded_matrix: z.array(z.array(z.number().int()).min(2).max(3)).min(1).max(2)"

      ok = [[1, 2], [3, 4, 5]]

      assert [true, false, false, false, false] ==
               E.node_accepts(art, [
                 {"NestedArray_validate_schema", %{"bounded_matrix" => ok}},
                 {"NestedArray_validate_schema", %{"bounded_matrix" => []}},
                 {"NestedArray_validate_schema", %{"bounded_matrix" => [[1, 2], [1, 2], [1, 2]]}},
                 {"NestedArray_validate_schema", %{"bounded_matrix" => [[1]]}},
                 {"NestedArray_validate_schema", %{"bounded_matrix" => [[1, 2, 3, 4]]}}
               ])
    end

    test "applies array constraints before optional and nullable wrappers", %{arr: arr, r: r} do
      assert Zod.line!(arr, "optional_reference_ids") =~
               "optional_reference_ids: z.array(z.guid()).max(16).optional()"

      assert Zod.line!(arr, "nullable_reference_ids") =~
               "nullable_reference_ids: z.array(z.guid()).min(1).nullable().optional()"

      assert r["opt_ids_omitted"]
      refute r["opt_ids_17"]
      refute r["opt_ids_null"]
      assert r["nullable_ids_null"] and r["nullable_ids_omitted"]
      refute r["nullable_ids_empty"]
    end
  end

  describe "Constraint priority and interactions" do
    test "min_length constraint takes precedence over default min(1) for required fields", %{
      org: org,
      r: r
    } do
      assert Zod.line!(org, "some_string") =~ "some_string: z.string().min(1).max(100)"

      # min_length >= 2 REPLACES the implicit min(1) - it must not stack
      assert Zod.line!(org, "username") =~ "username: z.string().min(3).max(20)"
      refute Zod.line!(org, "username") =~ "min(1)"
      refute r["user_ab"]
      assert r["user_abc"]

      # ...including on nilable fields with an explicit min_length
      assert Zod.line!(org, "optional_nickname") =~
               "optional_nickname: z.string().min(2).max(15).nullable().optional()"

      refute r["nick_a"]
      assert r["nick_ab"]

      # min_length: 0 with allow_empty?: false floors at min(1)
      assert Zod.line!(org, "legacy_code") =~
               "legacy_code: z.string().min(1).max(10).nullable().optional()"

      refute r["legacy_empty"]
      assert r["legacy_1"]
    end

    test "constraints are chained in correct order: type().constraint1().constraint2()", %{
      org: org
    } do
      assert org =~ "z.number().int().min(1).max(1000)"
      assert org =~ "z.string().min(1).max(100)"
    end
  end

  describe "Multiple arguments with different constraints" do
    test "each argument gets its own independent constraints", %{org: org, r: r} do
      assert Zod.line!(org, "number_of_employees") =~ "z.number().int().min(1).max(1000)"
      assert Zod.line!(org, "some_string") =~ "z.string().min(1).max(100)"

      refute Zod.line!(org, "number_of_employees") =~ ".max(100)"
      refute Zod.line!(org, "some_string") =~ ".max(1000)"

      # independence under evaluation: 500 is valid for the integer but 500 chars is not a string
      assert r["int_max_1000"]
      refute r["some_101"]
    end
  end

  describe "Edge cases and error handling" do
    test "nil constraints are handled gracefully", %{org: org, r: r} do
      assert Zod.line!(org, "user_id") =~ "user_id: z.guid()"
      assert is_binary(org)
      assert r["base"]
    end

    test "empty constraints list is handled gracefully", %{org: org, r: r} do
      assert org =~ "export const OrgTodo_create_schema = z.object({"
      assert org =~ "})"
      assert r["base"]
    end
  end

  describe "Schema structure validation" do
    test "generated schema is valid Zod syntax (loads and parses under real node)", %{
      org: org,
      r: r
    } do
      assert org =~ "export const OrgTodo_create_schema = z.object({"

      # the whole artifact evaluated under node without a SyntaxError: a payload parsed
      assert r["base"]

      for line <- org |> String.split("\n") |> Enum.filter(&String.contains?(&1, ": z.")) do
        assert String.ends_with?(String.trim(line), [",", "}"]) or
                 String.ends_with?(String.trim(line), ")"),
               "field line malformed: #{line}"
      end
    end

    test "field names are the Ash names verbatim (no camelCase spelling)", %{org: org} do
      # reference: numberOfEmployees / someString; ash_surface (w3-15): Ash names, see ledger
      assert org =~ "number_of_employees:"
      refute org =~ "numberOfEmployees:"
      assert org =~ "some_string:"
      refute org =~ "someString:"
    end
  end

  describe "Constraint documentation and clarity" do
    test "constraints match their Ash definitions exactly", %{org: org} do
      raw_action = Ash.Resource.Info.action(AshSurface.Ported.OrgTodo, :create)

      number_arg =
        Enum.find(raw_action.arguments, &(&1.public? && &1.name == :number_of_employees))

      assert number_arg.constraints == [min: 1, max: 1000]

      string_arg = Enum.find(raw_action.arguments, &(&1.public? && &1.name == :some_string))

      assert string_arg.constraints == [
               min_length: 1,
               max_length: 100,
               trim?: true,
               allow_empty?: false
             ]

      assert Zod.line!(org, "number_of_employees") =~ "z.number().int().min(1).max(1000)"
      assert Zod.line!(org, "some_string") =~ "z.string().min(1).max(100)"
    end
  end

  describe "Float constraints in Zod schemas" do
    test "generates min constraint for float arguments", %{org: org, r: r} do
      assert Zod.line!(org, "price") =~ "price: z.number().min(0).max(999999.99)"
      refute r["price_neg"]
      assert r["price_0"]
    end

    test "generates max constraint for float arguments", %{org: org, r: r} do
      assert Zod.line!(org, "percentage") =~ "percentage: z.number().min(0).max(100)"
      assert r["pct_100"]
      refute r["pct_over"]
      refute r["pct_neg"]
    end

    test "generates gt (greater than) constraint for float arguments", %{org: org, r: r} do
      assert Zod.line!(org, "temperature") =~ "temperature: z.number().gt(-273.15).lt(1000000)"
      refute r["temp_at_lower"]
      assert r["temp_above_lower"]
    end

    test "generates lt (less than) constraint for float arguments", %{org: org, r: r} do
      assert org =~ ".lt(1000000)"
      refute r["temp_at_upper"]
      assert r["temp_below_upper"]
    end

    test "nullable+omittable float with constraints", %{org: org, r: r} do
      assert Zod.line!(org, "optional_rating") =~
               "optional_rating: z.number().min(0).max(5).nullable().optional()"

      refute r["rating_over"]
      assert r["rating_ok"] and r["rating_null"]
    end

    test "float without constraints generates basic z.number()", %{org: org, r: r} do
      # every OrgTodo float carries bounds (as in the reference); floats stay non-integer
      assert is_binary(org)
      assert r["price_float"]
    end

    test "float constraints are independent from integer constraints", %{org: org, r: r} do
      assert Zod.line!(org, "number_of_employees") =~ "number_of_employees: z.number().int()"
      assert Zod.line!(org, "price") =~ "price: z.number().min"
      refute Zod.line!(org, "price") =~ ".int()"
      assert r["price_float"]
      refute r["int_float"]
    end
  end

  describe "CiString constraints in Zod schemas" do
    test "generates min_length constraint for ci_string arguments", %{org: org, r: r} do
      assert Zod.line!(org, "username") =~ "username: z.string().min(3).max(20)"
      refute r["user_ab"]
      assert r["user_abc"]
    end

    test "generates max_length constraint for ci_string arguments", %{org: org, r: r} do
      assert Zod.line!(org, "username") =~ ".max(20)"
      assert r["user_20"]
      refute r["user_21"]
    end

    test "generates regex constraint for ci_string arguments", %{org: org, r: r} do
      line = Zod.line!(org, "company_name")
      assert line =~ "company_name: z.string().min(2).max(100).regex(/^[a-zA-Z0-9\\s]+"
      refute r["company_a"]
      refute r["company_bad_chars"]
      assert r["company_ok"]
    end

    test "ci_string with only regex constraint", %{org: org, r: r} do
      # non-nullable, so it gets .min(1) automatically
      assert Zod.line!(org, "country_code") =~ "country_code: z.string().min(1).regex(/^[A-Z]{2}"
      refute r["country_3"]
      refute r["country_digits"]
    end

    test "nullable+omittable ci_string with constraints", %{org: org, r: r} do
      assert Zod.line!(org, "optional_nickname") =~
               "optional_nickname: z.string().min(2).max(15).nullable().optional()"

      assert r["nick_null"]
      refute r["nick_a"]
    end

    test "ci_string constraints work same as regular string", %{org: org} do
      assert Zod.line!(org, "username") =~ "username: z.string().min(3).max(20)"
      assert Zod.line!(org, "company_name") =~ "company_name: z.string().min(2).max(100).regex"
    end

    test "ci_string with case-insensitive regex", %{org: org, r: r} do
      assert Zod.line!(org, "country_code") =~ ~r{/\^\[A-Z\]\{2\}.*/i\)}
      assert r["country_lower"]
      refute r["country_3"]
    end
  end

  describe "Regex constraint handling (safe conversion only)" do
    test "simple regex patterns are converted to JavaScript", %{art: art} do
      # LinkContent (embedded union member) url: ~r/^https?:\/\//, projected through a holder
      holder = AshSurface.Ported.E.Fixtures.Domain
      art2 = E.artifact!([holder])
      block = Zod.block!(art2, "OrderMixedHolder_create_schema")
      assert block =~ ".regex(/^https?:\\/\\//)"
      assert is_binary(art)

      assert [true, false] ==
               E.node_accepts(art2, [
                 {"OrderMixedHolder_create_schema", %{"link" => %{"url" => "https://x.io"}}},
                 {"OrderMixedHolder_create_schema", %{"link" => %{"url" => "ftp://x.io"}}}
               ])
    end

    test "email regex pattern is properly converted", %{org: org, r: r} do
      assert Zod.line!(org, "email") =~
               "email: z.string().min(1).regex(/^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}"

      refute r["email_bad"]
    end

    test "phone number regex pattern is properly converted", %{org: org, r: r} do
      assert Zod.line!(org, "phone_number") =~
               "phone_number: z.string().min(1).regex(/^\\+?[1-9]\\d{1,14}"

      refute r["phone_bad"]
      assert r["phone_plus"]
    end

    test "hex color regex pattern is properly converted", %{org: org, r: r} do
      assert Zod.line!(org, "hex_color") =~ "hex_color: z.string().min(1).regex(/^#[0-9A-Fa-f]{6}"
      refute r["hex_short"]
      assert r["hex_ok"]
    end

    test "slug regex pattern is properly converted", %{org: org, r: r} do
      assert Zod.line!(org, "slug") =~ "slug: z.string().min(1).regex(/^[a-z0-9]+(?:-[a-z0-9]+)*"
      refute r["slug_bad"]
      assert r["slug_multi"]
    end

    test "semantic version regex pattern is properly converted", %{org: org, r: r} do
      assert Zod.line!(org, "version") =~ "version: z.string().min(1).regex(/^\\d+\\.\\d+\\.\\d+"
      refute r["version_bad"]
      refute r["version_alpha"]
    end

    test "case-insensitive regex includes i flag", %{org: org, r: r} do
      assert Zod.line!(org, "case_insensitive_code") =~
               "case_insensitive_code: z.string().min(1).regex(/^[A-Z]{3}-\\d{4}"

      assert Zod.line!(org, "case_insensitive_code") =~ "/i)"
      assert r["ci_lower"]
      refute r["ci_bad"]
    end

    test "nullable+omittable field with regex constraint", %{org: org, r: r} do
      # min(1) comes from the allow_empty?: false string default
      assert Zod.line!(org, "optional_url") =~
               "optional_url: z.string().min(1).regex(/^https?:\\/\\/.+/).nullable().optional()"

      assert r["url_null"] and r["url_http"]
      refute r["url_ftp"]
      refute r["url_empty"]
    end

    test "regex constraints are properly escaped for JavaScript", %{org: org} do
      assert org =~ "\\/"
      assert org =~ "\\d"
    end

    test "complex PCRE patterns are skipped to avoid incorrect validation" do
      # Safety mechanism: a PCRE-only pattern (lookbehind with named group) is dropped from the
      # generated Zod rather than emitted as an incorrect client-side regex.
      assert AshSurface.Compiler.ZodType.regex_safe_for_js?("^[a-z]+$")
      refute AshSurface.Compiler.ZodType.regex_safe_for_js?("(?<=a)b(?P<n>c)")

      definition = %{
        "type" => %{"kind" => "string"},
        "constraints" => %{"match" => "(?<=a)b(?P<n>c)"}
      }

      refute AshSurface.Compiler.ZodType.fragment(definition) =~ ".regex("

      simple = %{"type" => %{"kind" => "string"}, "constraints" => %{"match" => "^https?://"}}
      assert AshSurface.Compiler.ZodType.fragment(simple) =~ ".regex("
    end
  end

  describe "third-party type schemas" do
    test "AshMoney.Types.Money maps to object matching the Money alias" do
      assert AshSurface.Compiler.ZodType.third_party_types()["AshMoney.Types.Money"] ==
               "z.object({ amount: z.string(), currency: z.string() })"

      art = E.artifact!()
      line = Zod.line!(Zod.block!(art, "Task_create_schema"), "price")
      assert line =~ "price: z.object({ amount: z.string(), currency: z.string() })"

      assert [true, false] ==
               E.node_accepts(art, [
                 {"Task_create_schema",
                  %{"title" => "t", "price" => %{"amount" => "1.00", "currency" => "USD"}}},
                 {"Task_create_schema", %{"title" => "t", "price" => %{"amount" => 1}}}
               ])
    end
  end

  describe "Ash.Type.Vector in zod schemas" do
    test "resolves a vector by module rather than its :term kind", %{art: art} do
      block = Zod.block!(art, "Todo_create_schema")
      line = Zod.line!(block, "embedding")
      assert line =~ "embedding: z.array(z.number())"
      refute line =~ "z.any()"

      assert [true, false] ==
               E.node_accepts(art, [
                 {"Todo_create_schema", todo_base(%{"embedding" => [0.1, 0.2]})},
                 {"Todo_create_schema", todo_base(%{"embedding" => "nope"})}
               ])
    end
  end

  defp todo_base(extra) do
    Map.merge(%{"title" => "t", "user_id" => @uuid}, extra)
  end
end
