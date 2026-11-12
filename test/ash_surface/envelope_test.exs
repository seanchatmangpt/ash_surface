defmodule AshSurface.EnvelopeTest do
  use ExUnit.Case, async: true
  alias AshSurface.Envelope

  test "ok wraps data" do
    assert %{"success" => true, "data" => %{"a" => 1}} == Envelope.ok(%{"a" => 1})
    assert %{"success" => true, "data" => nil} == Envelope.ok(nil)
  end

  test "error runs real Ash errors through to_errors/2" do
    err =
      Ash.Error.Invalid.exception(
        errors: [Ash.Error.Changes.Required.exception(field: :title, type: :attribute)]
      )

    assert %{"success" => false, "errors" => [e | _]} = Envelope.error(err)
    assert is_map(e)
    assert Map.keys(e) -- Map.keys(Jason.decode!(Jason.encode!(e))) == []
    assert Envelope.error(err) == Envelope.error(err)
    assert %{"success" => false, "errors" => errs} = Envelope.error(err, formatter: :snake_case)
    assert is_list(errs)
  end
end
