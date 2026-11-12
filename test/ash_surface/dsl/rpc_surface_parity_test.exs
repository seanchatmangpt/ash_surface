defmodule AshSurface.Dsl.RpcSurfaceParityTest do
  @moduledoc """
  Parity courts for ash_typescript's `typescript_rpc` DSL (rpc_action / typed_query /
  section options). Counterpart: the `surface` section and its `projection` /
  `typed_query` entities. Real compiled resources through the real Spark verifier.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Resource.{Info, Projections}

  defp compile!(surface_body) do
    name = "Elixir.AshSurface.Dsl.RpcSurfaceParityTest.R#{System.unique_integer([:positive])}"

    Code.compile_string("""
    defmodule #{name} do
      use Ash.Resource, domain: nil, data_layer: Ash.DataLayer.Simple,
        extensions: [AshSurface.Resource]
      attributes do
        uuid_primary_key :id, public?: true
        attribute :title, :string, public?: true
      end
      actions do
        defaults [:read]
        read :other
      end
      surface do
        #{surface_body}
      end
    end
    """)

    String.to_existing_atom(name)
  end

  defp stderr_of(body), do: ExUnit.CaptureIO.capture_io(:stderr, fn -> compile!(body) end)

  defp rejects_type(body) do
    out =
      try do
        stderr_of(body)
      rescue
        e -> Exception.message(e)
      end

    assert out =~ "expected" or out =~ "invalid" or out =~ "Spark.Error.DslError"
  end

  test "rpc entity resource option resource: the surface section lives on the resource itself" do
    mod = compile!("projection :read")
    assert Info.compiled?(mod)
    assert [%AshSurface.Dsl.Projection{action: :read}] = Info.surface(mod)
  end

  test "rpc_action option action: unknown action refused, public action admitted" do
    refute stderr_of("projection :read") =~ "unknown_action_projection"
    out = stderr_of("projection :ghost")
    assert out =~ "unknown_action_projection"
    assert out =~ "ghost"
  end

  test "rpc_action option name: wire name is introspectable, duplicates refused, type enforced" do
    mod = compile!("projection :read, name: :list_docs")
    assert Projections.for_action(mod, :read).name == :list_docs
    assert Projections.presentation(Projections.for_action(mod, :read)).name == :list_docs

    out = stderr_of("projection :read, name: :same\nprojection :other, name: :same")
    assert out =~ "duplicate_projection_name"

    rejects_type(~s|projection :read, name: "not an atom"|)
  end

  test "rpc_action option namespace: presentation fact, string type enforced" do
    mod = compile!(~s|projection :read, namespace: "docs"|)
    assert Projections.presentation(Projections.for_action(mod, :read)).namespace == "docs"
    rejects_type("projection :read, namespace: 5")
  end

  test "rpc_action option description: presentation fact, string type enforced" do
    mod = compile!(~s|projection :read, description: "List docs"|)
    assert Projections.presentation(Projections.for_action(mod, :read)).description == "List docs"
    rejects_type("projection :read, description: 5")
  end

  test "rpc_action option see: list of related projection names, defaults to empty" do
    mod = compile!("projection :read, see: [:other]\nprojection :other")
    assert Projections.presentation(Projections.for_action(mod, :read)).see == [:other]
    assert Projections.presentation(Projections.for_action(mod, :other)).see == []
    rejects_type(~s|projection :read, see: "nope"|)
  end

  test "typed_query option description: introspectable string, type enforced" do
    mod = compile!(~s|typed_query :q, :read do\n description "All docs"\n fields [:id]\n end|)
    assert Projections.typed_query(mod, :q).description == "All docs"

    rejects_type("typed_query :q, :read do\n description 5\n fields [:id]\n end")
  end

  test "typed_query option ts_fields_const_name (fields_const_name): introspectable, type enforced" do
    mod =
      compile!(~s|typed_query :q, :read do\n fields_const_name "docFields"\n fields [:id]\n end|)

    assert Projections.typed_query(mod, :q).fields_const_name == "docFields"
    rejects_type("typed_query :q, :read do\n fields_const_name 5\n fields [:id]\n end")
  end

  test "typed_query option ts_result_type_name (result_type_name): introspectable, type enforced" do
    mod =
      compile!(~s|typed_query :q, :read do\n result_type_name "DocResult"\n fields [:id]\n end|)

    assert Projections.typed_query(mod, :q).result_type_name == "DocResult"
    rejects_type("typed_query :q, :read do\n result_type_name 5\n fields [:id]\n end")
  end

  test "typescript_rpc section: the surface section is generated with its options" do
    section = Enum.find(AshSurface.Resource.sections(), &(&1.name == :surface))
    assert section
    keys = Keyword.keys(section.schema)

    for k <- [:type_name, :namespace, :field_names, :argument_names, :show_raised_errors?],
        do: assert(k in keys)

    assert Enum.sort(Enum.map(section.entities, & &1.name)) == [:projection, :typed_query]
  end

  describe "typescript_rpc option show_raised_errors?" do
    setup do
      previous = Application.fetch_env(:ash_surface, :show_raised_errors)
      Application.put_env(:ash_surface, :show_raised_errors, false)

      on_exit(fn ->
        case previous do
          {:ok, v} -> Application.put_env(:ash_surface, :show_raised_errors, v)
          :error -> Application.delete_env(:ash_surface, :show_raised_errors)
        end
      end)
    end

    test "resource option overrides config and drives the projected error message" do
      shown = compile!("show_raised_errors? true\nprojection :read")
      hidden = compile!("show_raised_errors? false\nprojection :read")
      unset = compile!("projection :read")

      assert Info.show_raised_errors?(shown) == true
      assert Info.show_raised_errors?(hidden) == false
      assert Info.show_raised_errors?(unset) == false

      Application.put_env(:ash_surface, :show_raised_errors, true)
      assert Info.show_raised_errors?(unset) == true
      assert Info.show_raised_errors?(hidden) == false
      Application.put_env(:ash_surface, :show_raised_errors, false)

      err = RuntimeError.exception("secret-boom")

      [s] = AshSurface.Errors.to_errors(err, show_raised_errors: Info.show_raised_errors?(shown))
      assert s["message"] =~ "secret-boom"

      [h] = AshSurface.Errors.to_errors(err, show_raised_errors: Info.show_raised_errors?(hidden))
      refute h["message"] =~ "secret-boom"
    end

    test "non-boolean value is refused" do
      rejects_type(~s|show_raised_errors? "yes"|)
    end
  end
end
