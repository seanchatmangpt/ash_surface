defmodule AshSurface.FormatterExportTest do
  use ExUnit.Case, async: true

  @root Path.expand("../..", __DIR__)

  defp config do
    {conf, _} = Code.eval_file(Path.join(@root, ".formatter.exs"))
    conf
  end

  test "export mirrors locals_without_parens and names only real DSL entities" do
    conf = config()
    locals = Keyword.fetch!(conf, :locals_without_parens)
    assert Keyword.fetch!(conf, :export) == [locals_without_parens: locals]
    assert {:projection, 1} in locals

    entity_names =
      AshSurface.Resource.sections()
      |> Enum.flat_map(& &1.entities)
      |> Enum.map(& &1.name)

    for {name, _arity} <- locals, do: assert(name in entity_names)
  end

  test "exported locals format a real surface block without parens" do
    dir = Path.join(System.tmp_dir!(), "ash_surface_fmt_#{AshSurface.TestTmp.suffix()}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)

    locals = Keyword.fetch!(config(), :locals_without_parens)
    input = "surface do\n  projection :read\nend\n"

    assert Code.format_string!(input) |> IO.iodata_to_binary() ==
             "surface do\n  projection(:read)\nend"

    assert Code.format_string!(input, locals_without_parens: locals) |> IO.iodata_to_binary() ==
             "surface do\n  projection :read\nend"
  end
end
