defmodule AshSurface.ConfigDeepTest do
  use ExUnit.Case, async: false

  alias AshSurface.Config
  alias AshSurface.Config.Verifier

  @keys [
    :output_file,
    :output_dir,
    :zod_output_file,
    :zod_mapping_overrides,
    :show_raised_errors,
    :error_handler,
    :error_output_formatter,
    :zod_import_into_generated
  ]

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

  defp put(k, v), do: Application.put_env(:ash_surface, k, v)

  test "default artifact paths are .mjs siblings" do
    assert Path.extname(Config.output_file()) == ".mjs"
    assert Path.extname(Config.zod_output_file()) == ".mjs"
    assert Path.dirname(Config.zod_output_file()) == Path.dirname(Config.output_file())
  end

  test "zod_output_file derives from a configured output_file" do
    put(:output_file, "web/gen/client.mjs")
    assert Config.zod_output_file() == "web/gen/ash_surface_zod.mjs"
    put(:zod_output_file, "elsewhere/z.mjs")
    assert Config.zod_output_file() == "elsewhere/z.mjs"
  end

  test "output_dir alias feeds output_file; explicit output_file wins; nothing is lost" do
    put(:output_dir, "legacy/js")
    assert Config.output_file() == "legacy/js/ash_surface_client.mjs"
    assert Config.output_dir() == "legacy/js"
    assert Config.zod_output_file() == "legacy/js/ash_surface_zod.mjs"

    put(:output_file, "new/client.mjs")
    assert Config.output_file() == "new/client.mjs"
    assert Config.output_dir() == "legacy/js"
  end

  test "new key defaults" do
    assert Config.show_raised_errors() == false
    assert Config.error_handler() == nil
    assert Config.error_output_formatter() == nil
    assert Config.zod_import_into_generated() == false
    assert Verifier.verify() == :ok
  end

  test "error handler shapes: module and {m,f,a} pass, others fail" do
    put(:error_handler, MyApp.Handler)
    put(:error_output_formatter, {MyApp.Fmt, :format, [:extra]})
    assert Verifier.verify() == :ok

    put(:error_handler, "MyApp.Handler")
    assert {:error, [msg]} = Verifier.verify()
    assert msg =~ "error_handler"

    put(:error_handler, nil)
    put(:error_output_formatter, {MyApp.Fmt, :format})
    assert {:error, [msg]} = Verifier.verify()
    assert msg =~ "error_output_formatter"
  end

  test "booleans: show_raised_errors and zod_import_into_generated" do
    put(:show_raised_errors, :yes)
    put(:zod_import_into_generated, 1)
    assert {:error, errs} = Verifier.verify()
    assert Enum.any?(errs, &(&1 =~ "show_raised_errors"))
    assert Enum.any?(errs, &(&1 =~ "zod_import_into_generated"))
  end

  test "zod override shapes match ZodType.overrides: module pairs and kind maps" do
    put(:zod_mapping_overrides, [{MyApp.Money, "z.string()"}])
    assert Verifier.verify() == :ok
    put(:zod_mapping_overrides, %{"decimal" => "z.string()"})
    assert Verifier.verify() == :ok
    put(:zod_mapping_overrides, %{"decimal" => ""})
    assert {:error, [msg]} = Verifier.verify()
    assert msg =~ "z.expr"
    put(:zod_mapping_overrides, [:not_a_pair])
    assert {:error, [msg]} = Verifier.verify()
    assert msg =~ "pairs or a map"
  end

  test "override accepted by the verifier is applied by ZodType" do
    put(:zod_mapping_overrides, %{"decimal" => "z.string()"})
    assert AshSurface.Compiler.ZodType.base("decimal") == "z.string()"
    put(:zod_mapping_overrides, [{MyApp.Money, "z.number()"}])
    assert AshSurface.Compiler.ZodType.base("MyApp.Money") == "z.number()"
  end

  test "verify! raises ArgumentError naming the key" do
    put(:output_file, "")
    assert_raise ArgumentError, ~r/output_file/, fn -> Verifier.verify!() end
  end
end
