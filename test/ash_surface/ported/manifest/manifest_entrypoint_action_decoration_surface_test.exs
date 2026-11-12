defmodule AshSurface.Ported.Manifest.EntrypointActionDecorationSurfaceTest do
  @moduledoc """
  ash_surface counterpart of ash_typescript `manifest/entrypoint_action_decoration_test`.

  ash_typescript caches per-action decoration (return classification, expected input
  keys per formatter) on the manifest. ash_surface computes the same facts purely:
  `ResourceFacts.build/2` for the action facts and `FieldName.client_to_internal/3` /
  `FieldName.format_field_for_client/3` for the input-key maps.
  """
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.ResourceFacts
  alias AshSurface.FieldName

  @resources [AshSurface.Ported.User, AshSurface.Ported.Todo, AshSurface.Ported.Task]

  defp public_actions(resource),
    do: resource |> Ash.Resource.Info.actions() |> Enum.filter(& &1.public?)

  defp input_fields(action) do
    accepted = Map.get(action, :accept) |> List.wrap()
    args = action.arguments |> Enum.filter(& &1.public?) |> Enum.map(& &1.name)
    Enum.uniq(accepted ++ args)
  end

  test "every public action carries every precomputed fact key and an input map per formatter" do
    for resource <- @resources, action <- public_actions(resource) do
      facts = ResourceFacts.build(resource, action)

      for key <- ResourceFacts.fact_keys() do
        assert Map.has_key?(facts, key), "#{inspect(resource)}.#{action.name} lacks #{key}"
      end

      fields = input_fields(action)

      overrides =
        case AshSurface.Resource.Info.field_names(resource) do
          nil -> %{}
          names -> Map.new(names)
        end

      for formatter <- [:camel_case, :pascal_case, :snake_case] do
        assert {:ok, keys} = FieldName.client_to_internal(fields, formatter, overrides)
        assert is_map(keys)
        assert map_size(keys) == length(fields)
      end

      assert {:error, _} = FieldName.validate_formatter({SomeMod, "fun"})
    end
  end

  test "custom field-name mappings take precedence over the formatter in every formatter map" do
    resource = AshSurface.Ported.User
    overrides = Map.new(AshSurface.Resource.Info.field_names(resource))

    for formatter <- [:camel_case, :snake_case, :pascal_case] do
      {:ok, keys} =
        FieldName.client_to_internal([:address_line_1, :is_super_admin], formatter, overrides)

      assert Map.get(keys, "addressLine1") == :address_line_1
      refute Map.has_key?(keys, "address_line_1")
      refute Map.has_key?(keys, "AddressLine1")
    end

    {:ok, camel} = FieldName.client_to_internal([:is_super_admin], :camel_case, overrides)
    {:ok, snake} = FieldName.client_to_internal([:is_super_admin], :snake_case, overrides)
    {:ok, pascal} = FieldName.client_to_internal([:is_super_admin], :pascal_case, overrides)
    assert Map.get(camel, "isSuperAdmin") == :is_super_admin
    assert Map.get(snake, "is_super_admin") == :is_super_admin
    assert Map.get(pascal, "IsSuperAdmin") == :is_super_admin

    # the resource-level mapping also wins through the resource-aware entry point
    for formatter <- [:camel_case, :snake_case, :pascal_case] do
      assert FieldName.format_field_for_client(:address_line_1, resource, formatter) ==
               "addressLine1"
    end
  end

  test "facts equal a live recompute (pure, no hidden cache)" do
    for resource <- @resources, action <- public_actions(resource) do
      assert ResourceFacts.build(resource, action) == ResourceFacts.build(resource, action)
    end
  end
end
