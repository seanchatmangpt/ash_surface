defmodule AshSurface.Projector.ExpoActionsTest do
  @moduledoc """
  State-based (Chicago) tests for the `{prefix}.actions.mjs` emission of
  `AshSurface.Projector.Expo`.

  Covers the MX action descriptor contract of the emitted state:

  - stable ids matching `AshSurface.action_id/1`; every admitted action
    present exactly once, nothing extra
  - delegated facts (`semanticId`, `authorityBoundary`, `doAuthority`,
    `receiptRequired`) are emitted exactly as delegated via
    `custom.ash_surface`, and as nil when not delegated (v26.9.16
    delegation); they are never re-derived from action type
  """

  use ExUnit.Case, async: false

  alias Ash.Info.Manifest
  alias AshSurface.Fixtures.VolunteerMilestone
  alias AshSurface.Projector.Expo

  @prefix "zoela_actions_probe"
  @boundaries ~w(OBSERVE SELECT CONSTRUCT DO)
  @mx_descriptor_keys ~w(id semanticId resource action authorityBoundary doAuthority receiptRequired evidenceRequired possibleRefusals)

  @read_id "AshSurface.Fixtures.VolunteerMilestone#read"
  @record_id "AshSurface.Fixtures.VolunteerMilestone#record"

  @freeze_marker "export const ACTIONS = Object.freeze("
  @helper_anchor "export function getAction"

  setup do
    assert {:ok, manifest} =
             Manifest.generate(
               otp_app: :ash_surface,
               action_entrypoints: [
                 {VolunteerMilestone, :record},
                 {VolunteerMilestone, :read}
               ]
             )

    %{manifest: manifest}
  end

  test "descriptors carry exactly the admitted actions with stable ids matching action_id/1",
       ctx do
    %{actions: actions, source: source} = projected(ctx, %{})

    admitted_ids =
      ctx.manifest.entrypoints
      |> Enum.map(&AshSurface.action_id/1)
      |> MapSet.new()

    emitted_ids = Enum.map(actions, & &1["id"])

    # every admitted action present, nothing extra, no duplicates
    assert length(emitted_ids) == map_size(MapSet.new(emitted_ids))
    assert MapSet.new(emitted_ids) == admitted_ids

    # deterministic ordering supports stable consumption of the emitted set
    assert emitted_ids == Enum.sort(emitted_ids)

    for entrypoint <- ctx.manifest.entrypoints do
      id = AshSurface.action_id(entrypoint)

      assert descriptor = Enum.find(actions, &(&1["id"] == id)),
             "admitted action #{id} missing from actions.mjs"

      # MX descriptor shape
      for key <- @mx_descriptor_keys do
        assert Map.has_key?(descriptor, key), "descriptor #{id} missing MX key #{key}"
      end

      # v26.9.16 delegation: with an empty profile no facts are delegated, so
      # each delegated fact surfaces as nil rather than a derived default.
      assert descriptor["semanticId"] == nil
      assert descriptor["resource"] == "AshSurface.Fixtures.VolunteerMilestone"
      assert descriptor["action"] == Atom.to_string(entrypoint.action.name)
      assert descriptor["authorityBoundary"] == nil
      assert descriptor["doAuthority"] == nil
      assert descriptor["receiptRequired"] == nil
      assert is_boolean(descriptor["evidenceRequired"])
      assert is_list(descriptor["possibleRefusals"])
    end

    # the admitted set itself is frozen; clients cannot rewrite boundaries in place
    assert source =~ "Object.freeze("
  end

  test "emitted ids are stable across repeated projections of the same surface", ctx do
    assert {:ok, surface} = AshSurface.from_manifest(ctx.manifest, profile: %{})
    assert {:ok, first, _meta} = AshSurface.project(surface, Expo, prefix: @prefix)
    assert {:ok, second, _meta} = AshSurface.project(surface, Expo, prefix: @prefix)

    assert first["#{@prefix}.actions.mjs"] == second["#{@prefix}.actions.mjs"]

    assert Enum.map(parse_actions!(first["#{@prefix}.actions.mjs"]), & &1["id"]) ==
             Enum.map(parse_actions!(second["#{@prefix}.actions.mjs"]), & &1["id"])
  end

  # v26.9.16 delegation: unprofiled actions delegate no facts, so the boundary
  # and DO authority surface as nil — no OBSERVE/DO inference from action type.
  test "unprofiled actions surface nil delegated facts", ctx do
    %{actions: actions} = projected(ctx, %{})

    assert [%{"id" => @read_id} = read, %{"id" => @record_id} = record] = actions

    assert read["authorityBoundary"] == nil
    assert read["doAuthority"] == nil

    assert record["authorityBoundary"] == nil
    assert record["doAuthority"] == nil
  end

  test "profile-admitted boundaries (SELECT, CONSTRUCT) are emitted verbatim", ctx do
    profile = %{
      "actions" => %{
        @record_id => %{"authorityBoundary" => "SELECT", "semanticId" => "zoe:SelectOption"},
        @read_id => %{"authorityBoundary" => "CONSTRUCT"}
      }
    }

    %{actions: actions} = projected(ctx, profile)

    read = find_action(actions, @read_id)
    record = find_action(actions, @record_id)

    assert record["authorityBoundary"] == "SELECT"
    assert record["semanticId"] == "zoe:SelectOption"
    # v26.9.16 delegation: doAuthority was not delegated, so it surfaces as
    # nil instead of being derived from the boundary.
    assert record["doAuthority"] == nil

    assert read["authorityBoundary"] == "CONSTRUCT"
    assert read["doAuthority"] == nil
  end

  test "a read-typed action admitted at the DO boundary emits as server-authoritative", ctx do
    profile = %{"actions" => %{@read_id => %{"authorityBoundary" => "DO"}}}

    %{actions: actions} = projected(ctx, profile)

    read = find_action(actions, @read_id)

    assert read["authorityBoundary"] == "DO"
    # v26.9.16 delegation: doAuthority is a separate delegated fact; it is no
    # longer derived from the boundary, so it surfaces as nil here.
    assert read["doAuthority"] == nil
  end

  # v26.9.16 delegation: the boundary->doAuthority coupling is gone. Delegated
  # boundaries are emitted verbatim (or nil when not delegated), and doAuthority
  # is never synthesized from the boundary.
  test "delegated boundaries emit verbatim and doAuthority is never synthesized", ctx do
    profiles = [
      %{},
      %{"actions" => %{@record_id => %{"authorityBoundary" => "SELECT"}}},
      %{"actions" => %{@read_id => %{"authorityBoundary" => "CONSTRUCT"}}},
      %{"actions" => %{@read_id => %{"authorityBoundary" => "DO"}}}
    ]

    for profile <- profiles do
      %{actions: actions} = projected(ctx, profile)

      for descriptor <- actions do
        assert descriptor["authorityBoundary"] in @boundaries or
                 is_nil(descriptor["authorityBoundary"])

        assert is_nil(descriptor["doAuthority"]) or is_boolean(descriptor["doAuthority"]),
               "doAuthority for #{descriptor["id"]} is neither delegated nor nil"
      end
    end
  end

  defp projected(%{manifest: manifest}, profile) do
    assert {:ok, surface} = AshSurface.from_manifest(manifest, profile: profile)
    assert {:ok, artifacts, _meta} = AshSurface.project(surface, Expo, prefix: @prefix)

    source = artifacts["#{@prefix}.actions.mjs"]
    %{source: source, actions: parse_actions!(source), surface: surface}
  end

  defp find_action(actions, id) do
    Enum.find(actions, &(&1["id"] == id)) || flunk("action #{id} not emitted")
  end

  defp parse_actions!(source) do
    assert is_binary(source)

    json_start =
      case :binary.match(source, @freeze_marker) do
        {at, len} -> at + len
        :nomatch -> flunk("actions.mjs missing frozen ACTIONS export")
      end

    helper_at =
      case :binary.match(source, @helper_anchor) do
        {at, _len} -> at
        :nomatch -> flunk("actions.mjs missing getAction helper")
      end

    payload =
      source
      |> binary_part(json_start, helper_at - json_start)
      |> String.trim()
      |> String.trim_trailing(";")
      |> String.trim_trailing(")")
      |> String.trim()

    case Jason.decode(payload) do
      {:ok, actions} when is_list(actions) ->
        actions

      other ->
        flunk("ACTIONS payload is not a JSON array: #{inspect(other)}")
    end
  end
end
