defmodule AshSurface.Ported.Rpc.Raz.EntryNamespaceParityTest do
  @moduledoc """
  Lane RAZ: entry-level namespace is pass-through (parity, no KD).

  Reference ash_typescript@5d6e80ae `lib/ash_typescript/rpc.ex:128-133` declares the
  rpc_action entry `namespace` as `type: :string` only; no verifier or manifest generator
  validates or normalizes it (git grep of lib/ for invalid/regex namespace checks: none).
  Entry namespaces are therefore carried verbatim. Resource/domain-level invalid_namespace refusal was removed
  (wave3-rbd): no downstream harm witnessed, so all levels are lenient like the reference.
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
    {:ok, m} =
      Ash.Info.Manifest.generate(otp_app: :ash_surface, action_entrypoints: [{Plain, :read}])

    %{m: m}
  end

  for ns <- ["", "a b", "1x", " pad ", "Mixed-Case.x"] do
    test "entry namespace #{inspect(ns)} is carried verbatim", %{m: m} do
      ns = unquote(ns)
      out = ActionManifest.build(m, [E.entry(:ls, Plain, :read, namespace: ns)])
      assert [%{"namespace" => ^ns}] = out["actions"]
      assert out["namespaces"] == [ns]
    end
  end
end
