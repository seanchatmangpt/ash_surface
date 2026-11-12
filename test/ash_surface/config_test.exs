defmodule AshSurface.ConfigTest do
  use ExUnit.Case, async: false

  alias AshSurface.Config
  alias AshSurface.Config.Verifier

  @keys [:zod_object_mode, :zod_mapping_overrides, :zod_schema_suffix]

  setup do
    saved = for k <- @keys, do: {k, Application.fetch_env(:ash_surface, k)}

    on_exit(fn ->
      for {k, r} <- saved do
        case r do
          {:ok, v} -> Application.put_env(:ash_surface, k, v)
          :error -> Application.delete_env(:ash_surface, k)
        end
      end
    end)

    for k <- @keys, do: Application.delete_env(:ash_surface, k)
    :ok
  end

  test "defaults" do
    assert Config.zod_object_mode() == :strip
    assert Config.zod_import_path() == "zod"
    assert Verifier.verify() == :ok
  end

  test "rejects unknown object mode" do
    Application.put_env(:ash_surface, :zod_object_mode, :loose)
    assert {:error, [msg]} = Verifier.verify()
    assert msg =~ "zod_object_mode"
  end

  test "rejects override without import and non-identifier names" do
    Application.put_env(:ash_surface, :zod_mapping_overrides, [{MyT, %{name: "x"}}])
    assert {:error, _} = Verifier.verify()
    Application.put_env(:ash_surface, :zod_mapping_overrides, [{MyT, {"./m", "not ok"}}])
    assert {:error, [msg]} = Verifier.verify()
    assert msg =~ "identifier"
  end
end
