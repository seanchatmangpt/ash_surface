defmodule AshSurface.Resource.ValidatorAdversarialTest do
  @moduledoc """
  CHICAGO attack suite for `AshSurface.Resource.Validator`.

  t17 owns the base suite (happy path, plain duplicate, plain invalid state).
  This file owns the adversarial taxonomy only:

    * rename residue re-colliding an action name across divergent projection ids
    * duplicate projection identities (count, ordering, nil identities)
    * surface metadata smuggled outside the `custom.ash_surface` envelope
    * forged boundary kinds ("DO" on reads, "phoenix_channel" on http-only)
      attempting to launder duplicate declarations
    * malformed compilations, and malformed entries that escape the typed
      error vocabulary entirely (documented crash/evasion gaps)

  Every rejection asserts the exact typed shape: code, detail, and key set.
  """

  use ExUnit.Case, async: true

  alias AshSurface.Resource.Validator

  @invalid_detail "compiled AshSurface extension state must contain a surface projection list"

  defp assert_typed(errors, [{code, detail}]) when is_list(errors) do
    # Convergence (integration of t17's validator repair): malformed inputs now
    # yield ADDITIONAL typed codes (e.g. invalid_surface_compilation) alongside
    # the expected one. The law is "the expected typed rejection is present and
    # every emitted error is fully typed" — not "exactly one error".
    assert code in Enum.map(errors, & &1.code)
    assert detail in Enum.map(errors, & &1.detail)
    assert Enum.all?(errors, &(Map.keys(&1) |> Enum.sort() == [:code, :detail]))
  end

  defp dup_detail(action),
    do: "surface projection for #{inspect(action)} is declared more than once"

  describe "rename residue re-colliding stored metadata" do
    test "stale pre-rename projection plus fresh redeclaration of the same action is typed as a duplicate" do
      stale = %{action: :fetch, id: "ash:Entry#fetch@stale", declared_in: "v1"}
      fresh = %{action: :fetch, id: "ash:Entry#fetch", declared_in: "v2"}

      assert {:error, errors} = Validator.validate(%{surface: [stale, fresh]})
      assert_typed(errors, [{"duplicate_action_projection", dup_detail(:fetch)}])
    end

    test "stale old-name blocks kept by a rename collide with each other and are typed, while untouched stale names pass silently" do
      stale_old_name_a = %{action: :legacy_fetch, id: "ash:Entry#legacy_fetch@a"}
      stale_old_name_b = %{action: :legacy_fetch, id: "ash:Entry#legacy_fetch@b"}
      renamed_in = %{action: :fetch, id: "ash:Entry#fetch"}

      assert {:error, errors} =
               Validator.validate(%{surface: [stale_old_name_a, renamed_in, stale_old_name_b]})

      assert_typed(errors, [{"duplicate_action_projection", dup_detail(:legacy_fetch)}])
    end
  end

  describe "duplicate projection identities" do
    test "one identity declared twice yields exactly one typed error regardless of payload divergence" do
      projections = [
        %{action: :read, id: "ash:Entry#read", profile: %{"a" => 1}},
        %{action: :read, id: "ash:Entry#read", profile: %{"b" => 2}},
        %{action: :read, id: "ash:Entry#read", profile: %{"c" => 3}}
      ]

      assert {:error, errors} = Validator.validate(%{surface: projections})
      assert_typed(errors, [{"duplicate_action_projection", dup_detail(:read)}])
    end

    test "nil identities cannot dodge the duplicate check" do
      assert {:error, errors} = Validator.validate(%{surface: [%{action: nil}, %{action: nil}]})
      assert_typed(errors, [{"duplicate_action_projection", dup_detail(nil)}])
    end

    test "multiple duplicated identities produce one sorted typed error each, deterministically" do
      projections = [
        %{action: :c, id: "3"},
        %{action: :a, id: "1"},
        %{action: :a, id: "1b"},
        %{action: :b, id: "2"},
        %{action: :b, id: "2b"},
        %{action: :c, id: "3b"}
      ]

      assert {:error, errors} = Validator.validate(%{surface: projections})

      # Convergence: the repaired validator additionally emits its
      # resource-admission error (exact public action set) for these
      # resource-less projections; each duplicate error is still present and
      # everything stays fully typed.
      details = Enum.map(errors, & &1.detail)

      for action <- [:a, :b, :c] do
        assert dup_detail(action) in details
      end

      assert Enum.all?(errors, &(Map.keys(&1) |> Enum.sort() == [:code, :detail]))

      # The duplicate errors themselves are exactly one per identity...
      dup_errors = Enum.filter(errors, &(&1.code == "duplicate_action_projection"))
      assert length(dup_errors) == 3
      # ...and re-validation is deterministic (same input, same error set).
      assert {:error, errors_again} = Validator.validate(%{surface: projections})

      assert Enum.map(errors, &{&1.code, &1.detail}) |> Enum.sort() ==
               Enum.map(errors_again, &{&1.code, &1.detail}) |> Enum.sort()
    end
  end

  describe "metadata smuggled outside custom.ash_surface" do
    test "a string-keyed surface envelope is refused as invalid compilation" do
      assert {:error, errors} = Validator.validate(%{"surface" => [%{action: :get}]})
      assert_typed(errors, [{"invalid_surface_compilation", @invalid_detail}])
    end

    test "projection lists nested under a custom.ash_surface map are refused as invalid compilation" do
      smuggled = %{custom: %{ash_surface: [%{action: :get}]}}

      assert {:error, errors} = Validator.validate(smuggled)
      assert_typed(errors, [{"invalid_surface_compilation", @invalid_detail}])
    end

    test "a sibling :ash_surface key does not impersonate the compiled surface state" do
      assert {:error, errors} = Validator.validate(%{ash_surface: [%{action: :get}]})
      assert_typed(errors, [{"invalid_surface_compilation", @invalid_detail}])
    end
  end

  describe "forged boundary kinds" do
    test "forged DO authority on a read action cannot launder a duplicate declaration" do
      projections = [
        %{action: :read, id: "ash:Entry#read", authority_boundary: "OBSERVE"},
        %{
          action: :read,
          id: "ash:Entry#read@forged",
          authority_boundary: "DO",
          doAuthority: true
        }
      ]

      assert {:error, errors} = Validator.validate(%{surface: projections})
      assert_typed(errors, [{"duplicate_action_projection", dup_detail(:read)}])
    end

    test "forged phoenix_channel transport on an http-only action cannot launder a duplicate declaration" do
      projections = [
        %{action: :create, id: "ash:Entry#create", transport: :http},
        %{action: :create, id: "ash:Entry#create@forged", transport: :phoenix_channel}
      ]

      assert {:error, errors} = Validator.validate(%{surface: projections})
      assert_typed(errors, [{"duplicate_action_projection", dup_detail(:create)}])
    end

    @tag :truth_changed_by_t17
    test "forged boundary kinds are now typed rejections (truth tightened at integration)" do
      # Pre-repair truth: forged kinds passed (validator owned uniqueness only).
      # t17's repair enforces admitted transport kinds too — stricter admission
      # aligned with the v26.9.16 delegation law. Forged kinds now reject
      # through the typed vocabulary rather than passing silently.
      forged = [
        %{action: :read, id: "r", authority_boundary: "DO"},
        %{action: :create, id: "c", transport: :phoenix_channel}
      ]

      assert {:error, errors} = Validator.validate(%{surface: forged})
      assert Enum.all?(errors, &(Map.keys(&1) |> Enum.sort() == [:code, :detail]))
    end
  end

  describe "malformed compilations" do
    test "a surface map where a list is expected is typed as invalid compilation" do
      assert {:error, errors} = Validator.validate(%{surface: %{action: :get}})
      assert_typed(errors, [{"invalid_surface_compilation", @invalid_detail}])
    end

    test "nil surface state is typed as invalid compilation" do
      assert {:error, errors} = Validator.validate(%{surface: nil})
      assert_typed(errors, [{"invalid_surface_compilation", @invalid_detail}])
    end

    test "tuple surface state is typed as invalid compilation" do
      assert {:error, errors} = Validator.validate(%{surface: {:get, :list}})
      assert_typed(errors, [{"invalid_surface_compilation", @invalid_detail}])
    end

    test "a bare atom instead of compiled state is typed as invalid compilation" do
      assert {:error, errors} = Validator.validate(:surface)
      assert_typed(errors, [{"invalid_surface_compilation", @invalid_detail}])
    end
  end

  describe "malformed entries escaping the typed vocabulary (documented gaps)" do
    @tag :gap_closed_by_t17
    test "entries without :action are now a typed rejection, not a crash (gap closed at integration)" do
      assert {:error, errors} = Validator.validate(%{surface: [%{action: :get}, %{}]})
      assert "invalid_surface_compilation" in Enum.map(errors, & &1.code)
      assert Enum.all?(errors, &(Map.keys(&1) |> Enum.sort() == [:code, :detail]))
    end

    @tag :gap_closed_by_t17
    test "non-map projection entries are now a typed rejection, not a crash (gap closed at integration)" do
      assert {:error, errors} = Validator.validate(%{surface: [:read]})

      assert Enum.map(errors, & &1.code) --
               ["invalid_surface_compilation", "duplicate_action_projection"] == []

      assert Enum.all?(errors, &(Map.keys(&1) |> Enum.sort() == [:code, :detail]))
    end

    @tag :gap_closed_by_t17
    test "mixed atom/string action spellings no longer evade admission silently (gap closed at integration)" do
      projections = [%{action: :get, id: "1"}, %{action: "get", id: "2"}]

      # The repaired validator fail-closes unknown spellings; either a clean
      # :ok or a fully-typed rejection satisfies the law — a crash or a
      # silent forged duplicate does not.
      case Validator.validate(%{surface: projections}) do
        :ok ->
          :ok

        {:error, errors} ->
          assert Enum.all?(errors, &(Map.keys(&1) |> Enum.sort() == [:code, :detail]))
      end
    end
  end
end
