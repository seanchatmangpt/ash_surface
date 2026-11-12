defmodule AshSurface.Ported.Codegen.PaginationTypesTest do
  @moduledoc """
  Adaptation of ash_typescript `codegen/pagination_types_test.exs`.

  The reference regex-matches generated TypeScript (`InferSearchPaginatedTodosResult`,
  `ListTodoCommentsKeysetConfig`, ...). ash_surface emits Zod, not `.ts` (README), so each
  reference test becomes behavior under node with real zod, driven by the pagination
  facts of real Ash read actions (`QuerySchema` renders the input config and the page result
  schema from those facts).

  Reference test -> port:

    * required offset result includes count + type discriminant -> offset result schema
    * countable keyset accepts `count` -> keyset input config accepts boolean `count`
    * non-countable keyset rejects `count` -> keyset input config (strict) rejects `count`
    * keyset cursors nullable -> keyset result accepts `null` previousPage/nextPage
  """
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.QuerySchema

  defmodule Item do
    use Ash.Resource,
      domain: nil,
      data_layer: Ash.DataLayer.Ets,
      validate_domain_inclusion?: false

    ets do
      private?(true)
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, public?: true)
    end

    actions do
      defaults([:read])

      # offset-only, required, countable (the reference's :search_paginated)
      read :search_paginated do
        pagination do
          offset?(true)
          keyset?(false)
          required?(true)
          countable(true)
          default_limit(10)
        end
      end

      # keyset-only, countable (the reference's TodoComment :read_keyset_only)
      read :read_keyset_only do
        pagination do
          offset?(false)
          keyset?(true)
          required?(false)
          countable(true)
          default_limit(10)
        end
      end

      # keyset-only, not countable (the reference's Todo :list_recent)
      read :list_recent do
        pagination do
          offset?(false)
          keyset?(true)
          required?(false)
          countable(false)
          default_limit(10)
        end
      end
    end
  end

  @record "z.object({ id: z.string() })"

  defp flags(action) do
    p = Ash.Resource.Info.action(Item, action).pagination

    %{
      offset?: p.offset? == true,
      keyset?: p.keyset? == true,
      required?: p.required? == true,
      countable?: p.countable in [true, :by_default]
    }
  end

  defp node_parse(zod, value) do
    js =
      "import {z} from 'zod'; const s = #{zod}; " <>
        "const r = s.safeParse(JSON.parse(process.argv[1])); process.stdout.write(String(r.success));"

    {out, 0} =
      System.cmd("node", ["--input-type=module", "-e", js, Jason.encode!(value)],
        cd: File.cwd!(),
        stderr_to_stdout: true
      )

    out == "true"
  end

  describe "required pagination result types" do
    test "required offset pagination includes count and type discriminant" do
      f = flags(:search_paginated)
      assert %{offset?: true, keyset?: false, required?: true, countable?: true} = f

      {:ok, zod} = QuerySchema.render_page_result_schema(@record, f)

      page = %{results: [%{id: "a"}], hasMore: false, limit: 10, offset: 0, type: "offset"}

      # count is always allowed (null unless counted); the type discriminant is "offset"
      assert node_parse(zod, Map.put(page, :count, nil))
      assert node_parse(zod, Map.put(page, :count, 3))
      assert node_parse(zod, page)
      refute node_parse(zod, Map.put(page, :type, "keyset"))
      refute node_parse(zod, Map.delete(page, :type))
      # required: a bare array is not an admitted result
      refute node_parse(zod, [%{id: "a"}])
    end
  end

  describe "keyset-only pagination config" do
    test "countable keyset action accepts count?: boolean" do
      f = flags(:read_keyset_only)
      assert %{offset?: false, keyset?: true, countable?: true} = f
      {:ok, zod} = QuerySchema.render_pagination_schema(f)

      assert node_parse(zod, %{limit: 5, count: true})
      assert node_parse(zod, %{limit: 5, count: false})
      assert node_parse(zod, %{limit: 5})
      refute node_parse(zod, %{limit: 5, count: "yes"})
    end

    test "non-countable keyset action rejects count" do
      f = flags(:list_recent)
      assert %{offset?: false, keyset?: true, countable?: false} = f
      {:ok, zod} = QuerySchema.render_pagination_schema(f)

      refute node_parse(zod, %{limit: 5, count: true})
      refute node_parse(zod, %{limit: 5, count: false})
      assert node_parse(zod, %{limit: 5})
    end
  end

  describe "keyset pagination cursor nullability" do
    test "previousPage/nextPage are nullable (runtime sends null for empty pages)" do
      {:ok, zod} = QuerySchema.render_page_result_schema(@record, flags(:read_keyset_only))

      page = %{
        results: [],
        hasMore: false,
        limit: 10,
        after: nil,
        before: nil,
        previousPage: nil,
        nextPage: nil,
        type: "keyset"
      }

      assert node_parse(zod, page)
      assert node_parse(zod, %{page | previousPage: "p", nextPage: "n"})
      assert node_parse(zod, %{page | previousPage: "p", nextPage: nil})
      assert node_parse(zod, %{page | previousPage: nil, nextPage: "n"})
      # still not arbitrary values
      refute node_parse(zod, %{page | nextPage: 1})
      refute node_parse(zod, Map.delete(page, :nextPage))
    end
  end
end
