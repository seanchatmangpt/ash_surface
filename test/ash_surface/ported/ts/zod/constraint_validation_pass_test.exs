Code.ensure_loaded?(AshSurface.Ported.TS.Zod.Cases) ||
  Code.require_file("support/zod_cases.exs", __DIR__)

defmodule AshSurface.Ported.TS.Zod.ConstraintValidationPassTest do
  @moduledoc """
  Adaptation of ash_typescript `test/ts/zod/shouldPass/constraintValidation.ts` (every exported
  function has a test below, named after it). ash_surface emits no `.ts`/`ash_zod.ts`, so the
  reference's compile-and-parse checks become real-zod parses of the emitted artifact
  (`OrgTodo.create`, `Task.create/update`, `OrgTodo.validate_array_constraints`, Todo content
  link member) run under node. `testUpdateTaskAllOmittable` (update with every key omitted) is in the table. Wire names are snake_case (`number_of_employees`), schemas are
  `.passthrough()`. Money / PriorityScore / CustomIdentifier / GeoPoint use scoped
  `zod_mapping_overrides` (see `Cases`).
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.TS.Zod.Cases
  alias AshSurface.ZodFixtures.Harness

  @c "OrgTodo.create"
  @arr "OrgTodo.validate_array_constraints"
  @uuid Cases.uuid()
  import AshSurface.Ported.TS.Zod.Cases, only: [b: 1, arr: 0, arr: 1]

  # {reference function, schema id, [payloads]}; every payload must be accepted.
  @table [
    {"testIntegerMinConstraint", @c, [b(number_of_employees: 1)]},
    {"testIntegerMaxConstraint", @c, [b(number_of_employees: 1000)]},
    {"testIntegerMidRangeConstraint", @c, [b(number_of_employees: 500)]},
    {"testStringMinLengthConstraint", @c, [b(some_string: "a")]},
    {"testStringMaxLengthConstraint", @c, [b(some_string: String.duplicate("a", 100))]},
    {"testStringMidRangeLengthConstraint", @c,
     [b(some_string: "This is a valid string with moderate length")]},
    {"testRegexConstraintValid (content link member)", "Todo.create",
     [
       %{
         "title" => "t",
         "user_id" => @uuid,
         "content" => %{
           "content_type" => "link",
           "link" => %{"url" => "https://example.com", "title" => "Example link"}
         }
       }
     ]},
    {"testRegexConstraintHttpUrl (content link member)", "Todo.create",
     [
       %{
         "title" => "t",
         "user_id" => @uuid,
         "content" => %{
           "content_type" => "link",
           "link" => %{"url" => "http://example.com", "title" => "Example link"}
         }
       }
     ]},
    {"testAllConstraintsTogether", @c,
     [
       b(
         title: "Complete todo",
         description: "This has all valid fields",
         status: "pending",
         priority: "high",
         number_of_employees: 250,
         some_string: "Valid string with good length",
         email: "complete@example.com",
         slug: "complete-todo",
         version: "2.1.5",
         case_insensitive_code: "XYZ-9999",
         auto_complete: true,
         tags: ["important", "urgent"]
       )
     ]},
    {"testSafeParsingWithConstraints", @c, [b(number_of_employees: 50)]},
    {"validateWithConstraints", @c, [b([])]},
    {"createOrgTodoWithValidation", @c, [b([])]},
    {"testOptionalConstrainedField", @c,
     [
       b(
         number_of_employees: 100,
         slug: "test-slug-123",
         version: "1.2.3",
         description: "Valid description"
       )
     ]},
    {"testValidEmails", @c,
     for(
       e <- [
         "user@example.com",
         "test.user@example.com",
         "test+tag@example.co.uk",
         "user_name@example-domain.com"
       ],
       do: b(email: e)
     )},
    {"testValidPhoneNumbers", @c,
     for(p <- ["+15551234567", "15551234567", "+442071234567", "+12"], do: b(phone_number: p))},
    {"testValidHexColors", @c,
     for(c <- ["#000000", "#FFFFFF", "#ff5733", "#AbCdEf"], do: b(hex_color: c))},
    {"testValidSlugs", @c, for(s <- ["test", "test-slug", "a1-b2-c3", "123"], do: b(slug: s))},
    {"testValidVersions", @c, for(v <- ["0.0.0", "1.0.0", "10.20.30"], do: b(version: v))},
    {"testCaseInsensitiveCodes", @c,
     for(c <- ["ABC-1234", "abc-1234", "AbC-0000"], do: b(case_insensitive_code: c))},
    {"testOptionalUrlOmitted", @c, [b([])]},
    {"testOptionalUrlProvided", @c,
     for(
       u <- [
         "https://example.com",
         "http://test.com",
         "https://example.com/path/to/resource",
         "http://localhost:3000"
       ],
       do: b(optional_url: u)
     )},
    {"testFloatPriceValid", @c, for(p <- [0.0, 10.5, 999_999.99], do: b(price: p))},
    {"testFloatTemperatureValid", @c,
     for(t <- [-273.14, 0.0, 999_999.99], do: b(temperature: t))},
    {"testFloatPercentageValid", @c, for(p <- [0.0, 50.5, 100.0], do: b(percentage: p))},
    {"testOptionalFloatOmitted", @c, [b([])]},
    {"testOptionalFloatProvided", @c, for(r <- [0.0, 2.5, 5.0], do: b(optional_rating: r))},
    {"testFloatPrecision", @c,
     [
       b(price: 19.99),
       b(price: 123.456),
       b(temperature: -100.123),
       b(percentage: 33.333)
     ]},
    {"testCiStringUsernameValid", @c,
     for(u <- ["abc", "testuser", String.duplicate("a", 20)], do: b(username: u))},
    {"testCiStringCompanyNameValid", @c,
     for(c <- ["Ac", "Acme Corp", "Company 123"], do: b(company_name: c))},
    {"testCiStringCountryCodeValid", @c, for(c <- ["US", "us", "Gb"], do: b(country_code: c))},
    {"testOptionalCiStringOmitted", @c, [b([])]},
    {"testOptionalCiStringProvided", @c,
     for(n <- ["ab", "nickname", String.duplicate("n", 15)], do: b(optional_nickname: n))},
    {"testCiStringCaseVariations", @c,
     [
       b(username: "TestUser", company_name: "ACME CORP", country_code: "us"),
       b(username: "TESTUSER", company_name: "acme corp", country_code: "US"),
       b(username: "testuser", company_name: "Acme Corp", country_code: "Us")
     ]},
    {"testMoneyValidShape", "Task.create",
     [%{"title" => "Buy milk", "price" => %{"amount" => "4.99", "currency" => "USD"}}]},
    {"testMoneyOptionalOmitted", "Task.create", [%{"title" => "Priceless"}]},
    {"testNullableDescriptionAcceptsNull", @c, [b(description: nil)]},
    {"testNullableOptionalUrlAcceptsNull", @c, [b(optional_url: nil)]},
    {"testNullableOptionalRatingAcceptsNull", @c, [b(optional_rating: nil)]},
    {"testNullableOptionalNicknameAcceptsNull", @c, [b(optional_nickname: nil)]},
    {"testNullableMoneyAcceptsNull", "Task.create", [%{"title" => "Free", "price" => nil}]},
    {"testNullableTypedStructAcceptsNull", "Task.update", [%{"title" => "x", "stats" => nil}]},
    {"testUpdateTaskAllOmittable", "Task.update", [%{}]},
    {"testUpdateTaskOmittableTitleAcceptsValue", "Task.update", [%{"title" => "Updated"}]},
    {"testUpdateTaskOmittableArchivedAcceptsValue", "Task.update",
     [%{"title" => "x", "isArchived" => true}]},
    {"testEmptyOkStringAcceptsEmpty", @c, [b(empty_ok_string: "")]},
    {"testArrayCardinalityBoundaries", @arr, [arr()]},
    {"testOptionalArrayOmitted", @arr, [arr()]},
    {"testNullableArrayAcceptsNull", @arr, [arr(nullable_reference_ids: nil)]}
  ]

  setup_all do
    ts_dir = Cases.workspace!()
    on_exit(fn -> Harness.cleanup!(ts_dir) end)

    cases =
      for {name, id, payloads} <- @table,
          {p, i} <- Enum.with_index(payloads),
          do: %{label: "#{name}##{i}", id: id, payload: p}

    results = Cases.run!(ts_dir, cases) |> Map.new(&{&1["label"], &1})
    %{results: results}
  end

  for {name, _id, payloads} <- @table do
    test "#{name}: every payload parses", %{results: results} do
      for i <- 0..(length(unquote(Macro.escape(payloads))) - 1) do
        r = Map.fetch!(results, "#{unquote(name)}##{i}")
        assert r["success"] == true, "#{r["label"]} rejected: #{inspect(r["issues"])}"
      end
    end
  end
end
