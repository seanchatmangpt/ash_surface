defmodule AshSurface.TS.InferenceFixture do
  @moduledoc "Resource meta fixtures fed to the real `Inference.emit/1` (no doubles)."
  alias AshSurface.Projectors.JS.Inference

  defp f(name, ts, prim?), do: %{name: name, ts: ts, primitive?: prim?}

  def resources do
    [
      {"Todo",
       [
         f("id", "string", true),
         f("title", "string", true),
         f("done", "boolean", true),
         f("points", "number | null", true),
         f("user", ~S[{ __type: "Relationship"; __resource: UserSchema | null }], false),
         f(
           "comments",
           ~S[{ __type: "Relationship"; __resource: CommentSchema; __array: true; __pagination: "mixed"; __filterInput: { body?: string }; __sortField: "body" | "id" }],
           false
         ),
         f("tags", ~S[{ __type: "Relationship"; __resource: TagSchema; __array: true }], false),
         f("address", ~S[{ __type: "Relationship"; __resource: AddressSchema | null }], false),
         f("meta", "MetaSchema", false),
         f("content", "ContentSchema", false),
         f(
           "fullTitle",
           ~S[{ __type: "ComplexCalculation"; __returnType: UserSchema; __args: { sep: string } }],
           false
         )
       ]},
      {"User",
       [f("id", "string", true), f("email", "string", true), f("name", "string | null", true)]},
      {"Comment", [f("id", "string", true), f("body", "string", true)]},
      {"Tag", [f("id", "string", true), f("label", "string", true)]},
      {"Address", [f("street", "string", true), f("zip", "string | null", true)]},
      {"NoFields", []}
    ]
    |> then(fn rs ->
      # TypedMap / Union meta types need their own __type; resource_meta fixes
      # "Resource", so those two are appended as raw declarations below.
      rs
    end)
  end

  @extra ~S"""

  export type MetaSchema = { __type: "TypedMap"; __primitiveFields: "k" | "n"; k: string; n: number };
  export type ContentSchema = {
    __type: "Union";
    __primitiveFields: "text";
    text: string;
    note: NoteSchema;
  };
  export type NoteSchema = { __type: "TypedMap"; __primitiveFields: "body"; body: string };
  """

  def source, do: Inference.emit(resources()) <> @extra
end

defmodule AshSurface.TS.InferenceTscTest do
  @moduledoc """
  Real `tsc --strict` over cases importing the types `Inference.emit/1` really
  provides (README stance: tsc is a test tool only; inference.d.ts is not wired into js.ex).
  """
  use ExUnit.Case, async: false

  alias AshSurface.TS.InferenceFixture
  alias AshSurface.ZodFixtures.Harness

  @flags ~w(--strict --noEmit --skipLibCheck --module esnext --moduleResolution bundler --target es2022)

  setup_all do
    tsc = Harness.tool!("tsc")
    dir = Path.join(System.tmp_dir!(), "ash_surface_inf_#{AshSurface.TestTmp.suffix()}")
    File.mkdir_p!(dir)
    File.cp_r!(Path.join(Harness.repo_root(), "test/ts/inference"), Path.join(dir, "inference"))
    File.write!(Path.join(dir, "inference/schemas.ts"), InferenceFixture.source())
    on_exit(fn -> File.rm_rf!(dir) end)
    %{tsc: tsc, dir: Path.join(dir, "inference")}
  end

  test "emitted source alone compiles", %{tsc: tsc, dir: dir} do
    {out, status} = Harness.run(tsc, @flags ++ ["schemas.ts"], dir)
    assert status == 0, out
  end

  test "every shouldPass case compiles clean", %{tsc: tsc, dir: dir} do
    files =
      Path.wildcard(Path.join(dir, "shouldPass/*.ts")) |> Enum.map(&Path.relative_to(&1, dir))

    assert length(files) >= 10

    for file <- files do
      {out, status} = Harness.run(tsc, @flags ++ [file], dir)
      assert status == 0, "#{file}:\n" <> out
    end
  end

  test "every shouldFail case is rejected by tsc", %{tsc: tsc, dir: dir} do
    files =
      Path.wildcard(Path.join(dir, "shouldFail/*.ts")) |> Enum.map(&Path.relative_to(&1, dir))

    assert length(files) >= 6

    for file <- files do
      {out, status} = Harness.run(tsc, @flags ++ [file], dir)
      assert status != 0, "#{file} unexpectedly compiled"
      # Each case marks the lines that must error with `// @error` (optionally `// @error TS2322`
      # to pin the diagnostic code). The set of lines tsc reports must EQUAL the marker lines:
      # an unrelated error elsewhere cannot stand in for a marked line, and a marked line that
      # compiles cleanly is a vacuous negative.
      marked =
        File.read!(Path.join(dir, file))
        |> String.split("\n")
        |> Enum.with_index(1)
        |> Enum.flat_map(fn {line, n} ->
          case Regex.run(~r{// @error(?: (TS\d+))?\s*$}, line) do
            nil -> []
            [_] -> [{n, nil}]
            [_, code] -> [{n, code}]
          end
        end)

      assert marked != [], "#{file} has no @error marker"

      reported =
        Regex.scan(~r/^#{Regex.escape(file)}\((\d+),\d+\): error (TS\d+):/m, out)
        |> Enum.map(fn [_, n, code] -> {String.to_integer(n), code} end)

      reported_lines = reported |> Enum.map(&elem(&1, 0)) |> Enum.uniq() |> Enum.sort()
      marked_lines = marked |> Enum.map(&elem(&1, 0)) |> Enum.sort()

      assert reported_lines == marked_lines,
             "#{file}: tsc error lines #{inspect(reported_lines, charlists: :as_lists)} != @error marker lines " <>
               "#{inspect(marked_lines, charlists: :as_lists)}:\n" <> out

      for {n, code} <- marked, code != nil do
        assert {n, code} in reported,
               "#{file}:#{n}: expected #{code}, tsc reported #{inspect(Enum.filter(reported, &(elem(&1, 0) == n)))}"
      end
    end
  end
end
