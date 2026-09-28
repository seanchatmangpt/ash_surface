defmodule AshSurface.TestSupport.VerifiedSurface do
  @moduledoc """
  Test support: seals a hand-built `AshSurface.Surface` so it satisfies the
  single projector contract's trust boundary.

  Every projector runs behind `AshSurface.Projector.IR.to_surface/1`, which
  requires an `Ash.Info.Manifest` and a digest equal to the recomputed
  content address of the contract (`AshSurface.contract_digest/1`). Fixtures
  that hand-build a contract seal it here rather than carry a made-up digest.
  """

  @doc "Returns `surface` with a manifest struct and its true contract digest."
  @spec seal(AshSurface.Surface.t()) :: AshSurface.Surface.t()
  def seal(%AshSurface.Surface{} = surface) do
    manifest =
      case surface.manifest do
        %Ash.Info.Manifest{} = manifest -> manifest
        _ -> %Ash.Info.Manifest{}
      end

    %{surface | manifest: manifest, digest: AshSurface.contract_digest(surface.contract)}
  end
end
