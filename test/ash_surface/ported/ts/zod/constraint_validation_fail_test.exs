Code.ensure_loaded?(AshSurface.Ported.TS.Zod.Cases) ||
  Code.require_file("support/zod_cases.exs", __DIR__)

defmodule AshSurface.Ported.TS.Zod.ConstraintValidationFailTest do
  @moduledoc """
  Adaptation of ash_typescript `test/ts/zod/shouldFail/constraintValidation.ts` (every exported
  function has a test below, named after it). Each reference case parsed invalid data and
  expected a `ZodError`; here the emitted artifact schema is run under real node + real zod and
  the typed issues (`path: code`) are asserted, not just failure. Wire names are snake_case;
  Money / CustomIdentifier use scoped `zod_mapping_overrides` (see `Cases`).
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.TS.Zod.Cases
  alias AshSurface.ZodFixtures.Harness

  @c "OrgTodo.create"
  @arr "OrgTodo.validate_array_constraints"
  @uuid Cases.uuid()
  import AshSurface.Ported.TS.Zod.Cases, only: [b: 1, arr: 1, link: 2]

  # {reference function, schema id, payload, issues that must all be present}
  @table [
    {"testIntegerBelowMin", @c, b(number_of_employees: 0), ["number_of_employees: too_small"]},
    {"testIntegerAboveMax", @c, b(number_of_employees: 1001), ["number_of_employees: too_big"]},
    {"testIntegerNegative", @c, b(number_of_employees: -10), ["number_of_employees: too_small"]},
    {"testStringEmpty", @c, b(some_string: ""), ["some_string: too_small"]},
    {"testStringTooLong", @c, b(some_string: String.duplicate("a", 101)),
     ["some_string: too_big"]},
    {"testStringWayTooLong", @c, b(some_string: String.duplicate("a", 500)),
     ["some_string: too_big"]},
    {"testRegexInvalidUrl (content link member)", "Todo.create",
     link("not-a-url", "Invalid link"), ["content.link.url: invalid_format"]},
    {"testRegexFtpUrl (content link member)", "Todo.create",
     link("ftp://example.com", "FTP link"), ["content.link.url: invalid_format"]},
    {"testMultipleConstraintViolations", @c, b(number_of_employees: 5000, some_string: ""),
     ["number_of_employees: too_big", "some_string: too_small"]},
    {"testSafeParseConstraintViolation", @c, b(number_of_employees: 2000),
     ["number_of_employees: too_big"]},
    {"testIntegerFloatingPoint", @c, b(number_of_employees: 10.5),
     ["number_of_employees: invalid_type"]},
    {"testBoundaryViolations (just below min)", @c, b(number_of_employees: 0.99),
     ["number_of_employees: invalid_type"]},
    {"testBoundaryViolations (just above max)", @c, b(number_of_employees: 1000.01),
     ["number_of_employees: invalid_type"]},
    {"testRequiredFieldMissing", @c, Map.delete(b([]), "number_of_employees"),
     ["number_of_employees: invalid_type"]},
    {"testInvalidEmailNoAt", @c, b(email: "notanemail.com"), ["email: invalid_format"]},
    {"testInvalidEmailNoDomain", @c, b(email: "user@example"), ["email: invalid_format"]},
    {"testInvalidPhoneStartsWithZero", @c, b(phone_number: "+05551234567"),
     ["phone_number: invalid_format"]},
    {"testInvalidPhoneTooShort", @c, b(phone_number: "+1"), ["phone_number: invalid_format"]},
    {"testInvalidHexColorLength", @c, b(hex_color: "#FFF"), ["hex_color: invalid_format"]},
    {"testInvalidHexColorNoHash", @c, b(hex_color: "FF5733"), ["hex_color: invalid_format"]},
    {"testInvalidSlugUppercase", @c, b(slug: "Test-Slug"), ["slug: invalid_format"]},
    {"testInvalidSlugStartsWithHyphen", @c, b(slug: "-test-slug"), ["slug: invalid_format"]},
    {"testInvalidVersionMissingPatch", @c, b(version: "1.0"), ["version: invalid_format"]},
    {"testInvalidVersionWithLetters", @c, b(version: "1.0.0-beta"), ["version: invalid_format"]},
    {"testInvalidCodeWrongFormat", @c, b(case_insensitive_code: "AB-1234"),
     ["case_insensitive_code: invalid_format"]},
    {"testInvalidOptionalUrlWrongProtocol", @c, b(optional_url: "ftp://example.com"),
     ["optional_url: invalid_format"]},
    {"testFloatPriceBelowMin", @c, b(price: -0.01), ["price: too_small"]},
    {"testFloatPriceAboveMax", @c, b(price: 1_000_000.0), ["price: too_big"]},
    {"testFloatTemperatureAtGtBoundary", @c, b(temperature: -273.15), ["temperature: too_small"]},
    {"testFloatTemperatureAtLtBoundary", @c, b(temperature: 1_000_000.0),
     ["temperature: too_big"]},
    {"testFloatPercentageBelowMin", @c, b(percentage: -0.1), ["percentage: too_small"]},
    {"testFloatPercentageAboveMax", @c, b(percentage: 100.01), ["percentage: too_big"]},
    {"testOptionalFloatInvalid", @c, b(optional_rating: 5.5), ["optional_rating: too_big"]},
    {"testMultipleFloatViolations", @c, b(price: -100.0, temperature: -300.0, percentage: 150.0),
     ["price: too_small", "temperature: too_small", "percentage: too_big"]},
    {"testCiStringUsernameTooShort", @c, b(username: "ab"), ["username: too_small"]},
    {"testCiStringUsernameTooLong", @c, b(username: String.duplicate("a", 21)),
     ["username: too_big"]},
    {"testCiStringCompanyNameInvalidChars", @c, b(company_name: "Acme@Corp!"),
     ["company_name: invalid_format"]},
    {"testCiStringCompanyNameTooShort", @c, b(company_name: "A"), ["company_name: too_small"]},
    {"testCiStringCountryCodeWrongLength", @c, b(country_code: "USA"),
     ["country_code: invalid_format"]},
    {"testCiStringCountryCodeWithNumber", @c, b(country_code: "U1"),
     ["country_code: invalid_format"]},
    {"testOptionalCiStringInvalid", @c, b(optional_nickname: "a"),
     ["optional_nickname: too_small"]},
    {"testMultipleCiStringViolations", @c,
     b(username: "ab", company_name: "A", country_code: "123"),
     ["username: too_small", "company_name: too_small", "country_code: invalid_format"]},
    {"testMoneyMissingAmount", "Task.create",
     %{"title" => "Bad", "price" => %{"currency" => "USD"}}, ["price.amount: invalid_type"]},
    {"testMoneyWrongFieldTypes", "Task.create",
     %{"title" => "Bad", "price" => %{"amount" => 99, "currency" => 42}},
     ["price.amount: invalid_type", "price.currency: invalid_type"]},
    {"testOmittableOnlyTitleRejectsNull", "Task.update", %{"title" => nil},
     ["title: invalid_type"]},
    {"testOmittableOnlyArchivedRejectsNull", "Task.update",
     %{"title" => "x", "isArchived" => nil}, ["isArchived: invalid_type"]},
    {"update still rejects a wrong-typed title (T16b)", "Task.update", %{"title" => 5},
     ["title: invalid_type"]},
    {"create still requires title (T16b)", "Task.create", %{}, ["title: invalid_type"]},
    {"testRequiredTitleRejectsNullOnCreate", "Task.create", %{"title" => nil},
     ["title: invalid_type"]},
    {"testArrayBelowMinimum", @arr, arr(minimum_reference_ids: []),
     ["minimum_reference_ids: too_small"]},
    {"testArrayAboveMaximum", @arr, arr(maximum_reference_ids: List.duplicate(@uuid, 17)),
     ["maximum_reference_ids: too_big"]},
    {"testArrayItemConstraintViolation", @arr, arr(bounded_codes: ["x"]),
     ["bounded_codes.0: too_small"]},
    {"testOptionalArrayRejectsNull", @arr, arr(optional_reference_ids: nil),
     ["optional_reference_ids: invalid_type"]},
    {"testNullableStringRejectsEmpty", @c, b(description: ""), ["description: too_small"]}
  ]

  setup_all do
    ts_dir = Cases.workspace!()
    on_exit(fn -> Harness.cleanup!(ts_dir) end)

    cases =
      for {name, id, payload, _} <- @table, do: %{label: name, id: id, payload: payload}

    %{ts_dir: ts_dir, results: Cases.run!(ts_dir, cases) |> Map.new(&{&1["label"], &1})}
  end

  for {name, _id, _payload, expected} <- @table do
    test "#{name}: refused with typed issues", %{results: results} do
      r = Map.fetch!(results, unquote(name))
      assert r["success"] == false, "#{r["label"]} was accepted"

      for issue <- unquote(expected) do
        assert issue in r["issues"], "#{r["label"]}: #{issue} not in #{inspect(r["issues"])}"
      end
    end
  end

  test "control: the unmodified base payload and array payload are accepted (cases are not vacuous)",
       %{ts_dir: ts_dir} do
    [ok1, ok2] =
      Cases.run!(ts_dir, [
        %{label: "base", id: @c, payload: b([])},
        %{label: "arr", id: @arr, payload: arr([])}
      ])

    assert ok1["success"] == true, inspect(ok1)
    assert ok2["success"] == true, inspect(ok2)
  end
end
