defmodule AshSurface.FuzzFromManifestTest do
  @moduledoc """
  Decode-boundary fuzzing of the `AshSurface.from_manifest/2` profile, the
  untrusted entry point for consumer-authored projection metadata (Chicago
  school: a literal `Ash.Info.Manifest` and the real function; no doubles).

  Laws pinned:

    1. Totality: for ANY profile term (arbitrarily nested data, junk terms:
       tuples, pids, refs, funs, structs, improper lists, non-binary keys) the
       result is `{:ok, %Surface{}}` or `{:error, _}` — never a raise.
    2. Admitted surfaces are sound: the digest is 64 lowercase hex, the same
       profile re-derives the identical digest (determinism), and the contract
       is real JSON (Jason round-trip).
    3. The REFUSED_ prefix law: every `possibleRefusals` entry of an admitted
       contract is `"REFUSED_" <> reason` with a non-empty reason — a profile
       declaring any other refusal string can never reach a contract the JS
       runtime would reject.

  Bounded: 200 cases per property.
  """

  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Ash.Info.Manifest
  alias Ash.Info.Manifest.{Action, Entrypoint}
  alias AshSurface.Fixtures.VolunteerMilestone, as: Post

  @runs 200
  @read_id "AshSurface.Fixtures.VolunteerMilestone#read"

  defp manifest do
    %Manifest{
      entrypoints: [
        %Entrypoint{resource: Post, action: %Action{name: :read, type: :read, custom: %{}}},
        %Entrypoint{resource: Post, action: %Action{name: :record, type: :create, custom: %{}}}
      ]
    }
  end

  defp junk_leaf do
    one_of([
      integer(),
      float(),
      boolean(),
      constant(nil),
      atom(:alphanumeric),
      string(:printable, max_length: 12),
      binary(max_length: 6),
      constant({:a, 1}),
      constant(self()),
      constant(make_ref()),
      constant(&Function.identity/1),
      constant([1 | 2]),
      constant(DateTime.from_unix!(0)),
      constant(MapSet.new())
    ])
  end

  defp key do
    one_of([
      member_of(["actions", "transport", "possibleRefusals", "evidenceRequired", "audience"]),
      string(:alphanumeric, max_length: 6),
      atom(:alphanumeric),
      integer(0..3),
      constant({:k})
    ])
  end

  defp term(0), do: junk_leaf()

  defp term(depth) do
    frequency([
      {4, junk_leaf()},
      {2, list_of(term(depth - 1), max_length: 3)},
      {2, map(list_of({key(), term(depth - 1)}, max_length: 4), &Map.new/1)}
    ])
  end

  defp refusal_string do
    one_of([
      map(string(:alphanumeric, min_length: 1, max_length: 8), &("REFUSED_" <> &1)),
      member_of(["REFUSED", "REFUSED_", "refused_x", "UNKNOWN_AFTER_DISPATCH", "", "X_REFUSED_"])
    ])
  end

  defp action_profile do
    gen all(
          refusals <- one_of([list_of(refusal_string(), max_length: 3), term(1)]),
          evidence <- one_of([boolean(), term(0)]),
          transport <-
            one_of([member_of(["http", "phoenix_channel", "auto", "carrier_pigeon"]), term(0)]),
          extra <- map(list_of({key(), term(1)}, max_length: 2), &Map.new/1)
        ) do
      Map.merge(extra, %{
        "possibleRefusals" => refusals,
        "evidenceRequired" => evidence,
        "transport" => transport
      })
    end
  end

  # Profiles that mostly reach the per-action validators (the interesting depth).
  defp structured_profile do
    gen all(
          top <- map(list_of({key(), term(1)}, max_length: 3), &Map.new/1),
          actions <-
            one_of([
              map(
                list_of(
                  {member_of([
                     @read_id,
                     "AshSurface.Fixtures.VolunteerMilestone#record",
                     "Nope#x"
                   ]), one_of([action_profile(), term(1)])},
                  max_length: 3
                ),
                &Map.new/1
              ),
              term(1)
            ])
        ) do
      Map.put(top, "actions", actions)
    end
  end

  property "from_manifest/2 is total over arbitrary profile terms (never raises)" do
    check all(profile <- one_of([term(3), structured_profile()]), max_runs: @runs) do
      assert match?(
               {:ok, %AshSurface.Surface{}},
               AshSurface.from_manifest(manifest(), profile: profile)
             ) or
               match?({:error, _}, AshSurface.from_manifest(manifest(), profile: profile))
    end
  end

  property "admitted surfaces have hex digests, deterministic derivation, and JSON contracts" do
    check all(profile <- structured_profile(), max_runs: @runs) do
      case AshSurface.from_manifest(manifest(), profile: profile) do
        {:ok, surface} ->
          assert surface.digest =~ ~r/\A[0-9a-f]{64}\z/
          assert {:ok, again} = AshSurface.from_manifest(manifest(), profile: profile)
          assert again.digest == surface.digest
          assert surface.contract |> Jason.encode!() |> Jason.decode!() |> is_map()

        {:error, _} ->
          :ok
      end
    end
  end

  property "every admitted possibleRefusals entry is REFUSED_-prefixed with a reason" do
    check all(profile <- structured_profile(), max_runs: @runs) do
      with {:ok, surface} <- AshSurface.from_manifest(manifest(), profile: profile) do
        for action <- surface.contract["surface"]["actions"],
            code <- Map.get(action, "possibleRefusals", []) do
          assert is_binary(code)
          assert "REFUSED_" <> reason = code
          assert reason != ""
        end
      end
    end
  end

  test "the generators are not vacuous: structured profiles reach both outcomes" do
    outcomes =
      structured_profile()
      |> Enum.take(400)
      |> Enum.map(&elem(AshSurface.from_manifest(manifest(), profile: &1), 0))
      |> Enum.frequencies()

    assert outcomes[:ok] >= 3
    assert outcomes[:error] >= 3
  end

  test "an admitted contract is always JSON-encodable (invalid UTF-8 is refused typed)" do
    profile = %{"actions" => %{}, "transport" => <<128>>}

    case AshSurface.from_manifest(manifest(), profile: profile) do
      {:ok, surface} -> assert is_binary(Jason.encode!(surface.contract))
      {:error, _typed} -> :ok
    end
  end

  test "a non-REFUSED_ refusal string is refused typed" do
    profile = %{"actions" => %{@read_id => %{"possibleRefusals" => ["UNKNOWN_AFTER_DISPATCH"]}}}

    assert {:error, {:possible_refusal_not_a_refusal_code, @read_id, "UNKNOWN_AFTER_DISPATCH"}} =
             AshSurface.from_manifest(manifest(), profile: profile)
  end
end
