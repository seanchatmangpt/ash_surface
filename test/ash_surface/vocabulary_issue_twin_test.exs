defmodule AshSurface.VocabularyIssueTwinTest do
  use ExUnit.Case, async: true
  alias AshSurface.Vocabulary

  test "issue vocabulary is exposed and in to_map" do
    assert Vocabulary.issue_shape_keys() == ["path", "message", "code"]
    assert "INPUT_VALIDATION_FAILED" in Vocabulary.issue_refusal_codes()
    assert Vocabulary.to_map()["issueShapeKeys"] == Vocabulary.issue_shape_keys()
    assert Vocabulary.to_map()["issueRefusalCodes"] == Vocabulary.issue_refusal_codes()
  end

  test "refusal pattern twin: multiline reasons are refused" do
    for v <- ["REFUSED_\nX", "REFUSED_\r", "REFUSED_X\nY", "REFUSED_\n", "REFUSED_"] do
      refute Vocabulary.refusal_code?(v)
    end

    assert Vocabulary.refusal_code?("REFUSED_NO_AUTHORITY")
  end
end
