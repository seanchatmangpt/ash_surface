defmodule AshSurface.Ported.Rpc.Rbo.Fmt4 do
  @moduledoc false
  def f4(field, a, b, c), do: "#{field}|#{a}|#{b}|#{c}"
end

defmodule AshSurface.Ported.Rpc.Rbo.ErrorsAndFormatterTest do
  @moduledoc """
  Lane RBO: F1 (exposed `fields`), F4 (InvalidKeyset `vars.key`), G3 (arity-4 custom formatter
  argument order, KD-12 contract: binary non-empty result).
  """
  use ExUnit.Case, async: true

  alias AshSurface.Errors
  alias AshSurface.FieldName
  alias AshSurface.Ported.Rpc.Rbo.Fmt4

  test "F1: exposed UnknownError carries its field and path in `fields`/`path`" do
    err = Ash.Error.Unknown.UnknownError.exception(error: "kaboom", field: :f, path: [:a])
    [out] = Errors.to_errors(err, show_raised_errors: true)

    assert out["type"] == "unknown_error"
    assert out["message"] == "kaboom"
    assert out["fields"] == ["f"]
    assert out["path"] == ["a"]
    assert out["vars"] == %{}
  end

  test "F4: InvalidKeyset exposes its key and value in vars" do
    err = Ash.Error.Page.InvalidKeyset.exception(value: "zzz", key: :k)
    [out] = Errors.to_errors(err)
    assert out["vars"] == %{"key" => "k", "value" => "zzz"}
  end

  test "G3: arity-4 formatter receives (field, a, b, c) in order" do
    assert FieldName.format(:x, {Fmt4, :f4, ["A", "B", "C"]}) == "x|A|B|C"
    assert FieldName.compute("y", {Fmt4, :f4, [1, 2, 3]}) == "y|1|2|3"
  end
end
