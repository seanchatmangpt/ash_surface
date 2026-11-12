defmodule AshSurface.Compiler.QuerySchemaWave2Test do
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.QuerySchema, as: Q
  alias AshSurface.Projectors.JS.ZodGuard

  defp admitted!(zod), do: assert({:ok, :expression, ^zod} = ZodGuard.admit(zod))

  defp node_parse(zod, value) do
    root = File.cwd!()
    # Embed-site conversion (documented in QuerySchema moduledoc): zod 4
    # .regex() needs a RegExp, the guard-admitted spelling is a JSON string.
    zod = Regex.replace(~r/\.regex\(("(?:[^"\\]|\\.)*")\)/, zod, ".regex(new RegExp(\\1))")

    js =
      "import {z} from 'zod'; const s = #{zod}; " <>
        "const r = s.safeParse(JSON.parse(process.argv[1])); process.stdout.write(String(r.success));"

    {out, 0} =
      System.cmd("node", ["--input-type=module", "-e", js, Jason.encode!(value)],
        cd: root,
        stderr_to_stdout: true
      )

    out == "true"
  end

  test "sort prefixes ++ -- + - executed under real zod" do
    {:ok, z} = Q.render_sort_schema(["a", "b", "c", "d", "e"])
    admitted!(z)
    assert node_parse(z, "++a,--b,-c,+d,e")
    refute node_parse(z, "+++a")
    refute node_parse(z, "x")
    refute node_parse(z, "a,")
  end

  test "sort array option accepts string and string[]" do
    {:ok, z} = Q.render_sort_schema(["a", "b"], array?: true)
    admitted!(z)
    assert node_parse(z, "-a")
    assert node_parse(z, ["-a", "++b"])
    refute node_parse(z, ["zz"])
    {:ok, plain} = Q.render_sort_schema(["a", "b"])
    refute node_parse(plain, ["a"])
  end

  test "pagination default_limit and max_limit" do
    {:ok, z} =
      Q.render_pagination_schema(%{
        offset?: true,
        required?: true,
        default_limit?: true,
        max_limit: 50
      })

    admitted!(z)
    assert z =~ "max(50).optional()"
    assert node_parse(z, %{})
    refute node_parse(z, %{limit: 51})
    {:ok, z2} = Q.render_pagination_schema(%{offset?: true, required?: true})
    refute node_parse(z2, %{})
    assert node_parse(z2, %{limit: 500})
    refute node_parse(z2, %{limit: 501})

    assert Q.render_pagination_schema(%{offset?: true}) ==
             Q.render_pagination_schema(%{offset?: true})
  end

  test "render_query_params" do
    base = %{
      read?: true,
      enable_sort?: true,
      sortable_fields: ["b", "a"],
      pagination: %{offset?: true, required?: true}
    }

    {:ok, %{sort: s, page: p}} = Q.render_query_params(base)
    admitted!(s)
    admitted!(p)
    assert s =~ "a|b"
    assert {:ok, %{sort: nil, page: nil}} = Q.render_query_params(Map.put(base, :get?, true))
    assert {:ok, %{sort: nil}} = Q.render_query_params(%{base | enable_sort?: false})
    assert {:ok, %{page: nil}} = Q.render_query_params(%{base | pagination: nil})
    assert Q.render_query_params(base) == Q.render_query_params(base)
  end

  test "result shapes executed under real zod" do
    rec = "z.object({id: z.string()}).strict()"
    {:ok, off} = Q.render_offset_result_schema(rec)
    {:ok, key} = Q.render_keyset_result_schema(rec)
    admitted!(off)
    admitted!(key)

    o = %{results: [%{id: "1"}], hasMore: false, limit: 5, offset: 0, count: nil, type: "offset"}
    assert node_parse(off, o)
    refute node_parse(off, %{o | type: "keyset"})
    assert node_parse(off, Map.delete(o, :count))

    k = %{
      results: [],
      hasMore: true,
      limit: 5,
      after: nil,
      before: nil,
      previousPage: "p",
      nextPage: "n",
      count: 3,
      type: "keyset"
    }

    assert node_parse(key, k)

    {:ok, mixed} =
      Q.render_page_result_schema(rec, %{offset?: true, keyset?: true, required?: true})

    admitted!(mixed)
    assert String.starts_with?(mixed, "z.union([")
    assert node_parse(mixed, o) and node_parse(mixed, k)

    {:ok, opt} = Q.render_page_result_schema(rec, %{offset?: true})
    admitted!(opt)
    assert node_parse(opt, [%{id: "1"}]) and node_parse(opt, o)
    refute node_parse(opt, [%{nope: 1}])
    assert {:error, :pagination_unsupported} = Q.render_page_result_schema(rec, %{})
  end

  test "typed query input envelope" do
    {:ok, s} = Q.render_sort_schema(["a"])

    {:ok, z} =
      Q.render_typed_query_input_schema(%{input: "z.object({}).strict()", sort: s, page: nil})

    admitted!(z)
    assert node_parse(z, %{})
    assert node_parse(z, %{sort: "-a"})
    refute node_parse(z, %{page: %{}})

    {:ok, req} =
      Q.render_typed_query_input_schema(%{input: "z.object({}).strict()"}, required: [:input])

    refute node_parse(req, %{})
    assert node_parse(req, %{input: %{}})
  end
end
