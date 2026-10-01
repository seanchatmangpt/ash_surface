defmodule AshSurface.ReadOnlyProjection do
  @moduledoc """
  Generic authority-free projection of an exact external subject.

  The caller owns semantics and evidence. AshSurface only changes presentation.
  """

  @type source :: %{required(:subject) => String.t(), required(:authority) => :none}

  @spec project(source(), :operator | :seller) :: {:ok, map()} | {:error, term()}
  def project(%{subject: subject, authority: :none} = source, audience)
      when is_binary(subject) and audience in [:operator, :seller] do
    {:ok,
     %{
       subject: subject,
       audience: audience,
       authority: :none,
       evidence_mode: Map.get(source, :mode, :unknown),
       standing: Map.get(source, :standing, :unknown),
       evidence: Map.get(source, :evidence, %{}),
       capabilities: Map.get(source, :capabilities, []),
       presentation: presentation(source, audience)
     }}
  end

  def project(%{authority: authority}, _audience),
    do: {:error, {:refused, :projection_cannot_widen_authority, authority}}

  def project(_source, _audience), do: {:error, {:refused, :invalid_projection_source}}

  defp presentation(source, :operator) do
    Map.take(source, [:requirement, :plan, :execution, :receipts, :ocel, :replay])
  end

  defp presentation(source, :seller) do
    Map.take(source, [:customer_problem, :desired_outcome, :capabilities, :evidence, :standing])
  end
end
