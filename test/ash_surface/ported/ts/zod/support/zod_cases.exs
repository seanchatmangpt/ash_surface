defmodule AshSurface.Ported.TS.Zod.Cases do
  @moduledoc """
  Lane T16 private helpers: builds the real JS artifact of the ported domain (with scoped
  `zod_mapping_overrides` mirroring the reference test config), stages it in a unique tmp
  workspace, and runs cases under real node + real zod. No doubles.

  The reference overrides name schemas authored in TypeScript (`CustomZodSchemas.objectId`,
  `NestedZodSchemas.geoPoint`); ash_surface takes inline Zod expressions, so the same schemas
  are written inline (`z.string().min(3)`, the `{lat,lng}` object).
  """
  alias AshSurface.ZodFixtures.{Harness, HarnessExt}

  @uuid "123e4567-e89b-12d3-a456-426614174000"

  def uuid, do: @uuid

  def overrides do
    [
      {AshSurface.Ported.CustomIdentifier, "z.string().min(3)"},
      {AshSurface.Ported.GeoPoint,
       "z.object({ lat: z.number().min(-90).max(90), lng: z.number().min(-180).max(180) })"},
      {AshMoney.Types.Money, "z.object({ amount: z.string(), currency: z.string() })"},
      {AshSurface.Ported.Todo.PriorityScore, "z.number()"}
    ]
  end

  @doc "Builds the artifact under `overrides` (env restored afterwards) and stages a workspace."
  def workspace!(overrides \\ overrides()) do
    prev = Application.fetch_env(:ash_surface, :zod_mapping_overrides)
    Application.put_env(:ash_surface, :zod_mapping_overrides, overrides)

    try do
      artifact = HarnessExt.artifact!(AshSurface.Ported.Domain)
      Harness.workspace!(artifact)
    after
      case prev do
        {:ok, v} -> Application.put_env(:ash_surface, :zod_mapping_overrides, v)
        :error -> Application.delete_env(:ash_surface, :zod_mapping_overrides)
      end
    end
  end

  @doc """
  Runs `cases` (maps with `:label` and either `:id` + `:payload` or `:js`) in one node process;
  returns the decoded result list in order.
  """
  def run!(ts_dir, cases) do
    input = Path.join(ts_dir, "t16_in_#{AshSurface.TestTmp.suffix()}.json")
    File.write!(input, Jason.encode!(cases))

    {out, status} =
      Harness.run(
        Harness.tool!("node"),
        ["zod_t16_runner.mjs", "generated/ash_surface_client.mjs", input],
        ts_dir
      )

    if status != 0, do: raise("node runner failed (#{status}): #{out}")
    out |> String.split("\n", trim: true) |> List.last() |> Jason.decode!()
  end

  @doc "Reference `createValidBaseData()` in wire (snake_case) names."
  def base do
    %{
      "title" => "Test",
      "user_id" => @uuid,
      "number_of_employees" => 10,
      "some_string" => "valid",
      "email" => "test@example.com",
      "phone_number" => "+15551234567",
      "hex_color" => "#123456",
      "slug" => "test",
      "version" => "1.0.0",
      "case_insensitive_code" => "ABC-1234",
      "price" => 10.5,
      "temperature" => 20.0,
      "percentage" => 50.0,
      "username" => "testuser",
      "company_name" => "Acme Corp",
      "country_code" => "US",
      "auto_complete" => false,
      "address" => %{"street_address" => "123 Main St", "location_id" => "LOC123"}
    }
  end

  def with(overrides), do: Map.merge(base(), Map.new(overrides))

  @doc "`base/0` with string-keyed or atom-keyed overrides (atoms become wire names)."
  def b(kv), do: Map.merge(base(), Map.new(kv, fn {k, v} -> {to_string(k), v} end))

  @doc "Valid `validate_array_constraints` input (reference `createValidArrayConstraintData`, boundary form)."
  def arr(kv \\ []) do
    Map.merge(
      %{
        "minimum_reference_ids" => [@uuid],
        "maximum_reference_ids" => List.duplicate(@uuid, 16),
        "bounded_reference_ids" => List.duplicate(@uuid, 16),
        "bounded_codes" => ["ab", "12345678", "valid", "code"]
      },
      Map.new(kv, fn {k, v} -> {to_string(k), v} end)
    )
  end

  @doc "Todo.create payload carrying a `link` content-union member."
  def link(url, title),
    do: %{
      "title" => "t",
      "user_id" => @uuid,
      "content" => %{"content_type" => "link", "link" => %{"url" => url, "title" => title}}
    }
end
