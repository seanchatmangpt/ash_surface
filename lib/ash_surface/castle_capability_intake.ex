defmodule AshSurface.CastleCapabilityIntake do
  @moduledoc """
  CASTLE presentation-capability registry.

  Ash Expo and MMDIO are admitted only as powerless projections behind the
  AshSurface contract. This module does not mutate semantic state.
  """

  @projection_source "seanchatmangpt/ggen-ecosystem@50fdfa20c84205a80c6eb94e916cffbedc4b816e"
  @owner_capability "HUMAN_BOARD_SURFACE"
  @authority_ceiling :construct

  @donors [
    %{repository: "seanchatmangpt/ash_expo", sha: "024852b92330c76e12d0ab26531ef1e511c71041", capability: :mobile_surface, disposition: :wrap, placement: :mobile_surface},
    %{repository: "seanchatmangpt/mmdio", sha: "afc1f6e890a6d1c17b84d5931b21d3c74a851ebc", capability: :semantic_document_projection, disposition: :candidate_wrap, placement: :powerless_document_projection}
  ]

  @spec donors() :: [map()]
  def donors, do: @donors

  @spec projection_source() :: String.t()
  def projection_source, do: @projection_source

  @spec owner_capability() :: String.t()
  def owner_capability, do: @owner_capability

  @spec authority_ceiling() :: :construct
  def authority_ceiling, do: @authority_ceiling

  @spec fetch(String.t()) :: {:ok, map()} | {:error, :unknown_castle_surface_donor}
  def fetch(repository) when is_binary(repository) do
    case Enum.find(@donors, &(&1.repository == repository)) do
      nil -> {:error, :unknown_castle_surface_donor}
      donor -> {:ok, donor}
    end
  end

  @spec canonical_truth?(term()) :: false
  def canonical_truth?(_), do: false

  @spec do_authority?(term()) :: false
  def do_authority?(_), do: false
end
