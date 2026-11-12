defmodule AshSurface.Ported.Rpc.A.ForbiddenFieldRedactionTest do
  use ExUnit.Case, async: false

  alias AshSurface.Ported.RFP
  alias AshSurface.RuntimeParity.RequestedFields.Compat
  alias AshSurface.RuntimeParity.Rpc.ResultProcessor

  @secret "123-45-6789"

  test "normalize_value_for_json redacts a ForbiddenField" do
    forbidden = %Ash.ForbiddenField{field: :ssn, type: :attribute, original_value: @secret}
    result = ResultProcessor.normalize_value_for_json(forbidden)
    refute String.contains?(Jason.encode!(result), @secret)
    refute String.contains?(Jason.encode!(result), "original_value")
  end

  test "resource struct with a ForbiddenField field does not leak original_value (empty template)" do
    struct =
      struct(AshSurface.Ported.TodoMetadata, %{
        category: %Ash.ForbiddenField{
          field: :category,
          type: :attribute,
          original_value: @secret
        }
      })

    result =
      ResultProcessor.process(
        struct,
        [],
        AshSurface.Ported.TodoMetadata,
        Compat.resource_lookup(RFP.manifest())
      )

    encoded = Jason.encode!(result)
    refute String.contains?(encoded, @secret)
    refute String.contains?(encoded, "original_value")
  end

  test "extract_value maps a ForbiddenField to nil, never :skip" do
    forbidden = %Ash.ForbiddenField{field: :ssn, type: :attribute, original_value: @secret}

    assert ResultProcessor.extract_value(forbidden, nil, [], [], nil) == nil
    refute ResultProcessor.extract_value(forbidden, nil, [], [], nil) == :skip
  end

  test "normalize_primitive maps ForbiddenField and NotLoaded to nil" do
    forbidden = %Ash.ForbiddenField{field: :ssn, type: :attribute, original_value: @secret}
    assert ResultProcessor.normalize_primitive(forbidden) == nil
    assert ResultProcessor.normalize_primitive(%Ash.NotLoaded{field: :x, type: :attribute}) == nil
  end

  test "extract_value maps NotLoaded to :skip" do
    assert ResultProcessor.extract_value(
             %Ash.NotLoaded{field: :x, type: :attribute},
             nil,
             [],
             [],
             nil
           ) == :skip
  end

  defp meta_with(category) do
    struct(AshSurface.Ported.TodoMetadata, %{category: category})
  end

  defp process(struct, template) do
    ResultProcessor.process(
      struct,
      template,
      AshSurface.Ported.TodoMetadata,
      Compat.resource_lookup(RFP.manifest())
    )
  end

  test "templated ForbiddenField attribute keeps its key with nil (F1)" do
    forbidden = %Ash.ForbiddenField{field: :category, type: :attribute, original_value: @secret}
    result = process(meta_with(forbidden), [:category])
    assert result == %{category: nil}
    assert Map.has_key?(result, :category)
  end

  test "templated NotLoaded attribute drops its key" do
    result = process(meta_with(%Ash.NotLoaded{field: :category, type: :attribute}), [:category])
    assert result == %{}
  end

  test "nested-template ForbiddenField keeps its key with nil (F2)" do
    forbidden = %Ash.ForbiddenField{field: :category, type: :attribute, original_value: @secret}
    result = process(meta_with(forbidden), [{:category, [:x]}])
    assert result == %{category: nil}
    assert Map.has_key?(result, :category)

    result =
      process(meta_with(%Ash.NotLoaded{field: :category, type: :attribute}), [{:category, [:x]}])

    assert result == %{}
  end
end
