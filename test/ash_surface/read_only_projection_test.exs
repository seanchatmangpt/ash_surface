defmodule AshSurface.ReadOnlyProjectionTest do
  use ExUnit.Case, async: true
  alias AshSurface.ReadOnlyProjection

  @subject "urn:chicago:agentic-payment:purchase-001"

  test "operator and seller views preserve exact subject and zero authority" do
    source = %{subject: @subject, authority: :none, capabilities: ["bounded-purchase"], standing: :partial}
    assert {:ok, operator} = ReadOnlyProjection.project(source, :operator)
    assert {:ok, seller} = ReadOnlyProjection.project(source, :seller)
    assert operator.subject == @subject
    assert seller.subject == @subject
    assert operator.authority == :none
    assert seller.authority == :none
  end

  test "projection refuses any attempted authority widening" do
    assert {:error, {:refused, :projection_cannot_widen_authority, :do}} =
             ReadOnlyProjection.project(%{subject: @subject, authority: :do}, :operator)
  end

  test "projection refuses malformed or unknown audience sources" do
    assert {:error, {:refused, :invalid_projection_source}} =
             ReadOnlyProjection.project(%{subject: @subject}, :seller)

    assert_raise FunctionClauseError, fn ->
      ReadOnlyProjection.project(%{subject: @subject, authority: :none}, :unknown)
    end
  end
end
