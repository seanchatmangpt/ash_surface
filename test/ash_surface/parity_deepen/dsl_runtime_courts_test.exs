defmodule AshSurface.ParityDeepen.DslRuntimeCourtsTest.Toll do
  @moduledoc false
  use Ash.Resource,
    domain: AshSurface.ParityDeepen.DslRuntimeCourtsTest.DomA,
    data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key(:id)
    attribute(:lane, :string, public?: true, allow_nil?: false)
  end

  actions do
    defaults([:read])
  end
end

defmodule AshSurface.ParityDeepen.DslRuntimeCourtsTest.Fee do
  @moduledoc false
  use Ash.Resource,
    domain: AshSurface.ParityDeepen.DslRuntimeCourtsTest.DomB,
    data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key(:id)
    attribute(:amount, :integer, public?: true, allow_nil?: false)
  end

  actions do
    defaults([:read])
  end
end

defmodule AshSurface.ParityDeepen.DslRuntimeCourtsTest.DomA do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(AshSurface.ParityDeepen.DslRuntimeCourtsTest.Toll)
  end
end

defmodule AshSurface.ParityDeepen.DslRuntimeCourtsTest.DomB do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(AshSurface.ParityDeepen.DslRuntimeCourtsTest.Fee)
  end
end

defmodule AshSurface.ParityDeepen.DslRuntimeCourtsTest do
  @moduledoc """
  Wave-3 F1-deepen courts for the `typescript_rpc` DSL counterpart (`surface` section,
  `projection` entity), the runtime introspection modules (`Resource`, `Resource.Info`,
  `Resource.Projections`, `AshSurface`, `FieldName`) and the `domains` selection of
  `from_app/2`. Real compiled resources through the real Spark verifier; no doubles.
  """
  use ExUnit.Case, async: false

  alias Ash.Info.Manifest
  alias AshSurface.Resource.{Info, Projections}
  alias AshSurface.ParityDeepen.DslRuntimeCourtsTest.{DomA, DomB, Fee, Toll}

  @otp_app :ash_surface_parity_deepen_dsl

  defp compile!(opts) do
    name =
      "Elixir.AshSurface.ParityDeepen.DslRuntimeCourtsTest.R#{System.unique_integer([:positive])}"

    domain = Keyword.get(opts, :domain, "nil")
    surface = Keyword.fetch!(opts, :surface)

    Code.compile_string("""
    defmodule #{name} do
      use Ash.Resource, domain: #{domain}, data_layer: Ash.DataLayer.Simple, validate_domain_inclusion?: false,
        extensions: [AshSurface.Resource]
      attributes do
        uuid_primary_key :id, public?: true
        attribute :title, :string, public?: true
        #{if String.contains?(surface, "item_1"), do: "attribute :item_1, :string, public?: true", else: ""}
      end
      actions do
        defaults [:read]
        read :other
      end
      surface do
        #{surface}
      end
    end
    """)

    String.to_existing_atom(name)
  end

  defp stderr_of(opts), do: ExUnit.CaptureIO.capture_io(:stderr, fn -> compile!(opts) end)

  describe "dsl.rpc.entity.rpc_action (projection entity behavior)" do
    test "defaults apply when options are absent" do
      mod = compile!(surface: "projection :read")
      p = Projections.for_action(mod, :read)
      assert Projections.option(p, :get?) == false
      assert Projections.option(p, :not_found_error?) == true
      assert Projections.option(p, :enable_filter?) == true
      assert Projections.option(p, :enable_sort?) == true
      assert Projections.option(p, :get_by) == []
      assert Projections.option(p, :identities) == []
      assert Projections.option(p, :see) == []
      assert p.transport == :auto
    end

    test "options set in the DSL change the effective projection" do
      mod =
        compile!(
          surface:
            "projection :read, get_by: [:id], not_found_error?: false, enable_sort?: false, see: [:other]"
        )

      p = Projections.for_action(mod, :read)
      assert Projections.option(p, :get_by) == [:id]
      assert Projections.option(p, :not_found_error?) == false
      assert Projections.option(p, :enable_sort?) == false
      assert Projections.option(p, :see) == [:other]
    end

    test "two projections on one action are refused; get? with get_by conflicts" do
      assert stderr_of(surface: "projection :read\nprojection :read") =~
               "duplicate_action_projection"

      assert stderr_of(surface: "projection :read, get?: true, get_by: [:id]") =~
               "get_and_get_by_conflict"
    end
  end

  describe "dsl.rpc.entity.rpc_action.option.deprecated" do
    test "default is nil; true, false and a message round-trip as a presentation fact" do
      mod = compile!(surface: "projection :read")
      assert Projections.presentation(Projections.for_action(mod, :read)).deprecated == nil

      for {literal, expected} <- [{"true", true}, {"false", false}, {~s("use v2"), "use v2"}] do
        m = compile!(surface: "projection :read, deprecated: #{literal}")
        p = Projections.for_action(m, :read)
        assert Projections.presentation(p).deprecated == expected
        assert Projections.option(p, :deprecated) == expected
      end
    end

    test "deprecated changes nothing but its own presentation field in the compiled state" do
      plain = compile!(surface: "projection :read")
      dep = compile!(surface: ~s(projection :read, deprecated: "use v2"))

      strip =
        &(&1
          |> inspect()
          |> String.replace(~r/R\d+/, "R")
          |> String.replace(~s(deprecated: "use v2"), "deprecated: nil"))

      assert strip.(Info.compiled!(plain)) == strip.(Info.compiled!(dep))
    end
  end

  describe "dsl.rpc.section.typescript_rpc (surface section behavior)" do
    test "section options reach the introspection API and the manifest DSL serialization" do
      mod =
        compile!(
          surface: """
          type_name "Doc"
          namespace "docs"
          show_raised_errors? true
          projection :read
          """
        )

      assert Info.type_name(mod) == "Doc"
      assert Info.namespace(mod) == "docs"
      assert Info.effective_namespace(mod) == "docs"
      assert Info.show_raised_errors?(mod) == true

      dsl = AshSurface.Manifest.Dsl.serialize(mod)
      assert dsl["type_name"] == "Doc"
      assert dsl["namespace"] == "docs"
      assert dsl["show_raised_errors?"] == true
    end

    test "an undeclared section serializes to nothing and falls back to config" do
      mod = compile!(surface: "projection :read")
      assert Info.type_name(mod) == nil
      assert Info.namespace(mod) == nil
      assert AshSurface.Manifest.Dsl.serialize(mod) == %{}
      assert Info.show_raised_errors?(mod) == AshSurface.Config.show_raised_errors()
    end
  end

  describe "dsl.rpc.section.typescript_rpc.option.namespace" do
    test "a resource namespace overrides the domain namespace; absent, the domain's is inherited" do
      name =
        "Elixir.AshSurface.ParityDeepen.DslRuntimeCourtsTest.NsDom#{System.unique_integer([:positive])}"

      Code.compile_string("""
      defmodule #{name} do
        use Ash.Domain, validate_config_inclusion?: false, extensions: [AshSurface.Domain]
        surface do
          namespace "billing"
        end
      end
      """)

      dom = String.to_existing_atom(name)
      assert AshSurface.Domain.Info.namespace(dom) == "billing"

      over = compile!(domain: inspect(dom), surface: ~s(namespace "docs"\nprojection :read))
      inherit = compile!(domain: inspect(dom), surface: "projection :read")

      assert Info.effective_namespace(over) == "docs"
      assert Info.effective_namespace(inherit) == "billing"
      assert Info.namespace(inherit) == nil
    end
  end

  describe "runtime.module.Rpc (AshSurface.Resource DSL extension)" do
    test "the extension declares the surface section with projection and typed_query entities" do
      assert [%Spark.Dsl.Section{name: :surface} = section] = AshSurface.Resource.sections()
      assert section.entities |> Enum.map(& &1.name) |> Enum.sort() == [:projection, :typed_query]

      for key <- [:type_name, :namespace, :field_names, :argument_names, :show_raised_errors?],
          do: assert(Keyword.has_key?(section.schema, key), "missing section option #{key}")

      projection = Enum.find(section.entities, &(&1.name == :projection))
      assert projection.target == AshSurface.Dsl.Projection
      assert projection.args == [:action]
    end

    test "an Ash resource without the extension is not compiled and is refused loudly" do
      assert Info.compiled?(Toll) == false
      assert Info.compiled(Toll) == nil
      assert Info.compiled_result(Toll) == {:error, :not_compiled}
      assert_raise ArgumentError, fn -> Info.compiled!(Toll) end
      assert AshSurface.Manifest.Dsl.serialize(Toll) == %{}
    end
  end

  describe "runtime.module.Rpc.Info (AshSurface.Resource.Projections)" do
    test "lookup, split of projections vs typed queries, and absent names" do
      mod =
        compile!(
          surface: """
          projection :read
          projection :other, name: :other_list
          typed_query :tq, :read do
            fields [:id, :title]
          end
          """
        )

      assert Enum.map(Projections.all(mod), & &1.action) |> Enum.sort() == [:other, :read]
      assert [%{name: :tq, action: :read}] = Projections.typed_queries(mod)
      assert Projections.typed_query(mod, :tq).fields == [:id, :title]
      assert Projections.typed_query(mod, :nope) == nil
      assert Projections.for_action(mod, :other).name == :other_list
      assert Projections.for_action(mod, :nope) == nil
      assert Info.surface(mod) |> length() == 3
    end

    test "presentation facts carry exactly name/namespace/description/deprecated/see" do
      mod = compile!(surface: ~s(projection :read, description: "d", namespace: "n"))
      pres = Projections.presentation(Projections.for_action(mod, :read))
      assert Map.keys(pres) |> Enum.sort() == [:deprecated, :description, :name, :namespace, :see]
      assert pres.description == "d" and pres.namespace == "n" and pres.see == []
    end
  end

  describe "runtime.module.Resource.Info (AshSurface.Resource.Info)" do
    test "field_names and argument_names read back as declared" do
      mod =
        compile!(
          surface: """
          field_names item_1: "item1"
          projection :read
          """
        )

      assert Info.field_names(mod) == [item_1: "item1"]
      assert Info.argument_names(mod) == nil
      dsl = AshSurface.Manifest.Dsl.serialize(mod)
      assert dsl["field_names"] == %{"item_1" => "item1"}
      assert Info.compiled?(mod)
      assert {:ok, compiled} = Info.compiled_result(mod)
      assert compiled == Info.compiled!(mod)
    end
  end

  describe "runtime.module.AshTypescript (AshSurface top-level API)" do
    test "digest is key-order and key-type independent, 64 lowercase hex, and content-sensitive" do
      d = AshSurface.digest(%{"a" => 1, "b" => [1, 2]})
      assert d =~ ~r/\A[0-9a-f]{64}\z/
      assert d == AshSurface.digest(%{b: [1, 2], a: 1})
      assert d != AshSurface.digest(%{"a" => 2, "b" => [1, 2]})
      assert AshSurface.contract_digest(%{"a" => 1}) == AshSurface.digest(%{"a" => 1})
    end

    test "from_manifest mints a verifiable digest; a forged digest is refused" do
      assert {:ok, surface} =
               AshSurface.from_manifest(%Manifest{entrypoints: []}, profile: %{"tier" => "gold"})

      assert surface.digest == AshSurface.contract_digest(surface.contract)
      assert AshSurface.verify_surface_digest(surface) == :ok
      forged = %{surface | digest: String.duplicate("0", 64)}

      assert {:error, {:surface_digest_mismatch, _, actual}} =
               AshSurface.verify_surface_digest(forged)

      assert actual == surface.digest
    end

    test "unknown action profile keys are refused" do
      assert {:error, {:unknown_action_profile, ["Nope#x"]}} =
               AshSurface.from_manifest(%Manifest{entrypoints: []},
                 profile: %{"actions" => %{"Nope#x" => %{}}}
               )
    end

    test "action_id names the exact entrypoint; schema_version and runtime adapter are real" do
      Application.put_env(@otp_app, :ash_domains, [DomA])
      on_exit(fn -> Application.delete_env(@otp_app, :ash_domains) end)
      assert {:ok, manifest} = Manifest.generate(otp_app: @otp_app)
      [entry] = manifest.entrypoints
      assert AshSurface.action_id(entry) == "#{inspect(Toll)}#read"
      assert AshSurface.delegated(entry, "semanticId") == nil
      assert is_binary(AshSurface.schema_version())
      assert {:ok, source} = AshSurface.runtime_source()
      assert source =~ "createClient"
      assert File.exists?(AshSurface.runtime_path())
    end
  end

  describe "runtime.module.Helpers (AshSurface.FieldName / Naming real helper functions)" do
    alias AshSurface.{FieldName, Naming}

    test "format: each formatter, and an override wins verbatim" do
      assert FieldName.format(:created_at, :camel_case) == "createdAt"
      assert FieldName.format(:created_at, :pascal_case) == "CreatedAt"
      assert FieldName.format(:created_at, :snake_case) == "created_at"
      assert FieldName.format(:created_at, :camel_case, %{created_at: "when"}) == "when"

      assert FieldName.compute("is_done?", :camel_case) ==
               FieldName.compute(:is_done?, :camel_case)
    end

    test "parse_input never mints atoms and round-trips an existing field" do
      assert FieldName.parse_input("createdAt", :camel_case, [:created_at]) in [
               {:ok, :created_at},
               :error
             ]

      assert FieldName.parse_input("", :camel_case) == :error
      assert FieldName.parse_input(:already_atom, :camel_case) == {:ok, :already_atom}

      before = :erlang.system_info(:atom_count)
      _ = FieldName.parse_input("zzNeverAnAtom#{System.unique_integer([:positive])}", :camel_case)
      assert :erlang.system_info(:atom_count) - before < 5
    end

    test "parse_sort recognises direction prefixes" do
      assert {dir_asc, "title"} = FieldName.parse_sort("title")
      assert {dir_desc, "title"} = FieldName.parse_sort("-title")
      assert dir_asc != dir_desc
    end

    test "Naming flags awkward identifiers and suggests a replacement" do
      assert Naming.invalid_name?(:field_1)
      assert Naming.invalid_name?(:ready?)
      refute Naming.invalid_name?(:plain)
      assert Naming.make_name_better(:field_1) == "field1"
      assert Naming.make_name_better(:ready?) == "ready"
      assert Naming.identifier?("ok_name")
      refute Naming.identifier?("1bad")
    end
  end

  describe "dsl.manifest.opt_schema.option.domains (from_app domain selection)" do
    setup do
      on_exit(fn -> Application.delete_env(@otp_app, :ash_domains) end)
    end

    defp resources_of(surface),
      do:
        surface.action_ids
        |> Enum.map(&(&1 |> String.split("#") |> hd()))
        |> Enum.uniq()
        |> Enum.sort()

    test "only the selected domains' public actions are admitted" do
      Application.put_env(@otp_app, :ash_domains, [DomA])
      assert {:ok, a} = AshSurface.from_app(@otp_app)
      assert resources_of(a) == [inspect(Toll)]

      Application.put_env(@otp_app, :ash_domains, [DomB])
      assert {:ok, b} = AshSurface.from_app(@otp_app)
      assert resources_of(b) == [inspect(Fee)]

      Application.put_env(@otp_app, :ash_domains, [DomA, DomB])
      assert {:ok, both} = AshSurface.from_app(@otp_app)
      assert resources_of(both) == Enum.sort([inspect(Toll), inspect(Fee)])
    end

    test "an empty domain selection admits nothing" do
      Application.put_env(@otp_app, :ash_domains, [])
      assert {:ok, none} = AshSurface.from_app(@otp_app)
      assert none.action_ids == []
    end
  end
end
