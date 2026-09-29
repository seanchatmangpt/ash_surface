defmodule AshSurface.FuzzProjectorsTest do
  @moduledoc """
  Decode-boundary fuzzing of the projectors over Codec-decoded random IR
  (Chicago school: real `IR.Codec`, real `Projectors.JS` / `ARIA` /
  `LiveView`, and a real `node --check` on emitted artifacts; no doubles).

  The IR an application receives from the wire is untrusted: it is produced by
  `IR.Codec.from_map/1` over arbitrary JSON, so projectors see facts they
  never authored (hostile names, `*/` in comments, non-string zod, nested junk).

  Laws pinned:

    1. `Projectors.JS.project_ir/2` never raises over decoded IR: it returns
       `{:ok, %{filename => code}, meta}` or a typed `{:error, _}`. Whenever it
       admits, the emitted `.mjs` passes `node --check` (capped at 25 node
       invocations per run).
    2. `Projectors.LiveView.project_ir/2` never raises over decoded IR.
    3. `Projectors.ARIA.project_ir/2` raises only its two DOCUMENTED shape
       refusals (`ArgumentError`: invalid delegated live politeness, unnamed
       or non-map list-form aria input); any other exception class over
       decoded IR is a bug.
    4. Projection is deterministic: the same decoded IR projects to identical
       bytes twice.

  Bounded: 200 Elixir-side cases per property; 25 node checks.
  """

  use ExUnit.Case, async: true
  use ExUnitProperties

  alias AshSurface.IR
  alias AshSurface.IR.Codec
  alias AshSurface.Projectors.{ARIA, JS, LiveView}

  @runs 200
  @node_cap 25
  @scratch Path.join(Mix.Project.build_path(), "fuzz_projectors")

  setup do
    Enum.each(
      [IR.Ash, IR.Semantic, IR.Capability, IR.Presentation, IR.Schema],
      &Code.ensure_loaded!/1
    )

    :ok
  end

  defp json(0) do
    one_of([
      integer(),
      boolean(),
      constant(nil),
      string(:printable, max_length: 10),
      member_of(["OBSERVE", "DO", "*/ globalThis.pwned = 1; /*", "polite", "loud", "\u2028"])
    ])
  end

  defp json(depth) do
    frequency([
      {4, json(0)},
      {1, list_of(json(depth - 1), max_length: 3)},
      {1,
       map(
         list_of({string(:alphanumeric, max_length: 6), json(depth - 1)}, max_length: 3),
         &Map.new/1
       )}
    ])
  end

  # Every fact generator has two domains. :typed is the IR struct's declared
  # domain (resource/action names are strings, order is a non-negative
  # integer, aria carriers are named shapes); :hostile additionally admits
  # any JSON value in the same slot, which is what an untrusted wire map can
  # carry through `IR.Codec.from_map/1`, since the codec types sections but
  # not their scalar facts.
  defp domain(:typed, typed), do: typed
  defp domain(:hostile, typed), do: frequency([{3, typed}, {1, json(1)}])

  defp resource(mode) do
    domain(
      mode,
      frequency([
        {6, member_of(["Shop.Cart", "Blog.Post", "Forum.Post", "App.Todo", "Todo", "A.B.C"])},
        {2,
         member_of(["Object", "z", "Post Office", "", "my-thing", "class", "Todo_create_schema"])}
      ])
    )
  end

  defp action(mode) do
    domain(
      mode,
      frequency([
        {6, member_of(["read", "create", "update", "delete", "list", "record"])},
        {2, member_of(["add-item", "__proto__", "constructor", "", "1st", "new"])}
      ])
    )
  end

  defp zod do
    frequency([
      {3, constant(nil)},
      {5,
       member_of([
         "z.object({ title: z.string().min(1) })",
         "z.string().uuid().optional()",
         "z.record(z.string(), z.unknown())",
         "z.object({})"
       ])},
      {3,
       member_of([
         "z.string(); globalThis.pwned = 1",
         "z.string().constructor",
         "z.object({__proto__: z.string()})",
         "(() => 1)()",
         "",
         "z"
       ])},
      {1, json(1)}
    ])
  end

  defp aria(mode) do
    name_keyed =
      map(
        list_of(
          {string(:alphanumeric, min_length: 1, max_length: 5),
           map(
             list_of({member_of(["role", "required", "describedby"]), json(0)}, max_length: 3),
             &Map.new/1
           )},
          max_length: 3
        ),
        &Map.new/1
      )

    named_list =
      map(
        list_of(
          map(
            list_of({member_of(["role", "required", "describedby"]), json(0)}, max_length: 3),
            fn facts -> Map.put(Map.new(facts), "name", "field") end
          ),
          max_length: 3
        ),
        &%{"fields" => &1}
      )

    typed =
      frequency([
        {3, constant(nil)},
        {2, name_keyed},
        {2, named_list},
        {1, map(member_of(["polite", "assertive", "off", "loud"]), &%{"live" => &1})}
      ])

    case mode do
      :typed ->
        typed

      :hostile ->
        frequency([
          {3, typed},
          {3,
           map(
             list_of(
               {member_of(["role", "live", "inputs", "fields", "title", "x"]), json(2)},
               max_length: 4
             ),
             &Map.new/1
           )}
        ])
    end
  end

  defp policies do
    one_of([
      constant([]),
      list_of(
        map(list_of({member_of(["authorityBoundary", "x"]), json(0)}, max_length: 2), &Map.new/1),
        max_length: 2
      )
    ])
  end

  defp inputs do
    one_of([
      constant([]),
      list_of(
        map(
          list_of({member_of(["name", "type", "required", "default"]), json(0)}, max_length: 4),
          &Map.new/1
        ),
        max_length: 3
      )
    ])
  end

  defp presentation(mode) do
    typed =
      gen all(
            label <- one_of([constant(nil), string(:printable, max_length: 8)]),
            group <- one_of([constant(nil), member_of(["Admin", "Public", "*/ x /*"])]),
            order <- one_of([constant(nil), integer(0..9)]),
            widget <- one_of([constant(nil), member_of(["text", "number"])])
          ) do
        %{"label" => label, "group" => group, "order" => order, "widget" => widget}
      end

    frequency([
      {2, constant(nil)},
      {4, typed},
      {if(mode == :hostile, do: 3, else: 0),
       map(
         list_of(
           {member_of(["format", "group", "label", "order", "widget"]), json(0)},
           max_length: 5
         ),
         &Map.new/1
       )}
    ])
  end

  defp ir_map(mode) do
    gen all(
          resource <- resource(mode),
          action <- action(mode),
          action_type <- member_of(["read", "create", "update", "destroy", "action", nil]),
          inputs <- inputs(),
          policies <- policies(),
          presentation <- presentation(mode),
          zod <- zod(),
          aria <- aria(mode),
          version <- member_of(["v1", "v1", "v1", "v2", nil])
        ) do
      %{
        "version" => version,
        "ash" => %{
          "resource" => resource,
          "action" => action,
          "action_type" => action_type,
          "inputs" => inputs,
          "policies" => policies
        },
        "semantic" => nil,
        "capability" => nil,
        "presentation" => presentation,
        "schema" => %{"zod" => zod, "aria" => aria}
      }
    end
  end

  # Decoded IR only: the codec's own verdict gates what projectors see.
  defp decoded_ir(mode) do
    mode
    |> ir_map()
    |> map(&Codec.from_map/1)
    |> filter(&match?({:ok, _}, &1))
    |> map(&elem(&1, 1))
  end

  defp decoded_irs(mode \\ :typed), do: list_of(decoded_ir(mode), min_length: 1, max_length: 3)

  # ARIA's two documented refusals; anything else is a crash.
  defp aria_outcome(irs) do
    {:ok, _contract, _meta} = ARIA.project_ir(irs)
    :projected
  rescue
    error in ArgumentError ->
      msg = Exception.message(error)

      if msg =~ "invalid delegated live politeness" or msg =~ "unnamed list-form aria input" or
           msg =~ "list-form aria inputs must be maps" do
        :documented_refusal
      else
        reraise error, __STACKTRACE__
      end
  end

  property "JS project_ir never raises over decoded IR and is deterministic" do
    check all(irs <- decoded_irs(), max_runs: @runs) do
      first = JS.project_ir(irs)
      assert match?({:ok, %{}, %{}}, first) or match?({:error, _}, first)
      assert JS.project_ir(irs) == first
    end
  end

  property "LiveView project_ir never raises over decoded IR and is deterministic" do
    check all(irs <- decoded_irs(), max_runs: @runs) do
      first = LiveView.project_ir(irs, [])
      assert match?({:ok, %{}, %{}}, first) or match?({:error, _}, first)
      assert LiveView.project_ir(irs, []) == first
    end
  end

  property "ARIA project_ir raises only its documented shape refusals over decoded IR" do
    check all(irs <- decoded_irs(), max_runs: @runs) do
      assert aria_outcome(irs) in [:projected, :documented_refusal]
    end
  end

  test "every admitted JS artifact over decoded IR passes node --check (capped)" do
    File.mkdir_p!(@scratch)

    artifacts =
      decoded_irs()
      |> Enum.take(400)
      |> Enum.flat_map(fn irs ->
        case JS.project_ir(irs) do
          {:ok, files, _meta} -> Map.values(files)
          {:error, _} -> []
        end
      end)
      |> Enum.uniq()
      |> Enum.take(@node_cap)

    assert length(artifacts) >= 10, "generators admitted too few JS artifacts to be meaningful"

    for {code, index} <- Enum.with_index(artifacts) do
      path = Path.join(@scratch, "#{System.unique_integer([:positive])}_#{index}.mjs")
      File.write!(path, code)
      assert {_, 0} = System.cmd("node", ["--check", path], stderr_to_stdout: true), code
    end
  end

  test "the generators are not vacuous: JS admits and refuses" do
    outcomes =
      decoded_irs()
      |> Enum.take(300)
      |> Enum.map(&elem(JS.project_ir(&1), 0))
      |> Enum.frequencies()

    assert outcomes[:ok] > 10
    assert outcomes[:error] > 10
  end

  # The hostile domain: scalar facts of the wrong type, arriving through
  # `IR.Codec.from_map/1` (which admits any JSON in a fact slot). Measured
  # crash classes, now typed at the decode boundary (`IR.Codec.validate_facts/1`,
  # `{:error, {:invalid_fact, section, field}}`) and re-checked by every projector.

  property "HOSTILE JS project_ir never raises over decoded IR" do
    check all(irs <- decoded_irs(:hostile), max_runs: @runs) do
      assert match?({:ok, _, _}, JS.project_ir(irs)) or match?({:error, _}, JS.project_ir(irs))
    end
  end

  property "HOSTILE LiveView project_ir never raises over decoded IR" do
    check all(irs <- decoded_irs(:hostile), max_runs: @runs) do
      assert match?({:ok, _, _}, LiveView.project_ir(irs, [])) or
               match?({:error, _}, LiveView.project_ir(irs, []))
    end
  end

  property "HOSTILE ARIA project_ir raises only documented refusals over decoded IR" do
    check all(irs <- decoded_irs(:hostile), max_runs: @runs) do
      assert aria_outcome(irs) in [:projected, :documented_refusal]
    end
  end
end
