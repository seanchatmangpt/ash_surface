defmodule AshSurface.Ported.Rpc.C.NamespaceManifestSurfaceTest do
  @moduledoc """
  Adaptation of the reference namespace_test JSDoc / multi-file tests whose behavior has an
  ash_surface counterpart. The reference asserts the text of generated JSDoc blocks
  (`@ashActionType`, `@namespace`, `@deprecated`, `@see`, description precedence) and the
  grouping of RPC actions by namespace. ash_surface emits no `.ts`; the same facts are the
  machine-readable action manifest (`AshSurface.Manifest.ActionManifest`): `actionType`,
  `resource`, `name`, `namespace`, `description` (entry > action > none), `deprecated`
  (false | true | message) and `see` (camelCased function names). Typed query descriptions are
  carried by `AshSurface.Manifest.Dsl`.

  Real inline Spark resources, real `Ash.Info.Manifest`, no doubles. The tests that assert
  only JSDoc/TypeScript layout stay loud skips in `namespace_gap_test.exs`.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Manifest.{ActionManifest, Dsl}
  alias AshSurface.RuntimeParity.Rpc.Pipeline, as: E

  defmodule Doc do
    use Ash.Resource,
      domain: nil,
      data_layer: Ash.DataLayer.Simple,
      validate_domain_inclusion?: false,
      extensions: [AshSurface.Resource]

    attributes do
      uuid_primary_key(:id, public?: true)
      attribute(:title, :string, public?: true)
    end

    actions do
      defaults([:read, :destroy])
      create(:create, do: accept([:title]))
      read(:described, do: description("Fetches all todos for the current user"))
      read(:undescribed)
      read(:list)
    end

    surface do
      projection :read
      projection :described
      projection :undescribed
      projection :list

      typed_query :with_description, :read do
        description("Custom typed query description")
        fields([:id, :title])
      end

      typed_query :without_description, :read do
        fields([:id])
      end
    end
  end

  defmodule Scoped do
    use Ash.Resource,
      domain: nil,
      data_layer: Ash.DataLayer.Simple,
      validate_domain_inclusion?: false,
      extensions: [AshSurface.Resource]

    attributes do
      uuid_primary_key(:id, public?: true)
    end

    actions do
      defaults([:read])
    end

    surface do
      namespace("settings")
      projection :read
    end
  end

  defmodule NsDomain do
    use Ash.Domain, validate_config_inclusion?: false, extensions: [AshSurface.Domain]

    surface do
      namespace("second")
    end

    resources do
      allow_unregistered?(true)
    end
  end

  defmodule DomainOnly do
    use Ash.Resource,
      domain: NsDomain,
      data_layer: Ash.DataLayer.Simple,
      validate_domain_inclusion?: false,
      extensions: [AshSurface.Resource]

    attributes do
      uuid_primary_key(:id, public?: true)
    end

    actions do
      defaults([:read])
    end

    surface do
      projection :read
    end
  end

  defmodule DomainOverridden do
    use Ash.Resource,
      domain: NsDomain,
      data_layer: Ash.DataLayer.Simple,
      validate_domain_inclusion?: false,
      extensions: [AshSurface.Resource]

    attributes do
      uuid_primary_key(:id, public?: true)
    end

    actions do
      defaults([:read])
    end

    surface do
      namespace("resource_ns")
      projection :read
    end
  end

  setup_all do
    {:ok, manifest} =
      Ash.Info.Manifest.generate(
        otp_app: :ash_surface,
        action_entrypoints: [
          {Doc, :read},
          {Doc, :described},
          {Doc, :undescribed},
          {Doc, :list},
          {Doc, :create},
          {Doc, :destroy},
          {Scoped, :read},
          {DomainOnly, :read},
          {DomainOverridden, :read}
        ]
      )

    %{manifest: manifest}
  end

  defp build(manifest, entries), do: ActionManifest.build(manifest, entries)

  defp action(manifest, entry, opts \\ []) do
    entry = E.entry(entry, Doc, Keyword.get(opts, :action, :read), Keyword.drop(opts, [:action]))
    [a] = build(manifest, [entry])["actions"]
    a
  end

  test "006 actions in the entry table have correct resolved namespaces", %{manifest: m} do
    entries = [
      E.entry(:list_todos, Doc, :read, namespace: "todos"),
      E.entry(:list_todos_deprecated, Doc, :read, namespace: "todos"),
      E.entry(:list_todos_with_custom_description, Doc, :read, namespace: "todos"),
      E.entry(:list_users, Doc, :list, namespace: "users"),
      E.entry(:create_todo, Doc, :create),
      E.entry(:get_todo, Doc, :read),
      E.entry(:list_settings, Scoped, :read)
    ]

    grouped =
      m
      |> build(entries)
      |> Map.fetch!("actions")
      |> Enum.group_by(& &1["namespace"], & &1["name"])
      |> Map.new(fn {k, v} -> {k, Enum.sort(v)} end)

    assert grouped["todos"] ==
             Enum.sort(~w(list_todos list_todos_deprecated list_todos_with_custom_description))

    assert grouped["users"] == ["list_users"]
    assert grouped[nil] == Enum.sort(~w(create_todo get_todo))
    # resource-level namespace applies when the entry sets none
    assert grouped["settings"] == ["list_settings"]
  end

  test "domain namespace: entry > resource > domain, with namespaces aggregation", %{manifest: m} do
    entries = [
      E.entry(:dom_default, DomainOnly, :read),
      E.entry(:dom_entry, DomainOnly, :read, namespace: "entry_ns"),
      E.entry(:dom_resource, DomainOverridden, :read),
      E.entry(:dom_entry2, DomainOverridden, :read, namespace: "entry_ns"),
      E.entry(:no_ns, Doc, :create)
    ]

    built = build(m, entries)
    by_name = Map.new(built["actions"], &{&1["name"], &1["namespace"]})

    assert by_name == %{
             "dom_default" => "second",
             "dom_entry" => "entry_ns",
             "dom_resource" => "resource_ns",
             "dom_entry2" => "entry_ns",
             "no_ns" => nil
           }

    assert built["namespaces"] == ["entry_ns", "resource_ns", "second"]
    assert build(m, [E.entry(:no_ns, Doc, :create)])["namespaces"] == []
  end

  test "010 generate_jsdoc includes all metadata", %{manifest: m} do
    a = action(m, :list, namespace: "todos")
    assert a["actionType"] == "read"
    assert a["resource"] == "Doc"
    assert a["name"] == "list"
    assert a["namespace"] == "todos"
    assert a["functionName"] == "list"
  end

  test "011 generate_jsdoc omits namespace when not provided", %{manifest: m} do
    a = action(m, :create_doc, action: :create)
    assert a["actionType"] == "create"
    assert a["resource"] == "Doc"
    assert a["namespace"] == nil
  end

  describe "description precedence (entry > action > none)" do
    test "018 action description is carried when the entry has none", %{manifest: m} do
      assert action(m, :list_described, action: :described)["description"] ==
               "Fetches all todos for the current user"
    end

    test "019 no description when the action description is nil", %{manifest: m} do
      assert action(m, :list_undescribed, action: :undescribed)["description"] == ""
    end

    test "020 no description when the entry description is empty and the action has none", %{
      manifest: m
    } do
      assert action(m, :list_empty, action: :undescribed, description: "")["description"] == ""
    end

    test "022 entry description has highest priority", %{manifest: m} do
      a = action(m, :list_pub, action: :described, description: "Public RPC description")
      assert a["description"] == "Public RPC description"
    end

    test "023 entry description is shown regardless of the internals toggle", %{manifest: m} do
      for flag <- [true, false] do
        prev = Application.fetch_env(:ash_surface, :add_ash_internals_to_jsdoc)
        Application.put_env(:ash_surface, :add_ash_internals_to_jsdoc, flag)

        try do
          a = action(m, :list_pub, action: :described, description: "Public RPC description")
          assert a["description"] == "Public RPC description"
        after
          case prev do
            {:ok, v} -> Application.put_env(:ash_surface, :add_ash_internals_to_jsdoc, v)
            :error -> Application.delete_env(:ash_surface, :add_ash_internals_to_jsdoc)
          end
        end
      end
    end

    test "024 falls back to action description when the entry description is nil", %{manifest: m} do
      assert action(m, :list_nil, action: :described, description: nil)["description"] ==
               "Fetches all todos for the current user"
    end

    test "025 falls back when the entry description is empty", %{manifest: m} do
      assert action(m, :list_blank, action: :described, description: "")["description"] ==
               "Fetches all todos for the current user"
    end

    test "034 entry description appears in the manifest", %{manifest: m} do
      a =
        action(m, :list_todos_with_custom_description,
          description: "Fetch todos with a custom public description"
        )

      assert a["description"] == "Fetch todos with a custom public description"
    end
  end

  describe "deprecated" do
    test "026 includes the deprecation message", %{manifest: m} do
      assert action(m, :list, deprecated: "Use listTodosV2 instead")["deprecated"] ==
               "Use listTodosV2 instead"
    end

    test "027 is true when set to true", %{manifest: m} do
      assert action(m, :list, deprecated: true)["deprecated"] == true
    end

    test "028 is false when false or nil or unset", %{manifest: m} do
      assert action(m, :list, deprecated: false)["deprecated"] == false
      assert action(m, :list, deprecated: nil)["deprecated"] == false
      assert action(m, :list)["deprecated"] == false
    end
  end

  describe "see" do
    test "029 includes related actions as function names", %{manifest: m} do
      assert action(m, :list, see: [:create_todo, :get_todo])["see"] == ["createTodo", "getTodo"]
    end

    test "030 is empty when empty, nil or unset", %{manifest: m} do
      assert action(m, :list, see: [])["see"] == []
      assert action(m, :list, see: nil)["see"] == []
      assert action(m, :list)["see"] == []
    end
  end

  describe "typed query description" do
    test "032 uses custom description" do
      assert %{"typed_queries" => queries} = Dsl.serialize(Doc)
      q = Enum.find(queries, &(&1["name"] == "with_description"))
      assert q["description"] == "Custom typed query description"
    end

    test "033 carries no description when none is declared" do
      assert %{"typed_queries" => queries} = Dsl.serialize(Doc)
      q = Enum.find(queries, &(&1["name"] == "without_description"))
      refute Map.has_key?(q, "description")
    end
  end

  test "037 get_rpc_resources_by_namespace groups actions correctly", %{manifest: m} do
    entries = [
      E.entry(:list_todos, Doc, :read, namespace: "todos"),
      E.entry(:create_todo, Doc, :create),
      E.entry(:get_todo, Doc, :read)
    ]

    grouped = m |> build(entries) |> Map.fetch!("actions") |> Enum.group_by(& &1["namespace"])
    assert Map.has_key?(grouped, nil)
    assert is_list(grouped[nil])
    assert grouped[nil] != []
    assert length(grouped["todos"]) == 1
  end

  describe "namespace precedence and entry identity facts (mutation-killing)" do
    test "entry namespace beats the resource-level namespace; atoms are stringified", %{
      manifest: m
    } do
      [over] = build(m, [E.entry(:list_settings, Scoped, :read, namespace: "override")])["actions"]
      assert over["namespace"] == "override"

      [atom_ns] = build(m, [E.entry(:list_settings, Scoped, :read, namespace: :atomic)])["actions"]
      assert atom_ns["namespace"] == "atomic"

      [inherited] = build(m, [E.entry(:list_settings, Scoped, :read)])["actions"]
      assert inherited["namespace"] == "settings"

      # no domain on these resources and none declared: no namespace at all
      assert action(m, :list)["namespace"] == nil
    end

    test "name, functionName, actionType and get flag are exact", %{manifest: m} do
      a = action(m, :list_todos_deprecated, action: :list)
      assert a["name"] == "list_todos_deprecated"
      assert a["functionName"] == "listTodosDeprecated"
      assert a["get"] == false

      assert action(m, :one, action: :list, get?: true)["get"] == true
      assert action(m, :one, action: :list, get_by: [:id])["get"] == true
      assert action(m, :one, action: :list, get_by: [])["get"] == false

      assert action(m, :rm, action: :destroy)["actionType"] == "destroy"
      assert action(m, :mk, action: :create)["actionType"] == "create"
      assert action(m, :ls, action: :list)["actionType"] == "read"
    end

    test "read-only flags follow the action type and entry options", %{manifest: m} do
      read = action(m, :ls, action: :list)
      assert read["enableFilter"] == true
      assert read["enableSort"] == true

      off = action(m, :ls, action: :list, enable_filter?: false, enable_sort?: false)
      assert off["enableFilter"] == false
      assert off["enableSort"] == false

      create = action(m, :mk, action: :create)
      assert create["enableFilter"] == false
      assert create["enableSort"] == false
    end

    test "entry keys are the exact manifest vocabulary", %{manifest: m} do
      assert action(m, :ls, action: :list) |> Map.keys() |> Enum.sort() ==
               ~w(actionType deprecated description enableFilter enableSort functionName get hasFields input metadataFields name namespace pagination resource see)
    end

    test "actions keep entry order per namespace and group sizes are exact", %{manifest: m} do
      entries = [
        E.entry(:b_two, Doc, :read, namespace: "x"),
        E.entry(:a_one, Doc, :read, namespace: "x"),
        E.entry(:c_three, Doc, :read, namespace: "y")
      ]

      acts = build(m, entries)["actions"]
      by_ns = Enum.group_by(acts, & &1["namespace"], & &1["functionName"])
      assert Map.keys(by_ns) |> Enum.sort() == ["x", "y"]
      assert Enum.sort(by_ns["x"]) == ["aOne", "bTwo"]
      assert by_ns["y"] == ["cThree"]
      assert length(acts) == 3
    end
  end
end
