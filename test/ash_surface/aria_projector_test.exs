defmodule AshSurface.AriaProjectorTest do
  @moduledoc """
  Deep ARIA contract for the ash_surface presentation projector (deepens v19).

  The `project_ir/2` contract is declared locally in this file — single
  declaration, no duplicates — and exercised on six axes:

    * the complete type->role table (closed; unknown types are refused rather
      than defaulted to a presentation role),
    * required-field announcement (`aria-required` present iff required;
      absence, never negation),
    * tab order across groups (sequential, unique, gapless, continuous over
      group boundaries, interactive nodes only),
    * live-region semantics for OBSERVE surfaces ONLY — DO consequences
      never announce passively, and politeness is law, not configuration,
    * id stability across re-projections (identity is path, not position),
    * non-empty accessible names whenever presentation provides a label.

  Pure state-based tests: no config, no env, no network, no rendering engine.
  """

  use ExUnit.Case, async: true

  # The contract: the complete widget-type -> ARIA role table. Types mapping to
  # interactive roles join the tab order; static roles never do.
  @type_to_role %{
    "text" => "textbox",
    "textarea" => "textbox",
    "checkbox" => "checkbox",
    "radio" => "radio",
    "select" => "combobox",
    "listbox" => "listbox",
    "toggle" => "switch",
    "button" => "button",
    "link" => "link",
    "heading" => "heading",
    "status" => "status",
    "list" => "list",
    "table" => "table",
    "progressbar" => "progressbar"
  }

  @interactive_roles [
    "button",
    "checkbox",
    "combobox",
    "link",
    "listbox",
    "radio",
    "switch",
    "textbox"
  ]
  @static_roles ["group", "heading", "list", "progressbar", "status", "table"]

  # ------------------------------------------------------------------
  # project_ir/2 — the locally declared ARIA projection contract.
  #
  # ir :: %{
  #   "surfaceId" => binary(),
  #   "authorityBoundary" => "OBSERVE" | "SELECT" | "CONSTRUCT" | "DO",
  #   "groups" => [%{"id" => binary(), "label" => optional(binary()),
  #                 "fields" => [%{"id" => binary(), "type" => binary(),
  #                                "label" => optional(binary()),
  #                                "required" => optional(boolean()),
  #                                "live" => optional(binary())}]}]
  # }
  #
  # Returns the consumer-visible projection: one node per group container and
  # per field, with role, accessible name, announcement attributes, and the
  # surface-wide tab order and live-region channel.
  # ------------------------------------------------------------------
  defp project_ir(ir, opts \\ []) when is_map(ir) and is_list(opts) do
    surface_id = required_key!(ir, "surfaceId")
    boundary = required_key!(ir, "authorityBoundary")
    groups = Map.get(ir, "groups", [])

    assert_live_lawful!(ir, groups, boundary)

    {nodes, _final_tab} =
      Enum.reduce(groups, {[], 0}, fn group, {acc, tab} ->
        {projected, next_tab} = project_group(surface_id, group, tab)
        {acc ++ projected, next_tab}
      end)

    assert_unique_ids!(nodes)

    %{
      "surfaceId" => surface_id,
      "authorityBoundary" => boundary,
      "nodes" => nodes,
      "surfaceAria" => surface_aria(boundary, opts)
    }
  end

  defp required_key!(map, key) do
    case Map.fetch(map, key) do
      {:ok, value} -> value
      :error -> raise ArgumentError, "accessibility IR requires #{inspect(key)}"
    end
  end

  # A live region is a request whenever any surface, group, or field carries a
  # "live" key. Requests are lawful on OBSERVE surfaces only, and only polite.
  defp assert_live_lawful!(ir, groups, boundary) do
    requested =
      [ir | Enum.flat_map(groups, &[&1 | Map.get(&1, "fields", [])])]
      |> Enum.map(&Map.get(&1, "live"))
      |> Enum.reject(&is_nil/1)

    cond do
      requested == [] ->
        :ok

      boundary != "OBSERVE" ->
        raise ArgumentError,
              "live region requested on a #{boundary} surface: consequences never announce passively"

      requested != ["polite"] ->
        raise ArgumentError,
              "the only lawful live politeness is \"polite\", got: #{inspect(requested)}"

      true ->
        :ok
    end
  end

  defp project_group(surface_id, group, tab_start) do
    group_id = required_key!(group, "id")
    fields = Map.get(group, "fields", [])

    group_node =
      case accessible_name(group, "group #{inspect(group_id)}") do
        :none ->
          %{"id" => "#{surface_id}.#{group_id}", "role" => "group", "aria" => %{}}

        label ->
          %{
            "id" => "#{surface_id}.#{group_id}",
            "role" => "group",
            "aria" => %{},
            "label" => label
          }
      end

    {field_nodes, next_tab} =
      fields
      |> Enum.reduce({[], tab_start}, fn field, {acc, tab} ->
        node = project_field(surface_id, group_id, field)

        {node, tab} =
          if node["role"] in @interactive_roles do
            {Map.put(node, "tabindex", tab + 1), tab + 1}
          else
            {node, tab}
          end

        {[node | acc], tab}
      end)
      |> then(fn {reversed, tab} -> {Enum.reverse(reversed), tab} end)

    {[group_node | field_nodes], next_tab}
  end

  defp project_field(surface_id, group_id, field) do
    field_id = required_key!(field, "id")
    type = required_key!(field, "type")

    role =
      case Map.fetch(@type_to_role, type) do
        {:ok, role} ->
          role

        :error ->
          raise ArgumentError,
                "unknown widget type #{inspect(type)}: " <>
                  "the type->role table is closed, there is no presentation fallback"
      end

    node = %{
      "id" => Enum.join([surface_id, group_id, field_id], "."),
      "role" => role,
      "aria" => aria_announcements(field)
    }

    case accessible_name(field, "field #{inspect(field_id)}") do
      :none -> node
      label -> Map.put(node, "label", label)
    end
  end

  # Required-ness is announced as presence of aria-required="true"; an absent
  # attribute means "not required" — absence, never a negated "false".
  defp aria_announcements(field) do
    case field do
      %{"required" => true} -> %{"required" => "true"}
      _ -> %{}
    end
  end

  # A provided label must trim to a non-empty accessible name; a blank label
  # is fabrication and is refused. No label key is fabricated when
  # presentation provides none.
  defp accessible_name(map, what) do
    case Map.fetch(map, "label") do
      :error ->
        :none

      {:ok, label} when is_binary(label) ->
        trimmed = String.trim(label)

        if trimmed == "" do
          raise ArgumentError,
                "#{what} declares a blank label: presentation must not fabricate empty accessible names"
        end

        trimmed

      {:ok, other} ->
        raise ArgumentError, "#{what} label must be a binary, got: #{inspect(other)}"
    end
  end

  # Politeness is law, not configuration: the `opts` channel (e.g. a forged
  # `live:` politeness) never widens the announcement semantics.
  defp surface_aria("OBSERVE", _opts), do: %{"live" => "polite"}
  defp surface_aria(_boundary, _opts), do: %{}

  defp assert_unique_ids!(nodes) do
    ids = Enum.map(nodes, & &1["id"])
    duplicates = ids -- Enum.uniq(ids)

    if duplicates != [] do
      raise ArgumentError,
            "duplicate accessible node ids would break re-projection stability: #{inspect(duplicates)}"
    end
  end

  # State builders: concrete contract state, no mocks.

  defp ir(boundary, groups) do
    %{"surfaceId" => "needs_surface", "authorityBoundary" => boundary, "groups" => groups}
  end

  defp group(id, fields), do: %{"id" => id, "fields" => fields}

  defp field(id, type, extra \\ []) do
    Map.new([{"id", id}, {"type", type} | Enum.map(extra, fn {k, v} -> {to_string(k), v} end)])
  end

  defp ids(projection), do: Enum.map(projection["nodes"], & &1["id"])

  defp nodes_by_id(projection), do: Map.new(projection["nodes"], &{&1["id"], &1})

  defp tabbed_surface do
    ir("OBSERVE", [
      %{
        "id" => "filters",
        "label" => "Filters",
        "fields" => [
          field("q", "text", label: "Search"),
          field("status", "select", label: "Status", required: true)
        ]
      },
      group("actions", [
        field("save", "button", label: "Save"),
        field("results", "heading", label: "Results")
      ]),
      group("more", [field("open", "link", label: "Open")])
    ])
  end

  describe "type->role table (complete and closed)" do
    test "every entry of the table projects to its exact role" do
      fields = Enum.map(@type_to_role, fn {type, _role} -> field("f_#{type}", type) end)
      projection = project_ir(ir("OBSERVE", [group("g", fields)]))
      by_id = nodes_by_id(projection)

      for {type, role} <- @type_to_role do
        assert by_id["needs_surface.g.f_#{type}"]["role"] == role
      end
    end

    test "the table is a closed partition: every role is interactive or static, never both" do
      interactive = MapSet.new(@interactive_roles)
      static = MapSet.new(@static_roles)
      # The emitted role universe is the table plus the group container role.
      roles = @type_to_role |> Map.values() |> MapSet.new() |> MapSet.put("group")

      assert MapSet.union(interactive, static) == roles
      assert MapSet.disjoint?(interactive, static)
    end

    test "an unknown widget type is refused, not defaulted to a presentation role" do
      assert_raise ArgumentError, ~r/type->role table is closed/, fn ->
        project_ir(ir("OBSERVE", [group("g", [field("mystery", "telepathy")])]))
      end
    end
  end

  describe "required-field announcement" do
    test "a required field announces aria-required=\"true\"" do
      [_, node] =
        project_ir(ir("OBSERVE", [group("g", [field("status", "select", required: true)])]))[
          "nodes"
        ]

      assert node["aria"] == %{"required" => "true"}
    end

    test "absence, not negation: a non-required field carries no required key" do
      [_, optional] =
        project_ir(ir("OBSERVE", [group("g", [field("status", "select")])]))["nodes"]

      [_, explicit] =
        project_ir(ir("OBSERVE", [group("g", [field("status", "select", required: false)])]))[
          "nodes"
        ]

      refute Map.has_key?(optional["aria"], "required")
      refute Map.has_key?(explicit["aria"], "required")
    end

    test "the announcement is uniform across every interactive type" do
      interactive_types = for {type, role} <- @type_to_role, role in @interactive_roles, do: type
      fields = Enum.map(interactive_types, &field("f_#{&1}", &1, required: true))

      nodes = project_ir(ir("OBSERVE", [group("g", fields)]))["nodes"]

      assert length(nodes) == length(interactive_types) + 1

      for node <- nodes, node["role"] != "group" do
        assert node["aria"]["required"] == "true"
      end
    end
  end

  describe "tab order across groups" do
    test "the order continues across group boundaries in declaration order" do
      by_id = tabbed_surface() |> project_ir() |> nodes_by_id()

      assert by_id["needs_surface.filters.q"]["tabindex"] == 1
      assert by_id["needs_surface.filters.status"]["tabindex"] == 2
      assert by_id["needs_surface.actions.save"]["tabindex"] == 3
      assert by_id["needs_surface.more.open"]["tabindex"] == 4
    end

    test "assignment is exactly 1..n: unique and gapless over interactive nodes" do
      nodes = tabbed_surface() |> project_ir() |> Map.fetch!("nodes")
      interactive = Enum.filter(nodes, &Map.has_key?(&1, "tabindex"))
      tabs = interactive |> Enum.map(& &1["tabindex"]) |> Enum.sort()

      assert length(Enum.uniq(tabs)) == length(tabs)
      assert tabs == Enum.to_list(1..length(interactive))
    end

    test "static roles and group containers never join the tab order" do
      nodes = tabbed_surface() |> project_ir() |> Map.fetch!("nodes")

      for node <- nodes, node["role"] in @static_roles do
        refute Map.has_key?(node, "tabindex")
      end

      assert Enum.count(nodes, &Map.has_key?(&1, "tabindex")) ==
               Enum.count(nodes, &(&1["role"] in @interactive_roles))
    end
  end

  describe "live-region semantics: OBSERVE surfaces only" do
    test "an OBSERVE surface announces politely" do
      projection = project_ir(ir("OBSERVE", [group("g", [field("state", "status")])]))

      assert projection["surfaceAria"] == %{"live" => "polite"}
    end

    test "DO surfaces never announce passively: no live key on surface or nodes" do
      projection = project_ir(ir("DO", [group("g", [field("save", "button", label: "Save")])]))

      assert projection["surfaceAria"] == %{}
      refute Enum.any?(projection["nodes"], &Map.has_key?(&1["aria"], "live"))
      refute Enum.any?(projection["nodes"], &Map.has_key?(&1, "live"))
    end

    test "SELECT and CONSTRUCT surfaces are equally silent" do
      for boundary <- ["SELECT", "CONSTRUCT"] do
        projection = project_ir(ir(boundary, [group("g", [field("pick", "listbox")])]))
        assert projection["surfaceAria"] == %{}
        assert projection["authorityBoundary"] == boundary
      end
    end

    test "a DO surface requesting a live region is refused" do
      assert_raise ArgumentError, ~r/consequences never announce passively/, fn ->
        project_ir(ir("DO", [group("g", [field("receipt", "status", live: "assertive")])]))
      end
    end

    test "an OBSERVE surface may request only \"polite\"" do
      assert_raise ArgumentError, ~r/lawful live politeness/, fn ->
        project_ir(ir("OBSERVE", [group("g", [field("chatter", "status", live: "assertive")])]))
      end
    end

    test "politeness is law, not configuration: a forged live opt never widens it" do
      projection = project_ir(ir("OBSERVE", []), live: "assertive")

      assert projection["surfaceAria"] == %{"live" => "polite"}
    end
  end

  describe "id stability across re-projections" do
    test "projecting the same IR twice yields identical nodes" do
      surface = tabbed_surface()

      assert project_ir(surface)["nodes"] == project_ir(surface)["nodes"]
    end

    test "identity is path, not position: reordering groups preserves ids and moves tabindex" do
      [filters, actions, more] = tabbed_surface()["groups"]
      reordered = %{tabbed_surface() | "groups" => [more, filters, actions]}

      stable = tabbed_surface() |> project_ir() |> ids()
      moved = reordered |> project_ir() |> ids()

      assert MapSet.new(stable) == MapSet.new(moved)
      assert hd(moved) == "needs_surface.more"

      by_id = reordered |> project_ir() |> nodes_by_id()
      assert by_id["needs_surface.more.open"]["tabindex"] == 1
      assert by_id["needs_surface.filters.q"]["tabindex"] == 2
      assert by_id["needs_surface.actions.save"]["tabindex"] == 4
    end

    test "key insertion order never enters identity" do
      ordered = ir("OBSERVE", [group("g", [field("q", "text", label: "Search")])])
      reversed = ordered |> Map.to_list() |> Enum.reverse() |> Map.new()

      assert ids(project_ir(ordered)) == ids(project_ir(reversed))
    end

    test "two fields projecting to the same id are refused" do
      assert_raise ArgumentError, ~r/duplicate accessible node ids/, fn ->
        project_ir(ir("OBSERVE", [group("g", [field("q", "text"), field("q", "text")])]))
      end
    end
  end

  describe "non-empty labels when presentation provides them" do
    test "a provided label becomes the trimmed, non-empty accessible name" do
      [_, node] =
        project_ir(ir("OBSERVE", [group("g", [field("q", "text", label: "  Search  ")])]))[
          "nodes"
        ]

      assert node["label"] == "Search"
      assert node["label"] != ""
    end

    test "blank labels are refused: an empty accessible name is fabrication" do
      for blank <- ["", "   "] do
        assert_raise ArgumentError, ~r/blank label/, fn ->
          project_ir(ir("OBSERVE", [group("g", [field("q", "text", label: blank)])]))
        end
      end
    end

    test "when presentation provides no label, none is fabricated" do
      [group_node, node] = project_ir(ir("OBSERVE", [group("g", [field("q", "text")])]))["nodes"]

      refute Map.has_key?(node, "label")
      refute Map.has_key?(group_node, "label")
    end

    test "group labels obey the same law" do
      assert_raise ArgumentError, ~r/blank label/, fn ->
        project_ir(ir("OBSERVE", [%{"id" => "g", "label" => " ", "fields" => []}]))
      end

      [group_node | _] =
        project_ir(ir("OBSERVE", [%{"id" => "g", "label" => " Filters ", "fields" => []}]))[
          "nodes"
        ]

      assert group_node["label"] == "Filters"
    end
  end

  describe "projection shape" do
    test "surface and node key sets are exactly the consumer-visible ones" do
      projection = tabbed_surface() |> project_ir()

      assert Map.keys(projection) |> Enum.sort() == [
               "authorityBoundary",
               "nodes",
               "surfaceAria",
               "surfaceId"
             ]

      interactive = Enum.find(projection["nodes"], &(&1["id"] == "needs_surface.filters.q"))

      assert Map.keys(interactive) |> Enum.sort() == ["aria", "id", "label", "role", "tabindex"]

      static = Enum.find(projection["nodes"], &(&1["role"] == "heading"))
      assert Map.keys(static) |> Enum.sort() == ["aria", "id", "label", "role"]
    end
  end
end
