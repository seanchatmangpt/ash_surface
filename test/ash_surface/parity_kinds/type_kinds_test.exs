defmodule AshSurface.ParityKinds.TypeKindsTest do
  @moduledoc """
  Per-kind courts for the 30 `type.kind.*` parity ids. The expected table is hand-written
  (derived from ~/ash_typescript codegen/zod_schema_generator.ex, divergences noted inline),
  NOT read back from ZodType; accept/reject samples execute under real zod in node.
  """
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.ZodType

  @runner Path.expand("../../ts/kinds_runner.mjs", __DIR__)

  # kind => {expected zod text, accept payloads (JSON), reject payloads (JSON)}
  @expected %{
    "any" => {"z.any()", [~s("a"), ~s(1), ~s(null)], []},
    "atom" => {"z.string()", [~s("ok")], [~s(1)]},
    "binary" => {"z.string()", [~s("ok")], [~s(1)]},
    "boolean" => {"z.boolean()", [~s(true)], [~s("true")]},
    "ci_string" => {"z.string()", [~s("Ok")], [~s(1)]},
    "date" => {"z.iso.date()", [~s("2024-01-02")], [~s("nope")]},
    "datetime" => {"z.iso.datetime()", [~s("2024-01-02T03:04:05Z")], [~s("2024-01-02")]},
    "decimal" => {"z.string()", [~s("1.5")], [~s(1.5)]},
    "duration" => {"z.iso.duration()", [~s("P1D")], [~s("1 day")]},
    "duration_name" => {"z.string()", [~s("day")], [~s(1)]},
    "file" => {"z.any()", [~s({"a":1}), ~s("x")], []},
    "float" => {"z.number()", [~s(1.5)], [~s("1.5")]},
    "function" => {"z.any()", [~s("x"), ~s(1)], []},
    "integer" => {"z.number().int()", [~s(3)], [~s(1.5), ~s("3")]},
    "keyword" => {"z.record(z.string(), z.unknown())", [~s({"a":1})], [~s("x")]},
    "map" => {"z.record(z.string(), z.unknown())", [~s({"a":1})], [~s([1])]},
    "module" => {"z.string()", [~s("Elixir.Foo")], [~s(1)]},
    "naive_datetime" =>
      {"z.iso.datetime({local: true})", [~s("2024-01-02T03:04:05")], [~s("nope")]},
    "string" => {"z.string()", [~s("ok")], [~s(1)]},
    "struct" => {"z.record(z.string(), z.unknown())", [~s({"a":1})], [~s("x")]},
    "term" => {"z.any()", [~s("a"), ~s({"a":1})], []},
    "time" => {"z.iso.time()", [~s("03:04:05")], [~s("nope")]},
    "time_usec" => {"z.iso.time()", [~s("03:04:05.123456")], [~s("nope")]},
    "tuple" => {"z.record(z.string(), z.unknown())", [~s({"0":1})], [~s("x")]},
    "url_encoded_binary" => {"z.string()", [~s("a%20b")], [~s(1)]},
    "utc_datetime" => {"z.iso.datetime()", [~s("2024-01-02T03:04:05Z")], [~s("2024-01-02")]},
    "utc_datetime_usec" =>
      {"z.iso.datetime()", [~s("2024-01-02T03:04:05.123456Z")], [~s("2024-01-02")]},
    "uuid" => {"z.guid()", [~s("123e4567-e89b-12d3-a456-426614174000")], [~s("nope")]},
    "uuid_v7" => {"z.uuid()", [~s("01890a5d-ac96-774b-bcce-b302099a8057")], [~s("nope")]},
    "vector" => {"z.array(z.number())", [~s([1,2])], [~s(["a"])]}
  }

  setup_all do
    specs =
      for {kind, {expr, acc, rej}} <- @expected do
        cases =
          Enum.map(acc, &%{label: "accept " <> &1, expect: true, payload: Jason.decode!(&1)}) ++
            Enum.map(rej, &%{label: "reject " <> &1, expect: false, payload: Jason.decode!(&1)})

        %{kind: kind, expression: expr, cases: cases}
      end

    path = Path.join(System.tmp_dir!(), "kinds_#{AshSurface.TestTmp.suffix()}.json")
    File.write!(path, Jason.encode!(%{specs: specs}))
    on_exit(fn -> File.rm(path) end)
    {out, 0} = System.cmd("node", [@runner, path], cd: Path.expand("../../..", __DIR__))
    {:ok, zod: Jason.decode!(out)}
  end

  defp court(kind, zod) do
    {expr, _acc, _rej} = Map.fetch!(@expected, kind)
    assert ZodType.fragment(%{"type" => %{"kind" => kind}}) == expr
    results = Map.fetch!(zod, kind)
    assert results != []
    for r <- results, do: assert(r["success"] == r["expect"], "#{kind}: #{r["label"]}")
    :ok
  end

  test "type.kind.any renders", %{zod: zod} do
    assert court("any", zod) == :ok
  end

  test "type.kind.atom renders", %{zod: zod} do
    assert court("atom", zod) == :ok
  end

  test "type.kind.binary renders", %{zod: zod} do
    assert court("binary", zod) == :ok
  end

  test "type.kind.boolean renders", %{zod: zod} do
    assert court("boolean", zod) == :ok
  end

  test "type.kind.ci_string renders", %{zod: zod} do
    assert court("ci_string", zod) == :ok
  end

  test "type.kind.date renders", %{zod: zod} do
    assert court("date", zod) == :ok
  end

  test "type.kind.datetime renders", %{zod: zod} do
    assert court("datetime", zod) == :ok
  end

  test "type.kind.decimal renders", %{zod: zod} do
    assert court("decimal", zod) == :ok
  end

  test "type.kind.duration renders", %{zod: zod} do
    assert court("duration", zod) == :ok
  end

  test "type.kind.duration_name renders", %{zod: zod} do
    assert court("duration_name", zod) == :ok
  end

  test "type.kind.file renders", %{zod: zod} do
    assert court("file", zod) == :ok
  end

  test "type.kind.float renders", %{zod: zod} do
    assert court("float", zod) == :ok
  end

  test "type.kind.function renders", %{zod: zod} do
    assert court("function", zod) == :ok
  end

  test "type.kind.integer renders", %{zod: zod} do
    assert court("integer", zod) == :ok
  end

  test "type.kind.keyword renders", %{zod: zod} do
    assert court("keyword", zod) == :ok
  end

  test "type.kind.map renders", %{zod: zod} do
    assert court("map", zod) == :ok
  end

  test "type.kind.module renders", %{zod: zod} do
    assert court("module", zod) == :ok
  end

  test "type.kind.naive_datetime renders", %{zod: zod} do
    assert court("naive_datetime", zod) == :ok
  end

  test "type.kind.string renders", %{zod: zod} do
    assert court("string", zod) == :ok
  end

  test "type.kind.struct renders", %{zod: zod} do
    assert court("struct", zod) == :ok
  end

  test "type.kind.term renders", %{zod: zod} do
    assert court("term", zod) == :ok
  end

  test "type.kind.time renders", %{zod: zod} do
    assert court("time", zod) == :ok
  end

  test "type.kind.time_usec renders", %{zod: zod} do
    assert court("time_usec", zod) == :ok
  end

  test "type.kind.tuple renders", %{zod: zod} do
    assert court("tuple", zod) == :ok
  end

  test "type.kind.url_encoded_binary renders", %{zod: zod} do
    assert court("url_encoded_binary", zod) == :ok
  end

  test "type.kind.utc_datetime renders", %{zod: zod} do
    assert court("utc_datetime", zod) == :ok
  end

  test "type.kind.utc_datetime_usec renders", %{zod: zod} do
    assert court("utc_datetime_usec", zod) == :ok
  end

  test "type.kind.uuid renders", %{zod: zod} do
    assert court("uuid", zod) == :ok
  end

  test "type.kind.uuid_v7 renders", %{zod: zod} do
    assert court("uuid_v7", zod) == :ok
  end

  test "type.kind.vector renders", %{zod: zod} do
    assert court("vector", zod) == :ok
  end
end
