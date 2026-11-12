Code.require_file("support/t1.exs", __DIR__)

defmodule AshSurface.Ported.Top.EmbeddedGenericActionReturnTest do
  @moduledoc """
  Adaptation of ash_typescript `embedded_generic_action_return_test.exs`. The domain, resources and
  the compile are declared inline (the shared fixture set is untouched), including the shape that
  regressed in the reference: two resources where the earlier one relates to the later one
  (`Related` -> `Holder`), so `Holder` is visited as a relationship destination before its own root.

  ash_surface adaptation: the "types file" / "RPC file" pair becomes the single generated JS
  artifact. The argument-side and self-consistency tests port; the return-type tests (embedded
  resource named as a generic action's return type / `:struct` + `instance_of` / array return /
  nested-in-return) assert a *response schema* for generic action returns, which ash_surface does
  not emit: now emitted (IR `response_zod` from the action's declared `returns`) and asserted below.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.T1

  defmodule NestedEmbedded do
    use Ash.Resource, data_layer: :embedded, domain: nil, extensions: [AshSurface.Resource]

    surface do
      type_name("NestedEmbedded")
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:label, :string, public?: true, allow_nil?: false)
    end
  end

  defmodule StructReturnEmbedded do
    use Ash.Resource, data_layer: :embedded, domain: nil, extensions: [AshSurface.Resource]

    surface do
      type_name("StructReturnEmbedded")
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:label, :string, public?: true, allow_nil?: false)

      attribute(:nested, AshSurface.Ported.Top.EmbeddedGenericActionReturnTest.NestedEmbedded,
        public?: true
      )
    end
  end

  defmodule ArrayReturnEmbedded do
    use Ash.Resource, data_layer: :embedded, domain: nil, extensions: [AshSurface.Resource]

    surface do
      type_name("ArrayReturnEmbedded")
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:label, :string, public?: true, allow_nil?: false)
    end
  end

  defmodule ArgumentEmbedded do
    use Ash.Resource, data_layer: :embedded, domain: nil, extensions: [AshSurface.Resource]

    surface do
      type_name("ArgumentEmbedded")
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:label, :string, public?: true, allow_nil?: false)
    end
  end

  defmodule Holder do
    use Ash.Resource,
      domain: AshSurface.Ported.Top.EmbeddedGenericActionReturnTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshSurface.Resource]

    surface do
      type_name("Holder")
    end

    ets do
      private?(true)
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, public?: true)
    end

    actions do
      defaults([:read])

      action :build_embedded,
             AshSurface.Ported.Top.EmbeddedGenericActionReturnTest.StructReturnEmbedded do
        run(fn _input, _ctx ->
          {:ok, %AshSurface.Ported.Top.EmbeddedGenericActionReturnTest.StructReturnEmbedded{}}
        end)
      end

      action :build_struct, :struct do
        constraints(
          instance_of: AshSurface.Ported.Top.EmbeddedGenericActionReturnTest.StructReturnEmbedded
        )

        run(fn _input, _ctx ->
          {:ok, %AshSurface.Ported.Top.EmbeddedGenericActionReturnTest.StructReturnEmbedded{}}
        end)
      end

      action :build_struct_list, {:array, :struct} do
        constraints(
          items: [
            instance_of: AshSurface.Ported.Top.EmbeddedGenericActionReturnTest.ArrayReturnEmbedded
          ]
        )

        run(fn _input, _ctx -> {:ok, []} end)
      end

      action :accept_struct, :string do
        argument(:payload, :struct,
          allow_nil?: false,
          constraints: [
            instance_of: AshSurface.Ported.Top.EmbeddedGenericActionReturnTest.ArgumentEmbedded
          ]
        )

        run(fn _input, _ctx -> {:ok, "ok"} end)
      end
    end
  end

  defmodule Related do
    @moduledoc "Declared before `Holder` in the domain: `Holder` is reached as a relationship destination first."
    use Ash.Resource,
      domain: AshSurface.Ported.Top.EmbeddedGenericActionReturnTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshSurface.Resource]

    surface do
      type_name("Related")
    end

    ets do
      private?(true)
    end

    attributes do
      uuid_primary_key(:id)
    end

    relationships do
      belongs_to :holder, AshSurface.Ported.Top.EmbeddedGenericActionReturnTest.Holder do
        public?(true)
        attribute_writable?(true)
      end
    end

    actions do
      defaults([:read])
    end
  end

  defmodule Domain do
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource(AshSurface.Ported.Top.EmbeddedGenericActionReturnTest.Related)
      resource(AshSurface.Ported.Top.EmbeddedGenericActionReturnTest.Holder)
    end
  end

  @otp_app :ash_surface_t1_embedded_generic_return

  setup_all do
    Application.put_env(@otp_app, :ash_domains, [Domain])
    {:ok, manifest} = Ash.Info.Manifest.generate(otp_app: @otp_app)
    {:ok, irs} = AshSurface.Compiler.compile(manifest)
    irs = if is_map(irs), do: Map.values(irs), else: irs
    {:ok, artifacts, _meta} = AshSurface.Projectors.JS.project_ir(irs)
    art = Map.fetch!(artifacts, "ash_surface_client.mjs")
    refute art == "", "no artifact was generated"
    %{art: art, irs: irs}
  end

  defp response_const(art, id) do
    [_, expr] = Regex.run(~r/export const #{id}_response_schema = (.*);\n/, art)
    expr
  end

  test "embedded resource named as a generic action's return type is defined, not just referenced",
       %{art: art, irs: irs} do
    ir = Enum.find(irs, &(&1.ash.resource == Holder and &1.ash.action == :build_embedded))
    assert is_binary(ir.schema.response_zod)
    refute Map.has_key?(ir.schema.nil_reasons || %{}, "response_zod")
    assert response_const(art, "Holder_build_embedded") =~ "label: z.string().min(1)"

    assert [true, false] ==
             T1.node_accepts(
               [
                 {"Holder_build_embedded_response_schema", %{label: "x"}},
                 {"Holder_build_embedded_response_schema", %{}}
               ],
               art
             )
  end

  test "embedded resource returned via :struct + instance_of is defined", %{art: art} do
    assert response_const(art, "Holder_build_struct") =~ "label: z.string().min(1)"

    assert [true, false] ==
             T1.node_accepts(
               [
                 {"Holder_build_struct_response_schema", %{label: "x"}},
                 {"Holder_build_struct_response_schema", %{label: "x", extra: 1}}
               ],
               art
             )
  end

  test "embedded resource in a generic action's array return type is defined", %{art: art} do
    assert response_const(art, "Holder_build_struct_list") =~ "z.array(z.object({ label:"

    assert [true, true, false] ==
             T1.node_accepts(
               [
                 {"Holder_build_struct_list_response_schema", []},
                 {"Holder_build_struct_list_response_schema", [%{label: "x"}]},
                 {"Holder_build_struct_list_response_schema", [%{}]}
               ],
               art
             )
  end

  test "embedded resource nested inside a returned embedded resource is defined", %{art: art} do
    assert response_const(art, "Holder_build_embedded") =~ "nested: z.object({ label:"

    assert [true, false] ==
             T1.node_accepts(
               [
                 {"Holder_build_embedded_response_schema",
                  %{label: "x", nested: %{label: "inner"}}},
                 {"Holder_build_embedded_response_schema", %{label: "x", nested: %{}}}
               ],
               art
             )
  end

  test "the domain really does reach the generic action's resource by relationship first" do
    assert Ash.Domain.Info.resources(Domain) == [Related, Holder]

    assert Enum.any?(
             Ash.Resource.Info.public_relationships(Related),
             &(&1.destination == Holder)
           ),
           "expected Related to reach Holder through a public relationship"
  end

  test "every generic action of the later resource is compiled (visited-set regression shape)", %{
    irs: irs
  } do
    holder_actions =
      for ir <- irs, ir.ash.resource == Holder, do: ir.ash.action

    assert Enum.sort(holder_actions) ==
             [:accept_struct, :build_embedded, :build_struct, :build_struct_list, :read]
  end

  test "embedded resource used as a generic action argument is defined in the artifact", %{
    art: art
  } do
    [schema] =
      Regex.run(~r/export const Holder_accept_struct_schema = z\.object\(\{.*?\n\}\)/s, art)

    assert schema =~ "payload: z.object({ label: z.string().min(1) }).strict()"

    assert [true, false, false] ==
             T1.node_accepts(
               [
                 {"Holder_accept_struct_schema", %{payload: %{label: "x"}}},
                 {"Holder_accept_struct_schema", %{payload: %{}}},
                 {"Holder_accept_struct_schema", %{payload: %{label: "x", extra: 1}}}
               ],
               art
             )
  end

  test "every schema identifier the artifact references is defined in the artifact", %{art: art} do
    referenced =
      Regex.scan(~r/\b([A-Za-z][A-Za-z0-9]*_[a-z0-9_]*_schema)\b/, art)
      |> Enum.map(fn [_, name] -> name end)
      |> Enum.uniq()

    refute referenced == [], "expected the artifact to reference schemas"

    missing =
      Enum.reject(referenced, fn name ->
        String.contains?(art, "export const #{name} =")
      end)

    assert missing == [], "artifact references undefined schemas: #{inspect(missing)}"
  end

  test "every export the descriptors point at resolves under real node (module loads)", %{
    art: art
  } do
    assert [true] ==
             T1.node_accepts([{"Holder_accept_struct_schema", %{payload: %{label: "ok"}}}], art)
  end
end
