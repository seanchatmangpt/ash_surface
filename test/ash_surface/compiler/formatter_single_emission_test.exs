defmodule AshSurface.Compiler.FormatterSingleEmissionTest do
  use ExUnit.Case, async: false

  defmodule Dom do
    use Ash.Domain, validate_config_inclusion?: false
    resources do
      resource AshSurface.Compiler.FormatterSingleEmissionTest.Target
      resource AshSurface.Compiler.FormatterSingleEmissionTest.Other
      resource AshSurface.Compiler.FormatterSingleEmissionTest.Srt
    end
  end

  defmodule Emb do
    use Ash.Resource, data_layer: :embedded, domain: nil
    attributes do
      attribute :url_id, :string, public?: true
      attribute :is_active?, :boolean, public?: true
      attribute :éa_b, :string, public?: true
      attribute :id2_x, :integer, public?: true
      attribute :__x, :string, public?: true
    end
  end

  defmodule Other do
    use Ash.Resource, domain: AshSurface.Compiler.FormatterSingleEmissionTest.Dom, data_layer: Ash.DataLayer.Ets
    ets do
      private? true
    end
    attributes do
      uuid_primary_key :id, public?: true
      attribute :name, :string, public?: true
    end
    actions do
      defaults [:read]
    end
  end

  defmodule Srt do
    use Ash.Resource, domain: AshSurface.Compiler.FormatterSingleEmissionTest.Dom, data_layer: Ash.DataLayer.Ets
    ets do
      private? true
    end
    attributes do
      uuid_primary_key :id, public?: true
      attribute :url_id, :string, public?: true
      attribute :id2_x, :integer, public?: true
    end
    actions do
      defaults [:read]
    end
  end

  defmodule Target do
    use Ash.Resource, domain: AshSurface.Compiler.FormatterSingleEmissionTest.Dom, data_layer: Ash.DataLayer.Ets
    ets do
      private? true
    end
    attributes do
      uuid_primary_key :id, public?: true
      attribute :url_id, :string, public?: true
      attribute :is_active?, :boolean, public?: true
      attribute :éa_b, :string, public?: true
      attribute :id2_x, :integer, public?: true
      attribute :__x, :string, public?: true
      attribute :emb, Emb, public?: true
      attribute :tm, :map, public?: true, constraints: [fields: [url_id: [type: :string], is_active?: [type: :boolean]]]
      attribute :un, :union, public?: true, constraints: [types: [url_id: [type: :string], is_active: [type: :integer]]]
    end
    calculations do
      calculate :calc_one, :string, expr(url_id), public?: true
    end
    relationships do
      belongs_to :other_rel, Other, public?: true, attribute_public?: false
    end
    actions do
      defaults [:read, create: [:url_id, :is_active?, :éa_b, :id2_x, :__x, :emb, :tm, :un]]
    end
  end

  defmodule Up do
    @moduledoc false
    def up(field), do: field |> to_string() |> String.upcase()
  end

  alias AshSurface.Compiler.{EmbeddedSchema, RecordSchema, RouteSchema}
  alias AshSurface.FieldName

  @formatters [:pascal_case, :snake_case, :camel_case, {Up, :up}]
  @internal ~w(url_id is_active? éa_b id2_x __x)
  @uuid "123e4567-e89b-42d3-a456-426614174000"

  defp compile!(formatter) do
    Application.put_env(:ash_surface_fse, :ash_domains, [Dom])
    {:ok, manifest} = Ash.Info.Manifest.generate(otp_app: :ash_surface_fse)
    {:ok, irs} = AshSurface.Compiler.compile(manifest, output_field_formatter: formatter)
    irs
  end

  defp ir(irs, action),
    do: Enum.find(irs, &(&1.ash.resource == Target and &1.ash.action == action))

  # wire spelling of an internal name, from the IR facts (the oracle named by the defect)
  defp wire(facts, internal) do
    {w, _} = Enum.find(facts["field_names"]["fields"], fn {_w, i} -> i == internal end)
    w
  end

  defp nested(internal, formatter), do: FieldName.compute(internal, formatter)

  defp scalar("id2_x"), do: 1
  defp scalar("is_active?"), do: true
  defp scalar(_), do: "x"

  defp flat(names, spell), do: Map.new(names, &{spell.(&1), scalar(&1)})

  # a response payload spelled by `top` (top-level) and `inner` (nested containers)
  defp response(top, inner) do
    base = flat(@internal, top)

    base
    |> Map.put(top.("id"), @uuid)
    |> Map.put(top.("emb"), flat(@internal, inner))
    |> Map.put(top.("tm"), flat(["url_id", "is_active?"], inner))
    |> Map.put(top.("un"), %{inner.("url_id") => "x"})
  end

  defp node_run(artifact, cases) do
    node = AshSurface.ZodFixtures.Harness.tool!("node")
    root = File.cwd!()
    dir = AshSurface.TestTmp.unique_dir("ash_surface_fse")
    File.ln_s!(Path.join(root, "node_modules"), Path.join(dir, "node_modules"))
    File.write!(Path.join(dir, "client.mjs"), artifact)
    File.write!(Path.join(dir, "cases.json"), Jason.encode!(cases))

    File.write!(Path.join(dir, "run.mjs"), """
    import { z } from "zod";
    import { readFileSync } from "node:fs";
    import * as m from "./client.mjs";
    const cases = JSON.parse(readFileSync(new URL("./cases.json", import.meta.url), "utf8"));
    const out = cases.map((c) => {
      const schema = c.export ? m[c.export] : eval(c.expr);
      if (!schema) return "missing";
      return schema.safeParse(c.payload).success ? "accept" : "reject";
    });
    process.stdout.write(JSON.stringify(out));
    """)

    task =
      Task.async(fn -> System.cmd(node, ["run.mjs"], cd: dir, stderr_to_stdout: true) end)

    {out, 0} = Task.await(task, 60_000)
    Jason.decode!(out)
  end

  # {label, schema source, payload, expected}
  defp cases(formatter) do
    irs = compile!(formatter)
    read = ir(irs, :read)
    create = ir(irs, :create)
    facts = read.schema.facts
    top = &wire(facts, &1)
    inner = &nested(&1, formatter)
    ident = & &1

    {:ok, artifacts, _} = AshSurface.Projectors.JS.project_ir(irs)
    artifact = Map.fetch!(artifacts, "ash_surface_client.mjs")

    # the facts oracle agrees with one application of the configured formatter
    for i <- @internal, do: assert(top.(i) == FieldName.compute(i, formatter))

    exp = fn label, spec, payload_wire, payload_internal ->
      [{label <> " wire", spec, payload_wire, "accept"}] ++
        if payload_wire != payload_internal,
          do: [{label <> " internal", spec, payload_internal, "reject"}],
          else: []
    end

    s = read.schema
    rname = "Target_read_response_schema"
    resp_spec = %{export: rname}

    c =
      exp.("response", resp_spec, response(top, inner), response(ident, ident)) ++
        for(
          i <- @internal,
          op_val = scalar(i),
          pair <- exp.("filter #{i}", %{export: "Target_read_filter_schema"},
            %{field: top.(i), op: "eq", value: op_val}, %{field: i, op: "eq", value: op_val}),
          do: pair
        ) ++
        for(
          i <- ["url_id", "id2_x"],
          pair <- exp.("sort #{i}", %{export: "Srt_read_sort_schema"}, top.(i), i),
          pair2 <- [pair, put_elem(pair, 2, "-" <> elem(pair, 2))],
          do: pair2
        ) ++
        exp.("selection", %{expr: s.selection},
          %{fields: Enum.map(@internal, top)}, %{fields: @internal}) ++
        exp.("calculations.load", %{expr: s.calculations["load"]},
          %{top.("calc_one") => %{}}, %{"calc_one" => %{}}) ++
        exp.("load", %{expr: s.load}, %{top.("other_rel") => true}, %{"other_rel" => true}) ++
        exp.("validation_error", %{expr: create.schema.validation_error},
          Map.put(flat_arrays(top), top.("emb"), flat_arrays(inner)),
          Map.put(flat_arrays(ident), "emb", flat_arrays(ident))) ++
        [{"calculation result", %{expr: s.calculations["results"][top.("calc_one")]}, "x", "accept"}]

    # create input: passthrough, so bind the key by type: right type accepted, wrong rejected
    inputs =
      Enum.flat_map(@internal, fn i ->
        good = %{top.(i) => scalar(i)}
        bad = %{top.(i) => if(scalar(i) == "x", do: 7, else: "x")}

        [
          {"input #{i} good", %{export: "Target_create_schema"}, good, "accept"},
          {"input #{i} wrong-type", %{export: "Target_create_schema"}, bad, "reject"}
        ]
      end)

    {artifact, c ++ inputs}
  end

  defp flat_arrays(spell), do: Map.new(@internal, &{spell.(&1), ["m"]})

  for formatter <- @formatters do
    @tag formatter: formatter
    test "IR renderers accept facts spelling and refuse internal spelling under #{inspect(formatter)}",
         %{formatter: formatter} do
      {artifact, cs} = cases(formatter)

      wire_cases =
        Enum.map(cs, fn {_l, spec, payload, _e} -> Map.put(spec, :payload, payload) end)

      results = node_run(artifact, wire_cases)

      failures =
        for {{label, _, _, expected}, got} <- Enum.zip(cs, results), got != expected do
          {label, expected, got}
        end

      assert failures == []
      assert length(cs) > 20
    end

    test "standalone renderers emit configured spelling exactly once under #{inspect(formatter)}",
         %{} do
      f = unquote(Macro.escape(formatter))

      FieldName.with_formatter(f, fn ->
        # embedded resource reached directly
        {:ok, %{expression: expr}} = RecordSchema.render(Emb)
        for i <- @internal, do: assert(expr =~ FieldName.compute(i, f))
        assert expr |> String.split(":") |> length() > 5
        keys = for i <- @internal, do: FieldName.compute(i, f)
        assert Enum.all?(keys, &String.contains?(expr, &1))
        refute expr =~ "Urlid"

        # typed map / struct container with raw names
        {:ok, tm} =
          EmbeddedSchema.render(%{
            "type" => %{
              "kind" => "typed_map",
              "fields" => Enum.map(@internal, &%{"name" => &1, "type" => %{"kind" => "string"}})
            }
          })

        for i <- @internal, do: assert(tm =~ FieldName.compute(i, f))

        # route arguments
        case RouteSchema.build([
               %{
                 "name" => "r",
                 "path" => "/a",
                 "method" => "get",
                 "arguments" => [%{"name" => "url_id", "type" => %{"kind" => "string"}}]
               }
             ]) do
          {:ok, [%{"query" => q}]} ->
            assert q =~ FieldName.compute("url_id", f) or q =~ "url_id"

          other ->
            flunk("route build: #{inspect(other)}")
        end
      end)
    end
  end

  # ---- channel payload + route args (wave3-rw) ------------------------------------------------
  # Channel payloads render through EmbeddedSchema, so the configured formatter applies exactly
  # once to every payload key (top-level and nested). Route arguments are the HTTP request
  # surface (path template, query string, body as the controller receives them): their keys follow
  # the configured formatter once (reference route_renderer.ex:147,357,381,417 format_output_field
  # on path object, query and body keys); the router template `path`/`path_params` stay verbatim
  # and `field_names` carries the client=>server inverse (request_handler.ex:324). Both are pinned against real node + zod.

  @chan_fields [
    {"url_id", "string"},
    {"is_active?", "boolean"},
    {"éa_b", "string"},
    {"id2_x", "integer"},
    {"__x", "string"}
  ]

  defp chan_value("boolean"), do: true
  defp chan_value("integer"), do: 1
  defp chan_value(_), do: "x"

  defp chan_wrong("string"), do: 7
  defp chan_wrong(_), do: "x"

  defp chan_payload do
    leaf = fn {n, k} -> %{"name" => n, "type" => %{"kind" => k}} end

    nested = %{
      "name" => "inner_obj",
      "type" => %{"kind" => "typed_map", "fields" => Enum.map(@chan_fields, leaf)}
    }

    %{"type" => %{"kind" => "typed_map", "fields" => Enum.map(@chan_fields, leaf) ++ [nested]}}
  end

  defp chan_zod(formatter) do
    FieldName.with_formatter(formatter, fn ->
      {:ok, [c]} =
        AshSurface.Compiler.Section.Channel.build(%{
          "channels" => [
            %{"name" => "T", "events" => [%{"event" => "e", "payload" => chan_payload()}]}
          ]
        })

      hd(c.events).zod
    end)
  end

  for formatter <- @formatters do
    test "channel payload keys are emitted once in configured spelling under #{inspect(formatter)}" do
      f = unquote(Macro.escape(formatter))
      zod = chan_zod(f)
      spell = &FieldName.compute(&1, f)

      full = fn sp ->
        inner = Map.new(@chan_fields, fn {n, k} -> {sp.(n), chan_value(k)} end)
        Map.put(inner, sp.("inner_obj"), inner)
      end

      wire = full.(spell)
      internal = full.(& &1)
      inner_ok = Map.new(@chan_fields, fn {m, mk} -> {spell.(m), chan_value(mk)} end)

      cases =
        [%{expr: zod, payload: wire, want: "accept"}] ++
          if(wire != internal, do: [%{expr: zod, payload: internal, want: "reject"}], else: []) ++
          for({n, k} <- @chan_fields,
            do: %{expr: zod, payload: Map.put(wire, spell.(n), chan_wrong(k)), want: "reject"}) ++
          for {n, k} <- @chan_fields do
            bad = Map.put(inner_ok, spell.(n), chan_wrong(k))
            %{expr: zod, payload: Map.put(wire, spell.("inner_obj"), bad), want: "reject"}
          end

      got = node_run("export {};", Enum.map(cases, &Map.take(&1, [:expr, :payload])))
      assert Enum.zip(cases, got) |> Enum.reject(fn {c, g} -> c.want == g end) == []
      assert Enum.all?(@chan_fields, fn {n, _} -> String.contains?(zod, spell.(n)) end)
    end

    test "route arg keys follow the formatter once (path obj, query, body; template verbatim) under #{inspect(formatter)}" do
      f = unquote(Macro.escape(formatter))
      arg = fn {n, k}, extra -> Map.merge(%{"name" => n, "type" => %{"kind" => k}}, extra) end

      path_args =
        for {n, k} <- [{"url_id", "string"}, {"id2_x", "integer"}],
            do: arg.({n, k}, %{"allow_nil?" => false})

      rest = for {n, k} <- @chan_fields, n not in ["url_id", "id2_x"], do: arg.({n, k}, %{})

      FieldName.with_formatter(f, fn ->
        route = fn name, path, method ->
          {:ok, [r]} =
            RouteSchema.build([
              %{"name" => name, "path" => path, "method" => method,
                "arguments" => path_args ++ rest}
            ])

          r
        end

        g = route.("g", "/a/:url_id/:id2_x", "get")
        p = route.("p", "/b/:url_id/:id2_x", "post")

        sp = &FieldName.compute(&1, f)
        raw_path = %{"url_id" => "x", "id2_x" => "1"}
        raw_rest = %{"is_active?" => true, "éa_b" => "x", "__x" => "x"}
        fmt = fn m -> Map.new(m, fn {k, v} -> {sp.(k), v} end) end

        assert g["path"] == "/a/:url_id/:id2_x"
        assert g["path_params"] == ["url_id", "id2_x"]
        assert g["field_names"]["params"] == Map.new(Map.keys(raw_path), &{sp.(&1), &1})
        assert p["field_names"]["body"] == Map.new(Map.keys(raw_rest), &{sp.(&1), &1})
        assert g["field_names"]["query"] == Map.new(Map.keys(raw_rest), &{sp.(&1), &1})
        assert p["field_names"]["params"] == Map.new(Map.keys(raw_path), &{sp.(&1), &1})
        assert g["field_names"]["body"] == %{}
        assert p["field_names"]["query"] == %{}

        cases =
          [
            {g["params"], fmt.(raw_path), "accept"},
            {g["query"], fmt.(raw_rest), "accept"},
            {p["params"], fmt.(raw_path), "accept"},
            {p["body"], fmt.(raw_rest), "accept"}
          ] ++
            for({k, v} <- raw_rest, sp.(k) != k, do: {p["body"], %{k => v}, "reject"}) ++
            for({k, v} <- raw_path, sp.(k) != k, do: {p["params"], %{k => v}, "reject"}) ++
            [
              {p["body"], Map.put(fmt.(raw_rest), sp.("éa_b"), 7), "reject"},
              {p["body"], Map.put(fmt.(raw_rest), sp.("is_active?"), "x"), "reject"}
            ]

        got = node_run("export {};", Enum.map(cases, fn {e, pl, _} -> %{expr: e, payload: pl} end))
        assert Enum.zip(cases, got) |> Enum.reject(fn {{_, _, w}, g} -> w == g end) == []
        assert length(cases) >= 6
      end)
    end
  end

  test "route arg keys colliding after formatting are refused" do
    assert {:error, {:emitted_key_collision, {:route, "c"}, _, _}} =
             FieldName.with_formatter(:camel_case, fn ->
               RouteSchema.build([
                 %{"name" => "c", "path" => "/c", "method" => "post",
                   "arguments" => [
                     %{"name" => "a_b", "type" => %{"kind" => "string"}},
                     %{"name" => "aB", "type" => %{"kind" => "string"}}
                   ]}
               ])
             end)
  end
end
