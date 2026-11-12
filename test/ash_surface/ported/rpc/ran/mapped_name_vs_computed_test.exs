defmodule AshSurface.Ported.Rpc.Ran.PersonResource do
  @moduledoc "Lane RAN inline resource: mapped names DIFFER from every computed spelling."
  use Ash.Resource,
    domain: AshSurface.Ported.Rpc.Ran.PersonDomain,
    data_layer: Ash.DataLayer.Ets,
    primary_read_warning?: false,
    extensions: [AshSurface.Resource]

  ets do
    private?(true)
  end

  surface do
    type_name("RanPerson")
    field_names(is_ready?: "ready", line_1: "lineOne")

    typed_query :ran_people, :read do
      fields_const_name("ranPeople")
      result_type_name("RanPeopleResult")
      fields([:id, :is_ready?, :line_1, :last_name])
    end
  end

  attributes do
    uuid_primary_key(:id, public?: true)
    attribute(:is_ready?, :boolean, public?: true)
    attribute(:line_1, :string, public?: true)
    attribute(:last_name, :string, public?: true)
  end

  actions do
    read :read do
      primary?(true)
    end
  end
end

defmodule AshSurface.Ported.Rpc.Ran.PersonDomain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(AshSurface.Ported.Rpc.Ran.PersonResource)
  end
end

defmodule AshSurface.Ported.Rpc.Ran.MappedNameVsComputedTest do
  @moduledoc """
  Lane RAN. Mutation-survivor repair (RAK finding): in the typed-query read path the mapped-name
  handling survived because ported fixtures map to the same spelling the camelCase formatter
  computes. Here `first_name -> "ready"` and `zip_code -> "lineOne"` differ from every computed
  spelling (`isReady`/`line1`, snake, pascal), so only the mapping path yields the keys.
  Real resource, real manifest, real pipeline; assertions on exact output keys.
  """
  use ExUnit.Case, async: false

  alias AshSurface.FieldName
  alias AshSurface.Ported.Rpc.Ran.PersonResource
  alias AshSurface.RuntimeParity.RequestedFields.Compat
  alias AshSurface.RuntimeParity.Rpc.{Pipeline, Support, TypedQuery}

  @otp_app :ash_surface_ported_ran
  @id "22222222-2222-2222-2222-222222222222"

  defp install do
    Application.put_env(@otp_app, :ash_domains, [AshSurface.Ported.Rpc.Ran.PersonDomain])
    {:ok, manifest} = Ash.Info.Manifest.generate(otp_app: @otp_app)
    Support.install(Compat.prepare(manifest), [Pipeline.entry(:list_people, PersonResource, :read)])
  end

  defp person,
    do:
      struct(PersonResource, %{id: @id, is_ready?: true, line_1: "90210", last_name: "L"})

  defp run(params) do
    install()
    Pipeline.run_with_result(params, [person()], [], [])
  end

  defp keys(%{"success" => true, "data" => [row]}), do: row |> Map.keys() |> Enum.sort()
  defp keys(%{"Success" => true, "Data" => [row]}), do: row |> Map.keys() |> Enum.sort()

  test "wire/2 returns the mapped spelling, not the computed one" do
    assert FieldName.wire(PersonResource, :is_ready?) == "ready"
    assert FieldName.wire(PersonResource, :line_1) == "lineOne"
    assert FieldName.wire(PersonResource, :last_name) == "lastName"
    refute FieldName.compute(:is_ready?, :camel_case) == "ready"
    refute FieldName.compute(:line_1, :camel_case) == "lineOne"
  end

  test "RPC read emits exactly the mapped keys plus the computed key for the unmapped field" do
    result = run(%{"action" => "list_people", "fields" => ["id", "ready", "lineOne", "lastName"]})

    assert keys(result) == ["id", "lastName", "lineOne", "ready"]
    [row] = result["data"]
    assert row == %{"id" => @id, "ready" => true, "lineOne" => "90210", "lastName" => "L"}
  end

  test "the computed spelling of a mapped field is not a selectable wire name" do
    install()

    assert {:error, {:unknown_field, _, _, _}} =
             Pipeline.parse_request(%{"action" => "list_people", "fields" => ["isReady"]}, [])
  end

  test "mapped keys are verbatim under every output formatter scope; unmapped follow it" do
    for {formatter, id, last} <- [snake_case: {"id", "last_name"}, pascal_case: {"Id", "LastName"}, camel_case: {"id", "lastName"}] |> Enum.map(fn {f, {i, l}} -> {f, i, l} end) do
      result =
        FieldName.with_formatter(formatter, fn ->
          install()

          Pipeline.run_with_result(
            %{"action" => "list_people", "fields" => [id, "ready", "lineOne", last]},
            [person()],
            [],
            []
          )
        end)

      assert keys(result) == Enum.sort([id, "ready", "lineOne", last]),
             "formatter #{inspect(formatter)}: #{inspect(result)}"
    end
  end

  test "typed query result rows carry the mapped keys, never the computed ones" do
    install()

    result = TypedQuery.run(:ran_people, %{}, [person()], [])

    assert %{"success" => true, "data" => [row]} = result
    assert row == %{"id" => @id, "ready" => true, "lineOne" => "90210", "lastName" => "L"}
    refute Map.has_key?(row, "isReady")
    refute Map.has_key?(row, "line1")
  end
end
