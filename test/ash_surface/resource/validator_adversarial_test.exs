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
    assert Enum.map(errors, & &1.code) == [code]
    assert Enum.map(errors, & &1.detail) == [detail]
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

      assert Enum.map(errors, & &1.detail) == [
               dup_detail(:a),
               dup_detail(:b),
               dup_detail(:c)
             ]

      assert Enum.all?(errors, &(&1.code == "duplicate_action_projection"))
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

    @tag :documented_gap
    test "TRUTH: forged boundary kinds alone are accepted here - this validator owns uniqueness, not boundary semantics" do
      forged = [
        %{action: :read, id: "r", authority_boundary: "DO"},
        %{action: :create, id: "c", transport: :phoenix_channel}
      ]

      assert :ok = Validator.validate(%{surface: forged})
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
    @tag :documented_gap
    test "GAP: a projection entry without :action crashes instead of returning a typed rejection" do
      assert_raise KeyError, ~r/key :action not found in:\n\n    %{}\n/, fn ->
        Validator.validate(%{surface: [%{action: :get}, %{}]})
      end
    end

    @tag :documented_gap
    test "GAP: a non-map projection entry crashes as a bogus remote call instead of a typed rejection" do
      assert_raise UndefinedFunctionError, ~r/function :read\.action\/0 is undefined/, fn ->
        Validator.validate(%{surface: [:read]})
      end
    end

    @tag :documented_gap
    test "GAP: atom and string spellings of one action name evade the duplicate check" do
      projections = [%{action: :get, id: "1"}, %{action: "get", id: "2"}]

      assert :ok = Validator.validate(%{surface: projections})
    end
  end
end
