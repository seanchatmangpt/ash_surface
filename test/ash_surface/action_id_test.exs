defmodule AshSurface.ActionIdTest do
  @moduledoc """
  Chicago-school, table-driven state tests of `AshSurface.action_id/1`.

  Law under test — the action_id stability law:

    1. Stability: the same resource + action yields the identical id forever.
       The id is a pure function of `{resource, action.name}` — no timestamps,
       no randomness, no runtime introspection, no environment.
    2. Uniqueness: ids are injective across (resource, action) pairs — distinct
       resources and distinct actions never collide.
    3. Projection safety: ids contain only shell/CI/tracker-safe characters.
    4. Round-trip: ids survive manifest serialization (profile keying,
       decorated manifest custom data, JSON contract encode/decode) and
       decompose back into exactly their serialized resource and action.

  The golden tables below are FROZEN. Any drift in id format, separator,
   salting, or ordering must break this build.
  """

  use ExUnit.Case, async: true

  alias Ash.Info.Manifest
  alias Ash.Info.Manifest.{Action, Entrypoint}
  alias AshSurface

  # ---------------------------------------------------------------------------
  # Frozen golden table: {resource, action_name, exact frozen id}
  # ---------------------------------------------------------------------------

  @golden_ids [
    {MyApp.Accounts.User, :read, "MyApp.Accounts.User#read"},
    {MyApp.Accounts.User, :sign_in_with_password, "MyApp.Accounts.User#sign_in_with_password"},
    {MyApp.Billing.Invoice, :issue_refund, "MyApp.Billing.Invoice#issue_refund"},
    {MyApp.Billing.Invoice.V2, :migrate_ledger_2, "MyApp.Billing.Invoice.V2#migrate_ledger_2"},
    {Zoela.Mx.Episode, :record_observation, "Zoela.Mx.Episode#record_observation"},
    {Support.Simple, :create, "Support.Simple#create"}
  ]

  @golden_id_strings Enum.map(@golden_ids, &elem(&1, 2))

  # The frozen projection of the whole table, independent of the rows above.
  @golden_table_projection Enum.sort(@golden_id_strings)

  # Cross-product table for the uniqueness law.
  @uniqueness_resources [
    Helpdesk.Support.Ticket,
    Helpdesk.Support.Resource,
    MyApp.Accounts.User,
    MyApp.Accounts.Session
  ]

  @uniqueness_actions [:read, :create, :update, :destroy, :sign_in]

  # Safe alphabet: printable ASCII identifier segments, dots between module
  # segments, and exactly one `#` separator. Anything else — whitespace, shell
  # metacharacters, quotes, globs, path/flag triggers, non-ASCII — is unsafe.
  @id_shape ~r/\A[A-Za-z0-9_]+(\.[A-Za-z0-9_]+)*#[A-Za-z0-9_]+\z/
  @unsafe_characters ~r/[\s"'`\\$&;|<>(){}\[\]*?!~^%,:=\/@]/
  @printable_ascii_range 33..126

  defp entrypoint(resource, action_name, action_opts \\ []) do
    action = struct!(Action, Keyword.put(action_opts, :name, action_name))

    %Entrypoint{resource: resource, action: action}
  end

  defp golden_manifest do
    entrypoints =
      Enum.map(@golden_ids, fn {resource, action_name, _id} ->
        entrypoint(resource, action_name, type: :action, custom: %{})
      end)

    %Manifest{entrypoints: entrypoints}
  end

  describe "stability: frozen golden ids (any drift breaks the build)" do
    test "every frozen golden id is reproduced exactly" do
      for {resource, action_name, frozen_id} <- @golden_ids do
        actual_id = AshSurface.action_id(entrypoint(resource, action_name))

        assert actual_id == frozen_id,
               "action_id drift for #{inspect(resource)}##{action_name}: " <>
                 "expected #{inspect(frozen_id)}, got #{inspect(actual_id)}"
      end
    end

    test "the golden table projects to the frozen list of ids" do
      ids =
        Enum.map(@golden_ids, fn {resource, action_name, _id} ->
          AshSurface.action_id(entrypoint(resource, action_name))
        end)
        |> Enum.sort()

      assert ids == @golden_table_projection
    end
  end

  describe "stability: id is a pure function of resource and action name" do
    @identity_table [
      {MyApp.Accounts.User, :read, [type: :read]},
      {MyApp.Accounts.User, :read, [type: :action]},
      {MyApp.Accounts.User, :read, [type: :read, description: "changed", primary?: true]},
      {MyApp.Billing.Invoice, :issue_refund, [type: :create, get?: true, inputs: []]}
    ]

    test "non-identity action fields never change the id" do
      for {resource, action_name, action_opts} <- @identity_table do
        base = AshSurface.action_id(entrypoint(resource, action_name))
        varied = AshSurface.action_id(entrypoint(resource, action_name, action_opts))

        assert varied == base
      end
    end

    test "entrypoint config and custom data never change the id" do
      resource = Zoela.Mx.Episode
      plain = entrypoint(resource, :record_observation)
      decorated = %Entrypoint{plain | config: %{router: :anything}, custom: %{tracker: 7}}

      assert AshSurface.action_id(plain) == AshSurface.action_id(decorated)
    end

    test "the id is deterministic across repeated calls and fresh input structs" do
      for {resource, action_name, frozen_id} <- @golden_ids do
        ids = for _ <- 1..100, do: AshSurface.action_id(entrypoint(resource, action_name))

        assert Enum.uniq(ids) == [frozen_id]
      end
    end

    test "undefined resources get a static id: no runtime introspection or env" do
      id = AshSurface.action_id(entrypoint(AshSurface.ActionIdTest.Never.Defined, :peek))

      assert id == "AshSurface.ActionIdTest.Never.Defined#peek"
      refute Code.ensure_loaded?(AshSurface.ActionIdTest.Never.Defined)
    end
  end

  describe "uniqueness across resources and actions" do
    test "the (resource x action) cross-product yields pairwise distinct ids" do
      ids =
        for resource <- @uniqueness_resources,
            action_name <- @uniqueness_actions do
          AshSurface.action_id(entrypoint(resource, action_name))
        end

      assert length(ids) == length(@uniqueness_resources) * length(@uniqueness_actions)
      assert Enum.uniq(ids) == ids
    end

    test "distinct actions on one resource never collide" do
      ids =
        Enum.map(@uniqueness_actions, &AshSurface.action_id(entrypoint(MyApp.Accounts.User, &1)))

      assert Enum.uniq(ids) == ids
    end

    test "the same action on distinct resources never collides" do
      ids =
        Enum.map(@uniqueness_resources, &AshSurface.action_id(entrypoint(&1, :sign_in)))

      assert Enum.uniq(ids) == ids
    end

    test "the golden table itself is collision-free" do
      assert length(Enum.uniq(@golden_id_strings)) == length(@golden_id_strings)
    end
  end

  describe "projection safety: shell, CI, and tracker safe characters only" do
    test "every golden id matches the safe id shape" do
      for id <- @golden_id_strings do
        assert Regex.match?(@id_shape, id), "unsafe id shape: #{inspect(id)}"
      end
    end

    test "the uniqueness cross-product matches the safe id shape" do
      for resource <- @uniqueness_resources,
          action_name <- @uniqueness_actions do
        assert Regex.match?(@id_shape, AshSurface.action_id(entrypoint(resource, action_name)))
      end
    end

    test "ids contain no shell metacharacters, quotes, globs, or whitespace" do
      for id <- @golden_id_strings do
        refute Regex.match?(@unsafe_characters, id), "unsafe characters in #{inspect(id)}"
      end
    end

    test "ids are printable ASCII only (byte 33..126), so no unicode surprises" do
      for id <- @golden_id_strings do
        assert byte_size(id) > 0
        assert Enum.all?(String.to_charlist(id), &Enum.member?(@printable_ascii_range, &1))
      end
    end

    test "the `#` appears exactly once, as the resource/action separator" do
      for id <- @golden_id_strings do
        # A two-element split pins the separator count to exactly one.
        assert [resource_part, action_part] = String.split(id, "#")

        assert resource_part != ""
        assert action_part != ""
      end
    end

    test "ids never start with `-` or `.` (CLI flag and path traversal safe)" do
      for id <- @golden_id_strings do
        refute String.starts_with?(id, "-")
        refute String.starts_with?(id, ".")
      end
    end
  end

  describe "round-trips within manifest serialization" do
    test "golden ids are accepted as profile keys and re-emerge as surface ids" do
      profile = %{actions: Map.new(@golden_id_strings, &{&1, %{consumer: :web}})}

      assert {:ok, surface} = AshSurface.from_manifest(golden_manifest(), profile: profile)

      assert surface.action_ids == Enum.sort(@golden_id_strings)
    end

    test "the decorated manifest carries each id in custom.ash_surface" do
      assert {:ok, surface} = AshSurface.from_manifest(golden_manifest())
      decorated_ids = Enum.map(surface.manifest.entrypoints, & &1.action.custom.ash_surface["id"])

      assert Enum.sort(decorated_ids) == Enum.sort(@golden_id_strings)
    end

    test "ids survive JSON contract encode/decode and decompose to their parts" do
      assert {:ok, surface} = AshSurface.from_manifest(golden_manifest())

      decoded =
        surface.contract
        |> Jason.encode!()
        |> Jason.decode!()

      serialized_actions = decoded["surface"]["actions"]
      assert length(serialized_actions) == length(@golden_ids)

      for {resource, action_name, frozen_id} <- @golden_ids do
        action = Enum.find(serialized_actions, &(&1["id"] == frozen_id))

        assert action != nil, "id #{inspect(frozen_id)} lost by manifest serialization"

        # Round-trip identity: the serialized id decomposes into exactly the
        # serialized resource and action strings.
        assert action["resource"] == resource |> Module.split() |> Enum.join(".")
        assert action["action"] == to_string(action_name)
        assert action["id"] == action["resource"] <> "#" <> action["action"]

        # v26.9.16 delegation: semanticId is a delegated fact. No profile
        # delegates it here, so it surfaces as nil instead of a derived
        # "ash:<id>" default.
        assert action["semanticId"] == nil
      end
    end

    test "serialized Ash manifest resource strings agree with the id prefixes" do
      assert {:ok, surface} = AshSurface.from_manifest(golden_manifest())

      serialized_resources =
        surface.contract["manifest"]["entrypoints"]
        |> Enum.map(& &1["resource"])
        |> Enum.uniq()
        |> Enum.sort()

      expected_resources =
        @golden_ids
        |> Enum.map(fn {resource, _action_name, _id} ->
          resource |> Module.split() |> Enum.join(".")
        end)
        |> Enum.uniq()
        |> Enum.sort()

      assert serialized_resources == expected_resources

      # Each id's prefix is exactly its entrypoint's serialized resource string.
      for {resource, _action_name, id} <- @golden_ids do
        resource_string = resource |> Module.split() |> Enum.join(".")
        assert String.starts_with?(id, resource_string <> "#")
      end
    end
  end
end
