defmodule AshSurface.Ported.Rpc.C.NestedQueryOptsPipelineSurfaceTest do
  @moduledoc """
  Port of the reference nested_query_opts_pipeline tests that are decidable without an action
  run: request parsing (load restrictions, entrypoint flags) and result processing of
  caller-built records/pages through the non-actuating pipeline. Test 14 (multitenant paging within
  a tenant needs a data layer) stays a loud skip in the gap file.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Ported.Rpc, as: R
  alias AshSurface.Ported, as: P

  describe "load restrictions cover envelope loads (PR #75 bypass regression)" do
    test "denied nested path inside an envelope is rejected" do
      params = %{
        "action" => "list_todos_deny_nested",
        "fields" => [
          "id",
          %{"comments" => %{"limit" => 2, "fields" => ["id", %{"todo" => ["id"]}]}}
        ]
      }

      assert {:error, {:load_denied, denied}} = R.parse(params)
      assert Enum.any?(denied, &(&1 =~ "todo"))
    end

    test "allowed envelope load passes" do
      params = %{
        "action" => "list_todos_allow_nested",
        "fields" => [
          "id",
          %{"comments" => %{"limit" => 2, "fields" => ["id", %{"todo" => ["id"]}]}}
        ]
      }

      assert {:ok, request} = R.parse(params)
      assert [{:comments, %Ash.Query{}}] = request.load
    end

    test "envelope load not in the allow list is rejected" do
      params = %{
        "action" => "list_todos_allow_only_user",
        "fields" => ["id", %{"comments" => %{"limit" => 2, "fields" => ["id"]}}]
      }

      assert {:error, {:load_not_allowed, disallowed}} = R.parse(params)
      assert "comments" in disallowed
    end

    test "denied_loads blocks paths inside a paged envelope (bypass regression)" do
      assert %{"success" => false, "errors" => errors} =
               R.error(%{
                 "action" => "list_todos_deny_nested",
                 "fields" => [
                   "id",
                   %{
                     "comments" => %{
                       "page" => %{"limit" => 2},
                       "fields" => ["id", %{"todo" => ["id"]}]
                     }
                   }
                 ]
               })

      assert Enum.any?(List.wrap(errors), fn e ->
               e["type"] in ["load_denied", :load_denied]
             end)
    end
  end

  describe "entrypoint flags gate nested envelopes" do
    test "nested filter under an enable_filter?: false action errors as disabled" do
      params = %{
        "action" => "list_todos_no_filter",
        "fields" => [
          "id",
          %{"comments" => %{"filter" => %{"rating" => %{"eq" => 1}}, "fields" => ["id"]}}
        ]
      }

      assert {:error, {:filter_not_supported, :comments, :disabled, []}} = R.parse(params)
    end

    test "nested sort under an enable_sort?: false action errors as disabled" do
      params = %{
        "action" => "list_todos_no_sort",
        "fields" => ["id", %{"comments" => %{"sort" => "-rating", "fields" => ["id"]}}]
      }

      assert {:error, {:sort_not_supported, :comments, :disabled, []}} = R.parse(params)
    end

    test "nested filter under a default action passes" do
      params = %{
        "action" => "list_todos",
        "fields" => [
          "id",
          %{"comments" => %{"filter" => %{"rating" => %{"eq" => 1}}, "fields" => ["id"]}}
        ]
      }

      assert {:ok, _request} = R.parse(params)
    end
  end

  describe "result shaping of caller-built nested pages" do
    defp comment(attrs), do: struct(P.TodoComment, attrs)

    test "offset-paged nested comments return the top-level page shape" do
      page =
        struct(Ash.Page.Offset, %{
          results: [
            comment(%{id: "c1", content: "comment-1"}),
            comment(%{id: "c2", content: "comment-2"})
          ],
          limit: 2,
          offset: 0,
          count: 5,
          more?: true
        })

      todo = struct(P.Todo, %{id: "t1"}) |> Map.put(:comments, page)

      assert %{"success" => true, "data" => data} =
               R.run(
                 %{
                   "action" => "get_todo",
                   "input" => %{"id" => "t1"},
                   "fields" => [
                     "id",
                     %{
                       "comments" => %{
                         "page" => %{"limit" => 2, "offset" => 0, "count" => true},
                         "sort" => "content",
                         "fields" => ["id", "content"]
                       }
                     }
                   ]
                 },
                 todo
               )

      page = data["comments"]
      assert page["type"] == :offset
      assert page["limit"] == 2
      assert page["offset"] == 0
      assert page["hasMore"] == true
      assert page["count"] == 5

      assert [%{"content" => "comment-1"}, %{"content" => "comment-2"}] = page["results"]
    end

    test "keyset-paged nested comments carry cursors; empty pages have nil cursors" do
      keyset = fn results, cursor_for_first, cursor_for_last ->
        struct(Ash.Page.Keyset, %{
          results: results,
          limit: 5,
          more?: false,
          before: cursor_for_first,
          after: cursor_for_last
        })
      end

      c1 = comment(%{id: "c1"}) |> Map.put(:__metadata__, %{keyset: "cur-1"})
      c2 = comment(%{id: "c2"}) |> Map.put(:__metadata__, %{keyset: "cur-2"})

      params = fn ->
        %{
          "action" => "get_todo",
          "input" => %{"id" => "t1"},
          "fields" => [
            "id",
            %{"comments" => %{"page" => %{"limit" => 5}, "sort" => "content", "fields" => ["id"]}}
          ]
        }
      end

      full = struct(P.Todo, %{id: "t1"}) |> Map.put(:comments, keyset.([c1, c2], nil, nil))
      assert %{"success" => true, "data" => data} = R.run(params.(), full)
      page = data["comments"]
      assert page["type"] == :keyset
      assert is_binary(page["nextPage"])
      assert is_binary(page["previousPage"])

      empty = struct(P.Todo, %{id: "t1"}) |> Map.put(:comments, keyset.([], nil, nil))
      assert %{"success" => true, "data" => empty_data} = R.run(params.(), empty)
      empty_page = empty_data["comments"]
      assert empty_page["results"] == []
      assert empty_page["previousPage"] == nil
      assert empty_page["nextPage"] == nil
    end

    test "filtered/sorted/limited nested comments keep the plain array shape" do
      todo =
        struct(P.Todo, %{id: "t1"})
        |> Map.put(:comments, [
          comment(%{id: "c1", rating: 5}),
          comment(%{id: "c2", rating: 3})
        ])

      assert %{"success" => true, "data" => data} =
               R.run(
                 %{
                   "action" => "get_todo",
                   "input" => %{"id" => "t1"},
                   "fields" => [
                     "id",
                     %{
                       "comments" => %{
                         "filter" => %{"rating" => %{"greaterThan" => 2}},
                         "sort" => "-rating",
                         "limit" => 2,
                         "fields" => ["id", "rating"]
                       }
                     }
                   ]
                 },
                 todo
               )

      assert [%{"id" => "c1", "rating" => 5}, %{"id" => "c2", "rating" => 3}] = data["comments"]
    end

    test "offset-only and keyset-only relationships page end-to-end" do
      c1 = comment(%{id: "c1"}) |> Map.put(:__metadata__, %{keyset: "cur-1"})
      c2 = comment(%{id: "c2"}) |> Map.put(:__metadata__, %{keyset: "cur-2"})

      offset_page =
        struct(Ash.Page.Offset, %{results: [c1, c2], limit: 2, offset: 0, count: 3, more?: true})

      keyset_page =
        struct(Ash.Page.Keyset, %{
          results: [c1, c2],
          limit: 2,
          more?: true,
          before: nil,
          after: nil
        })

      offset_todo = struct(P.Todo, %{id: "t1"}) |> Map.put(:offset_comments, offset_page)

      assert %{"success" => true, "data" => offset_data} =
               R.run(
                 %{
                   "action" => "get_todo",
                   "input" => %{"id" => "t1"},
                   "fields" => [
                     "id",
                     %{
                       "offsetComments" => %{
                         "page" => %{"limit" => 2, "offset" => 0, "count" => true},
                         "fields" => ["id"]
                       }
                     }
                   ]
                 },
                 offset_todo
               )

      offset_result = offset_data["offsetComments"]
      assert offset_result["type"] == :offset
      assert offset_result["count"] == 3
      assert offset_result["hasMore"] == true
      assert length(offset_result["results"]) == 2

      keyset_todo = struct(P.Todo, %{id: "t1"}) |> Map.put(:keyset_comments, keyset_page)

      assert %{"success" => true, "data" => keyset_data} =
               R.run(
                 %{
                   "action" => "get_todo",
                   "input" => %{"id" => "t1"},
                   "fields" => [
                     "id",
                     %{"keysetComments" => %{"page" => %{"limit" => 2}, "fields" => ["id"]}}
                   ]
                 },
                 keyset_todo
               )

      keyset_result = keyset_data["keysetComments"]
      assert keyset_result["type"] == :keyset
      assert length(keyset_result["results"]) == 2
      assert is_binary(keyset_result["nextPage"])
    end

    test "many_to_many envelope loads through the join resource" do
      commenter = struct(P.User, %{id: "u1", name: "Nested QO User"})

      plain = struct(P.Todo, %{id: "t1"}) |> Map.put(:commenters, [commenter, commenter])

      assert %{"success" => true, "data" => data} =
               R.run(
                 %{
                   "action" => "get_todo",
                   "input" => %{"id" => "t1"},
                   "fields" => [
                     "id",
                     %{
                       "commenters" => %{
                         "sort" => "name",
                         "limit" => 5,
                         "fields" => ["id", "name"]
                       }
                     }
                   ]
                 },
                 plain
               )

      assert [%{"name" => "Nested QO User"}] = Enum.uniq(data["commenters"])

      paged =
        struct(P.Todo, %{id: "t1"})
        |> Map.put(
          :commenters,
          struct(Ash.Page.Offset, %{
            results: [commenter],
            limit: 5,
            offset: 0,
            count: nil,
            more?: false
          })
        )

      assert %{"success" => true, "data" => paged_data} =
               R.run(
                 %{
                   "action" => "get_todo",
                   "input" => %{"id" => "t1"},
                   "fields" => [
                     "id",
                     %{
                       "commenters" => %{
                         "page" => %{"limit" => 5, "offset" => 0},
                         "fields" => ["id"]
                       }
                     }
                   ]
                 },
                 paged
               )

      assert paged_data["commenters"]["type"] == :offset
      assert is_list(paged_data["commenters"]["results"])
    end

    test "nested envelope works on a create result" do
      todo = struct(P.Todo, %{id: "t1", title: "With comments"}) |> Map.put(:comments, [])

      assert %{"success" => true, "data" => data} =
               R.run(
                 %{
                   "action" => "create_todo",
                   "input" => %{"title" => "With comments", "userId" => "u1"},
                   "fields" => ["id", %{"comments" => %{"limit" => 1, "fields" => ["id"]}}]
                 },
                 todo
               )

      assert data["comments"] == []
    end
  end
end
