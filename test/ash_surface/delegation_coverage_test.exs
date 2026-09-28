defmodule AshSurface.DelegationCoverageTest do
  @moduledoc """
  Pins the delegated-fact reading law and profile admission law of the
  `AshSurface` root module and `AshSurface.IR`:

    * `AshSurface.delegated/2` is exactly `AshSurface.IR.delegated/2`, and
      reads a delegated fact only when a delegating authority stored it in
      the entrypoint's `custom.ash_surface` profile — atom-keyed or
      string-keyed section, atom-keyed or string-keyed profile. Anything
      else (no section, a section without a profile map) reads as `nil`:
      never defaulted, never re-derived;
    * `AshSurface.IR.delegated_facts/0` is the frozen four-fact vocabulary
      and every fact of it round-trips through a real `from_manifest/2`
      surface envelope;
    * a profile list carrying a non-JSON value is refused typed, naming the
      offending value, instead of being silently serialized.
  """

  use ExUnit.Case, async: true

  alias Ash.Info.Manifest
  alias Ash.Info.Manifest.{Action, Entrypoint}
  alias AshSurface.IR

  @facts %{
    "semanticId" => "zoe:cap/reinforce",
    "authorityBoundary" => "OBSERVE",
    "doAuthority" => false,
    "receiptRequired" => true
  }

  defp entrypoint(custom) do
    %Entrypoint{
      resource: Helpdesk.Support.Ticket,
      action: struct!(Action, name: :open, type: :create, custom: custom)
    }
  end

  test "delegated_facts/0 is the frozen four-fact vocabulary" do
    assert IR.delegated_facts() ==
             ["semanticId", "authorityBoundary", "doAuthority", "receiptRequired"]
  end

  test "root delegated/2 agrees with IR.delegated/2 on every delegated fact" do
    ep = entrypoint(%{ash_surface: %{"profile" => @facts}})

    for fact <- IR.delegated_facts() do
      assert AshSurface.delegated(ep, fact) == @facts[fact]
      assert AshSurface.delegated(ep, fact) == IR.delegated(ep, fact)
    end
  end

  test "a string-keyed ash_surface section with an atom-keyed profile is read verbatim" do
    ep = entrypoint(%{"ash_surface" => %{profile: @facts}})

    assert Enum.map(IR.delegated_facts(), &IR.delegated(ep, &1)) ==
             ["zoe:cap/reinforce", "OBSERVE", false, true]
  end

  test "absent section or absent profile map reads nil, never a default" do
    no_section = entrypoint(%{other_extension: %{"profile" => @facts}})
    no_profile = entrypoint(%{ash_surface: %{"id" => "Helpdesk.Support.Ticket#open"}})
    bad_profile = entrypoint(%{ash_surface: %{"profile" => "not a map"}})

    for ep <- [no_section, no_profile, bad_profile], fact <- IR.delegated_facts() do
      assert AshSurface.delegated(ep, fact) == nil
    end
  end

  test "delegated facts stored by the profile reach the real surface envelope and decorated manifest" do
    manifest = %Manifest{entrypoints: [entrypoint(%{})]}
    id = "Helpdesk.Support.Ticket#open"

    assert {:ok, surface} =
             AshSurface.from_manifest(manifest, profile: %{"actions" => %{id => @facts}})

    assert [action] = surface.contract["surface"]["actions"]
    assert [decorated] = surface.manifest.entrypoints

    for fact <- IR.delegated_facts() do
      assert action[fact] == @facts[fact]
      assert AshSurface.delegated(decorated, fact) == @facts[fact]
    end

    # Without a delegating profile the same entrypoint carries nil facts.
    assert {:ok, bare} = AshSurface.from_manifest(manifest)
    assert [bare_action] = bare.contract["surface"]["actions"]
    assert Enum.map(IR.delegated_facts(), &bare_action[&1]) == [nil, nil, nil, nil]
  end

  test "a profile list carrying a non-JSON value is refused, naming the value" do
    manifest = %Manifest{entrypoints: []}
    ref = make_ref()

    assert AshSurface.from_manifest(manifest, profile: %{"tags" => ["ok", ref, "later"]}) ==
             {:error, {:profile_value_not_serializable, ref}}

    assert AshSurface.from_manifest(manifest, profile: %{"nested" => [[1, {:tuple}]]}) ==
             {:error, {:profile_value_not_serializable, {:tuple}}}
  end
end
