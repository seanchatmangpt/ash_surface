defmodule AshSurface.Projectors.AriaProjectorTest do
  @moduledoc """
  Tests for `AshSurface.Projectors.ARIA.project_ir/2`: the ARIA contract map
  (with optional `.json` emission) projected from `IR.Schema.aria` +
  `IR.Presentation` — labelled groups, per-input role/required/
  aria-describedby with sequential `tabIndex`, tab order from the delegated
  presentation order, and live-region hints on OBSERVE surfaces only.

  The full contract and its JSON rendering are golden-frozen below: any
  semantic change to the projection must land here as a deliberate edit.
  """

  use ExUnit.Case, async: true

  alias AshSurface.IR
  alias AshSurface.Projectors.ARIA

  @golden_json "{\"contract\":\"aria\",\"groups\":[{\"id\":\"reading\",\"label\":\"reading\",\"members\":[\"Member.profile\",\"Todo.list\"],\"role\":\"group\"},{\"id\":\"writing\",\"label\":\"writing\",\"members\":[\"Todo.create\"],\"role\":\"group\"}],\"surfaces\":[{\"action\":\"profile\",\"group\":\"reading\",\"id\":\"Member.profile\",\"inputs\":[{\"aria-describedby\":\"archived-help\",\"name\":\"archived\",\"required\":false,\"role\":\"checkbox\",\"tabIndex\":1}],\"label\":\"Member profile\",\"resource\":\"Member\",\"role\":\"region\"},{\"action\":\"touch\",\"group\":null,\"id\":\"Note.touch\",\"inputs\":[],\"label\":\"Touch note\",\"resource\":\"Note\",\"role\":null},{\"action\":\"create\",\"group\":\"writing\",\"id\":\"Todo.create\",\"inputs\":[{\"aria-describedby\":\"title-help\",\"name\":\"title\",\"required\":true,\"role\":\"textbox\",\"tabIndex\":1},{\"aria-describedby\":null,\"name\":\"due_on\",\"required\":false,\"role\":\"date\",\"tabIndex\":2}],\"label\":\"Create todo\",\"resource\":\"Todo\",\"role\":null},{\"action\":\"list\",\"group\":\"reading\",\"id\":\"Todo.list\",\"inputs\":[{\"aria-describedby\":\"status-help\",\"name\":\"status\",\"required\":false,\"role\":\"combobox\",\"tabIndex\":1}],\"label\":\"List todos\",\"live\":\"polite\",\"resource\":\"Todo\",\"role\":null}],\"tabOrder\":[\"Todo.list\",\"Todo.create\",\"Member.profile\",\"Note.touch\"],\"version\":\"26.9.17\"}"

  # ---------------------------------------------------------------------------
  # Fixture IRs: an OBSERVE read with a name-keyed inputs map, a DO write
  # with list-form atom/string inputs and a delegated politeness that MUST be
  # suppressed, a CONSTRUCT with atom-keyed delegated facts and the
  # name-keyed aria fallback, and a bare surface with no aria at all.
  # ---------------------------------------------------------------------------

  defp todo_list_ir do
    IR.new(
      ash: %IR.Ash{
        resource: "Todo",
        action: :list,
        action_type: :read,
        policies: [%{"authorityBoundary" => "OBSERVE"}]
      },
      presentation: %IR.Presentation{label: "List todos", group: "reading", order: 1},
      schema: %IR.Schema{
        aria: %{
          "inputs" => %{
            "status" => %{
              "role" => "combobox",
              "required" => false,
              "describedby" => "status-help"
            }
          }
        }
      }
    )
  end

  defp todo_create_ir do
    IR.new(
      ash: %IR.Ash{
        resource: "Todo",
        action: :create,
        action_type: :create,
        policies: [%{"authorityBoundary" => "DO"}]
      },
      presentation: %IR.Presentation{label: "Create todo", group: "writing", order: 2},
      schema: %IR.Schema{
        aria: %{
          # Delegated politeness on a DO surface: dropped, never honored.
          "live" => "assertive",
          "inputs" => [
            %{name: "title", role: "textbox", required: true, describedby: "title-help"},
            %{"name" => "due_on", "role" => "date", "required" => false}
          ]
        }
      }
    )
  end

  defp member_profile_ir do
    IR.new(
      ash: %IR.Ash{
        resource: "Member",
        action: :profile,
        action_type: :read,
        policies: [%{:authorityBoundary => "CONSTRUCT"}]
      },
      presentation: %IR.Presentation{label: "Member profile", group: "reading"},
      schema: %IR.Schema{
        aria: %{
          :role => "region",
          "archived" => %{role: "checkbox", describedby: "archived-help"}
        }
      }
    )
  end

  defp note_touch_ir do
    IR.new(
      ash: %IR.Ash{
        resource: "Note",
        action: :touch,
        action_type: :update,
        policies: []
      },
      presentation: %IR.Presentation{label: "Touch note"}
    )
  end

  defp fixture_irs do
    [todo_list_ir(), todo_create_ir(), member_profile_ir(), note_touch_ir()]
  end

  defp golden_contract do
    %{
      "contract" => "aria",
      "version" => "26.9.17",
      "surfaces" => [
        %{
          "id" => "Member.profile",
          "resource" => "Member",
          "action" => "profile",
          "label" => "Member profile",
          "group" => "reading",
          "role" => "region",
          "inputs" => [
            %{
              "name" => "archived",
              "role" => "checkbox",
              "required" => false,
              "aria-describedby" => "archived-help",
              "tabIndex" => 1
            }
          ]
        },
        %{
          "id" => "Note.touch",
          "resource" => "Note",
          "action" => "touch",
          "label" => "Touch note",
          "group" => nil,
          "role" => nil,
          "inputs" => []
        },
        %{
          "id" => "Todo.create",
          "resource" => "Todo",
          "action" => "create",
          "label" => "Create todo",
          "group" => "writing",
          "role" => nil,
          "inputs" => [
            %{
              "name" => "title",
              "role" => "textbox",
              "required" => true,
              "aria-describedby" => "title-help",
              "tabIndex" => 1
            },
            %{
              "name" => "due_on",
              "role" => "date",
              "required" => false,
              "aria-describedby" => nil,
              "tabIndex" => 2
            }
          ]
        },
        %{
          "id" => "Todo.list",
          "resource" => "Todo",
          "action" => "list",
          "label" => "List todos",
          "group" => "reading",
          "role" => nil,
          "inputs" => [
            %{
              "name" => "status",
              "role" => "combobox",
              "required" => false,
              "aria-describedby" => "status-help",
              "tabIndex" => 1
            }
          ],
          "live" => "polite"
        }
      ],
      "groups" => [
        %{
          "id" => "reading",
          "label" => "reading",
          "role" => "group",
          "members" => ["Member.profile", "Todo.list"]
        },
        %{
          "id" => "writing",
          "label" => "writing",
          "role" => "group",
          "members" => ["Todo.create"]
        }
      ],
      "tabOrder" => ["Todo.list", "Todo.create", "Member.profile", "Note.touch"]
    }
  end

  describe "project_ir/2 contract" do
    test "projects the golden-frozen ARIA contract from the fixture IRs" do
      assert {:ok, contract, meta} = ARIA.project_ir(fixture_irs())

      assert contract == golden_contract()

      assert meta == %{
               prefix: "ash_surface_aria",
               surface_count: 4,
               group_count: 2,
               emitted: nil
             }
    end

    test "renders the contract as the golden-frozen JSON bytes" do
      assert {:ok, contract, _meta} = ARIA.project_ir(fixture_irs())

      assert ARIA.to_json(contract) == @golden_json
    end

    test "accepts a single IR, not only a list" do
      assert {:ok, contract, %{surface_count: 1}} = ARIA.project_ir(note_touch_ir())
      assert [%{"id" => "Note.touch"}] = contract["surfaces"]
    end
  end

  describe "live-region law (OBSERVE only)" do
    test "only OBSERVE surfaces carry a live hint; default politeness is polite" do
      assert {:ok, contract, _} = ARIA.project_ir(fixture_irs())

      live = contract["surfaces"] |> Enum.filter(& &1["live"]) |> Map.new(&{&1["id"], &1["live"]})
      assert live == %{"Todo.list" => "polite"}
    end

    test "a delegated politeness on a DO surface is dropped, never honored" do
      assert {:ok, contract, _} = ARIA.project_ir(todo_create_ir())
      refute hd(contract["surfaces"]) |> Map.has_key?("live")
    end

    test "a delegated politeness on an OBSERVE surface is admitted, case-normalized" do
      ir = %{todo_list_ir() | schema: %IR.Schema{aria: %{"live" => "ASSERTIVE"}}}

      assert {:ok, contract, _} = ARIA.project_ir(ir)
      assert hd(contract["surfaces"])["live"] == "assertive"
    end

    test "an invalid delegated politeness raises: shape is law" do
      ir = %{todo_list_ir() | schema: %IR.Schema{aria: %{"live" => "chatty"}}}

      assert_raise ArgumentError, ~r/invalid delegated live politeness/, fn ->
        ARIA.project_ir(ir)
      end
    end
  end

  describe "tab order law" do
    test "presentation.order drives tabOrder; nil sorts last, id breaks ties" do
      assert {:ok, contract, _} = ARIA.project_ir(fixture_irs())
      assert contract["tabOrder"] == ["Todo.list", "Todo.create", "Member.profile", "Note.touch"]
    end

    test "per-input tabIndex is sequential from 1 in input order" do
      assert {:ok, contract, _} = ARIA.project_ir(todo_create_ir())

      assert Enum.map(hd(contract["surfaces"])["inputs"], & &1["tabIndex"]) == [1, 2]
    end
  end

  describe "byte determinism" do
    test "repeated projection is identical, map and JSON" do
      assert {:ok, first, _} = ARIA.project_ir(fixture_irs())
      assert {:ok, second, _} = ARIA.project_ir(fixture_irs())
      assert first == second
      assert ARIA.to_json(first) == ARIA.to_json(second)
    end

    test "input reordering projects identical bytes" do
      assert {:ok, baseline, _} = ARIA.project_ir(fixture_irs())
      assert {:ok, shuffled, _} = ARIA.project_ir(Enum.reverse(fixture_irs()))
      assert shuffled == baseline
      assert ARIA.to_json(shuffled) == ARIA.to_json(baseline)
    end

    test "name-keyed inputs are name-sorted regardless of map iteration order" do
      ir = %{
        todo_list_ir()
        | schema: %IR.Schema{
            aria: %{"inputs" => %{"zebra" => %{}, "alpha" => %{}, "mid" => %{}}}
          }
      }

      assert {:ok, contract, _} = ARIA.project_ir(ir)

      assert Enum.map(hd(contract["surfaces"])["inputs"], & &1["name"]) == [
               "alpha",
               "mid",
               "zebra"
             ]
    end
  end

  describe "shape law" do
    test "an unnamed list-form input raises" do
      ir = %{todo_create_ir() | schema: %IR.Schema{aria: %{"inputs" => [%{role: "textbox"}]}}}

      assert_raise ArgumentError, ~r/unnamed list-form aria input/, fn ->
        ARIA.project_ir(ir)
      end
    end

    test "absent facts project as nil/false, never inferred" do
      assert {:ok, contract, _} = ARIA.project_ir(note_touch_ir())

      assert hd(contract["surfaces"]) == %{
               "id" => "Note.touch",
               "resource" => "Note",
               "action" => "touch",
               "label" => "Touch note",
               "group" => nil,
               "role" => nil,
               "inputs" => []
             }
    end
  end

  describe ".json emission" do
    @tag :tmp_dir
    test "without target_dir nothing is written", %{tmp_dir: tmp_dir} do
      assert {:ok, _contract, %{emitted: nil}} = ARIA.project_ir(fixture_irs())
      assert File.ls!(tmp_dir) == []
    end

    @tag :tmp_dir
    test "target_dir writes exactly one .json file with the golden bytes", %{tmp_dir: tmp_dir} do
      assert {:ok, contract, %{emitted: "ash_surface_aria.json"}} =
               ARIA.project_ir(fixture_irs(), target_dir: tmp_dir)

      assert File.ls!(tmp_dir) == ["ash_surface_aria.json"]
      assert File.read!(Path.join(tmp_dir, "ash_surface_aria.json")) == ARIA.to_json(contract)
      assert File.read!(Path.join(tmp_dir, "ash_surface_aria.json")) == @golden_json
    end

    @tag :tmp_dir
    test "custom prefix names the emitted file", %{tmp_dir: tmp_dir} do
      assert {:ok, _contract, %{prefix: "acme_aria", emitted: "acme_aria.json"}} =
               ARIA.project_ir(fixture_irs(), prefix: "acme_aria", target_dir: tmp_dir)

      assert File.ls!(tmp_dir) == ["acme_aria.json"]
    end
  end
end
