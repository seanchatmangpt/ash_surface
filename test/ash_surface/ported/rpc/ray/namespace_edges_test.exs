defmodule AshSurface.Ported.Rpc.Ray.NamespaceEdgesTest do
  @moduledoc """
  Lane RAY (RAL gap): empty-string and invalid namespaces at entry, resource and domain level,
  through real compile and `ActionManifest`.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Manifest.ActionManifest
  alias AshSurface.RuntimeParity.Rpc.Pipeline, as: E

  defmodule Plain do
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
      projection :read
    end
  end

  setup_all do
    {:ok, manifest} =
      Ash.Info.Manifest.generate(
        otp_app: :ash_surface,
        action_entrypoints: [{Plain, :read}]
      )

    %{manifest: manifest}
  end

  defp built(m, entries), do: ActionManifest.build(m, entries)

  test "entry-level empty namespace is carried verbatim and listed", %{manifest: m} do
    out = built(m, [E.entry(:ls, Plain, :read, namespace: "")])
    assert [%{"namespace" => ""}] = out["actions"]
    assert out["namespaces"] == [""]
  end

  test "entry-level invalid namespace is not validated by the manifest", %{manifest: m} do
    out = built(m, [E.entry(:ls, Plain, :read, namespace: "a b")])
    assert out["namespaces"] == ["a b"]
  end

  defp refused(namespace_dsl) do
    n = System.unique_integer([:positive])

    ExUnit.CaptureIO.capture_io(:stderr, fn ->
      Code.compile_string("""
      defmodule AshSurface.Ported.Rpc.Ray.Refused#{n} do
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
          #{namespace_dsl}
          projection :read
        end
      end
      """)
    end)
  end

  test "resource-level empty and invalid namespaces are accepted (reference parity)" do
    for ns <- [~s|""|, ~s|"a b"|, ~s|"1x"|] do
      out = refused("namespace #{ns}")
      refute out =~ "invalid_namespace"
      refute out =~ "Spark.Error.DslError"
    end
  end

  test "domain-level empty and invalid namespaces are accepted (reference parity)" do
    for ns <- [~s|""|, ~s|"a b"|] do
      n = System.unique_integer([:positive])

      out =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          Code.compile_string("""
          defmodule AshSurface.Ported.Rpc.Ray.AcceptedDomain#{n} do
            use Ash.Domain, validate_config_inclusion?: false, extensions: [AshSurface.Domain]

            surface do
              namespace #{ns}
            end

            resources do
              allow_unregistered?(true)
            end
          end
          """)
        end)

      refute out =~ "invalid_namespace"
      refute out =~ "Spark.Error.DslError"
    end
  end

  test "a valid resource namespace compiles without refusal" do
    refute refused(~s|namespace "ok_ns"|) =~ "invalid_namespace"
  end
end
