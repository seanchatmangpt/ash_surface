defmodule AshSurface.TrustBoundaryTest do
  @moduledoc """
  Trust-boundary law: a `%Surface{}` digest is a verified fact, not a claim.
  IR (`Projector.IR.to_surface/1`) and `MXEpisode.compose/1` recompute the
  content address of the carried contract with `AshSurface.contract_digest/1`
  (the same function `from_manifest/2` mints with) and refuse a mismatch with
  the typed `{:surface_digest_mismatch, claimed, actual}`.
  """
  use ExUnit.Case, async: true

  alias AshSurface.{Event, MXEpisode, Observation, PlanningEpisode}
  alias AshSurface.Projector.IR

  defp real_surface do
    {:ok, surface} =
      AshSurface.from_manifest(%Ash.Info.Manifest{entrypoints: []}, profile: %{"tier" => "gold"})

    surface
  end

  defp loop(surface) do
    observation = Observation.create("sp:ticket:trust", %{"status" => "open"})

    %{
      observation: observation,
      planning_episode:
        PlanningEpisode.create("ws:trust", planner_identity: "ash_pplan", policy_identity: "p:1"),
      event: Event.create(observation.exact_subject, 1, "state.changed"),
      surface: surface,
      receipt_hash: String.duplicate("7", 64),
      subject_repo: "r",
      subject_head: "h",
      consequence_id: "c"
    }
  end

  test "contract_digest/1 is the digest from_manifest mints" do
    surface = real_surface()
    assert AshSurface.contract_digest(surface.contract) == surface.digest
    assert AshSurface.verify_surface_digest(surface) == :ok
  end

  describe "Projector.IR.to_surface/1" do
    test "round-trips a real surface with its digest verified" do
      surface = real_surface()
      {:ok, ir} = IR.from_surface(surface)
      assert {:ok, ^surface} = IR.to_surface(ir)
    end

    test "refuses a well-formed but forged digest" do
      surface = real_surface()
      forged = String.duplicate("a", 64)
      {:ok, ir} = IR.from_surface(%{surface | digest: forged})

      assert {:error, {:surface_digest_mismatch, ^forged, actual}} = IR.to_surface(ir)
      assert actual == surface.digest
    end

    test "refuses a tampered contract carrying the original digest" do
      surface = real_surface()
      tampered = put_in(surface.contract, ["surface", "profile", "tier"], "platinum")
      {:ok, ir} = IR.from_surface(%{surface | contract: tampered})

      assert {:error, {:surface_digest_mismatch, claimed, actual}} = IR.to_surface(ir)
      assert claimed == surface.digest
      assert actual == AshSurface.contract_digest(tampered)
      refute actual == claimed
    end

    test "a forged surface never reaches a surface-consuming projector" do
      forged = %{real_surface() | digest: String.duplicate("b", 64)}
      {:ok, ir} = IR.from_surface(forged)

      assert {:error, {:surface_digest_mismatch, _, _}} =
               IR.project(AshSurface.Projector.VoiceKiosk, ir, [])

      # The public facade dispatches through the same contract: no bypass.
      assert {:error, {:surface_digest_mismatch, _, _}} =
               AshSurface.project(forged, AshSurface.Projector.Expo)
    end
  end

  describe "MXEpisode.compose/1" do
    test "binds a verified surface digest" do
      surface = real_surface()
      assert {:ok, episode} = MXEpisode.compose(loop(surface))

      assert Enum.find(episode["observed_transitions"], &(&1["step"] == "authorize_candidate"))[
               "surface_digest"
             ] == surface.digest
    end

    test "refuses a well-formed digest that does not address the contract" do
      forged = String.duplicate("a", 64)
      surface = %{real_surface() | digest: forged}

      assert {:error, {:surface_digest_mismatch, ^forged, actual}} =
               MXEpisode.compose(loop(surface))

      assert actual == real_surface().digest
    end

    test "format is still refused first, as an invalid digest" do
      surface = %{real_surface() | digest: "short"}

      assert {:error, {:invalid_surface_digest, "short"}} = MXEpisode.compose(loop(surface))
    end
  end
end
