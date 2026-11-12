defmodule AshSurface.Ported.Rpc.E.TypedMapEmbeddedRowsSurfaceTest do
  @moduledoc """
  Port of ash_typescript `rpc/typed_map_embedded_rows_test.exs` (3 tests). Test 001 asserts the
  generated TypeScript `__primitiveFields` text; its behavioral counterpart is the pipeline's
  field-selection classification: the embedded-row field of the typed map is not selectable as
  a plain string leaf. Tests 002/003 run the pipeline over a caller-built `Todo` whose
  `metadata_report` calculation value is what `MetadataReportCalculation` produces (real
  `TodoMetadata` embedded structs); no data layer.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported, as: P
  alias AshSurface.Ported.{Rpc, RpcFixtures}

  defp todo_with_report do
    report = %{
      rows: [
        %P.TodoMetadata{category: "work", priority_score: 80},
        %P.TodoMetadata{category: "personal", priority_score: 20}
      ],
      total: 2
    }

    RpcFixtures.todo(title: "Report Todo") |> Map.put(:metadata_report, report)
  end

  test "001 embedded-resource array field is not a plain-string leaf of the typed map" do
    params = %{
      "action" => "list_todos",
      "fields" => ["id", %{"metadataReport" => ["total", "rows"]}]
    }

    assert {:ok, request} = Rpc.parse(params)

    # `total` is a primitive leaf; `rows` (array of embedded resources) is not, so the
    # extraction template carries it as a bare name only in the lenient-runtime form (test 003),
    # while nested selection yields a nested template node (test 002).
    nested = %{
      "action" => "list_todos",
      "fields" => ["id", %{"metadataReport" => ["total", %{"rows" => ["category"]}]}]
    }

    assert {:ok, nested_request} = Rpc.parse(nested)

    assert {:metadata_report, template} =
             Enum.find(nested_request.extraction_template, &match?({:metadata_report, _}, &1))

    assert :total in template
    assert Enum.any?(template, &match?({:rows, [:category]}, &1))
    refute Enum.any?(template, &(&1 == :rows))
    assert request.extraction_template != nested_request.extraction_template
  end

  test "002 nested selection on embedded rows returns only requested fields" do
    result =
      Rpc.run(
        %{
          "action" => "list_todos",
          "fields" => [
            "id",
            %{"metadataReport" => ["total", %{"rows" => ["category", "priorityScore"]}]}
          ]
        },
        [todo_with_report()]
      )

    assert result["success"] == true
    assert [todo | _] = result["data"]
    report = todo["metadataReport"]
    assert report["total"] == 2
    assert [row1, row2] = report["rows"]
    assert row1 == %{"category" => "work", "priorityScore" => 80}
    assert row2 == %{"category" => "personal", "priorityScore" => 20}
  end

  test "003 plain string selection of embedded rows is still accepted at runtime" do
    result =
      Rpc.run(
        %{"action" => "list_todos", "fields" => ["id", %{"metadataReport" => ["total", "rows"]}]},
        [todo_with_report()]
      )

    assert result["success"] == true
    assert [todo | _] = result["data"]
    report = todo["metadataReport"]
    assert report["total"] == 2
    assert [row1, _row2] = report["rows"]
    assert row1["category"] == "work"
  end
end
