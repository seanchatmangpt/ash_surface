defmodule AshSurface.Ported.Rpc.A.CodegenDeterminismTest do
  @moduledoc """
  Port of ash_typescript `codegen_determinism_test.exs`. The reference hashes ten runs of the
  TypeScript generator. ash_surface generates no `.ts`; the equivalent deterministic artifact
  is the compiled IR (including the emitted Zod schema text), hashed via canonical JSON.
  """
  use ExUnit.Case, async: false

  alias AshSurface.{CanonicalJSON, Compiler}
  alias AshSurface.IR.Codec

  @otp_app :ash_surface_t8_determinism

  setup do
    Application.put_env(@otp_app, :ash_domains, [AshSurface.Ported.Domain])
    on_exit(fn -> Application.delete_env(@otp_app, :ash_domains) end)
    :ok
  end

  describe "codegen determinism" do
    @tag timeout: 240_000
    test "manifest generation + IR compile (Zod schemas included) 3 times, and 2 more compiles of one manifest, are identical" do
      {:ok, shared} = Ash.Info.Manifest.generate(otp_app: @otp_app)

      hashes =
        Enum.map(1..5, fn i ->
          manifest =
            if i <= 3 do
              {:ok, m} = Ash.Info.Manifest.generate(otp_app: @otp_app)
              m
            else
              shared
            end

          {:ok, irs} = Compiler.compile(manifest)
          irs = if is_map(irs), do: Map.values(irs), else: irs

          canonical =
            irs
            |> Enum.map(&CanonicalJSON.encode(Codec.to_map(&1)))
            |> Enum.sort()
            |> Enum.join("\n")

          :crypto.hash(:sha256, canonical) |> Base.encode16()
        end)

      assert length(hashes) == 5
      assert length(Enum.uniq(hashes)) == 1
    end
  end
end
