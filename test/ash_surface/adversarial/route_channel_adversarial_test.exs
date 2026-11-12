Code.require_file("support.exs", __DIR__)

defmodule AshSurface.Adversarial.RouteChannelTest do
  @moduledoc """
  Lane S2b courts: hostile route-argument / path-param / channel-event / payload-field
  names through RouteSchema, Section.Channel and ChannelDiscovery.verify. 200 seeded
  cases per renderer; every rendered expression is admitted by ZodGuard and executed
  under real zod in node with accept/reject + prototype-pollution checks.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Adversarial.S2
  alias AshSurface.Compiler.{ChannelDiscovery, RouteSchema}
  alias AshSurface.Compiler.Section.Channel
  alias AshSurface.Projectors.JS.ZodGuard

  @extra ["*glob", "page[size]", "user-id", "", String.duplicate("q", 300), "9lead", "prototype"]
  @cases 200

  # INDEPENDENT oracle (does not call AshSurface.FieldName). Reference rule, ash_typescript
  # @5d6e80ae: Helpers.format_output_field/1 (helpers.ex:73) -> FieldFormatter.compute_field_name
  # :camel_case (field_formatter.ex:293-305) -> Helpers.snake_to_camel_case/1 (helpers.ex:25-30)
  # = lowercase-first(Macro.camelize(name)); so `p_1` -> "P1" -> `p1` (underscore before a digit
  # is dropped). Route path/query/body keys go through format_output_field (route_renderer.ex:147,
  # 155; request_handler.ex:324); the URL template keeps `:p_1` verbatim. Documented lib
  # deviation (KD-13): leading `_` preserved. RBS: trailing `?` is kept like the reference.
  defp ref_emit(name) do
    rest = String.trim_leading(name, "_")
    lead = String.duplicate("_", byte_size(name) - byte_size(rest))

    case Macro.camelize(rest) do
      <<f::utf8, r::binary>> -> lead <> String.downcase(<<f::utf8>>) <> r
      "" -> lead
    end
  end

  # Names outside the reference's domain (hostile bytes) are emitted verbatim by both when they
  # carry no `_`/`?`; others are dropped from the random pool for this court.
  defp oracle_domain?(_n), do: true

  defp pool, do: S2.nasty() ++ @extra

  defp pick_names(k, allow_proto?) do
    base = pool() ++ for(_ <- 1..6, do: S2.rand_name())
    base = if allow_proto?, do: base, else: Enum.reject(base, &(&1 == "__proto__"))
    base |> Enum.reject(&(&1 == "")) |> Enum.uniq() |> Enum.shuffle() |> Enum.take(k)
  end

  defp str(n), do: %{"name" => n, "type" => %{"kind" => "string"}, "allow_nil?" => false}

  # Executes {id, expr, names} under real zod: valid payload accepted with own keys ==
  # names, wrong-typed payload rejected, no prototype pollution.
  defp run_node(items) do
    dir =
      Path.join(
        System.tmp_dir!(),
        "s2b_#{System.unique_integer([:positive])}_#{System.pid()}_#{Base.url_encode64(:crypto.strong_rand_bytes(6), padding: false)}"
      )

    File.mkdir_p!(dir)
    File.ln_s!(Path.join(File.cwd!(), "node_modules"), Path.join(dir, "node_modules"))

    spec =
      items
      |> Enum.map(fn {_id, expr, names} -> %{expr: expr, names: names} end)

    body =
      spec
      |> Enum.with_index()
      |> Enum.map_join("\n", fn {%{expr: expr}, i} ->
        """
        try {
          const S = #{expr};
          const names = spec[#{i}].names;
          const good = JSON.parse(spec[#{i}].good);
          const bad = JSON.parse(spec[#{i}].bad);
          const r = S.safeParse(good);
          out[#{i}] = {ok: r.success,
            keys: r.success ? Object.keys(r.data).sort() : null,
            badRejected: !S.safeParse(bad).success,
            extraRejected: !S.safeParse(Object.assign(JSON.parse(spec[#{i}].good), {zz_extra_key: "x"})).success};
        } catch (e) { out[#{i}] = {throw: String(e && e.message || e)}; }
        """
      end)

    enriched =
      Enum.map(spec, fn %{names: names} = s ->
        good = Map.new(names, &{&1, "x"})
        bad = if names == [], do: %{"zz" => 1}, else: %{hd(names) => 1}

        %{s | names: names}
        |> Map.put(:good, Jason.encode!(good))
        |> Map.put(:bad, Jason.encode!(bad))
      end)

    File.write!(Path.join(dir, "run.mjs"), """
    import { z } from "zod";
    const spec = #{Jason.encode!(enriched)};
    const out = [];
    #{body}
    out.push({polluted: ({}).polluted !== undefined || Object.prototype.hasOwnProperty.call(Object.prototype, "zz_extra_key")});
    process.stdout.write(JSON.stringify(out));
    """)

    {raw, 0} = System.cmd(S2.node!(), ["run.mjs"], cd: dir, stderr_to_stdout: true)
    File.rm_rf!(dir)
    Jason.decode!(raw)
  end

  defp verify!(label, items) do
    {admitted, refused} =
      Enum.split_with(items, fn {_id, expr, _n} -> match?({:ok, _, _}, ZodGuard.admit(expr)) end)

    assert refused == [],
           "#{label}: ZodGuard refused #{length(refused)} rendered expressions, e.g. " <>
             inspect(
               Enum.take(refused, 2)
               |> Enum.map(fn {id, e, _} -> {id, e, ZodGuard.admit(e)} end),
               limit: :infinity,
               printable_limit: 400
             )

    out = run_node(admitted)
    {results, [%{"polluted" => polluted}]} = Enum.split(out, length(admitted))
    refute polluted, "#{label}: prototype polluted"

    bad =
      admitted
      |> Enum.zip(results)
      |> Enum.reject(fn {{_id, _e, names}, r} ->
        r["ok"] == true and r["keys"] == Enum.sort(names) and r["badRejected"] == true and
          r["extraRejected"] == true
      end)

    assert bad == [],
           "#{label}: #{length(bad)} wrong-behaviour cases, e.g. #{inspect(Enum.take(bad, 2), limit: :infinity)}"

    length(admitted)
  end

  describe "RouteSchema" do
    for seed <- [201] do
      test "seed=#{seed}: #{@cases} hostile-name routes: typed error or guarded+executed" do
        :rand.seed(:exsss, {unquote(seed), unquote(seed), unquote(seed)})

        {items, errors} =
          Enum.reduce(1..@cases, {[], 0}, fn i, {acc, errs} ->
            k = :rand.uniform(3)
            names = pick_names(k, false)
            method = Enum.random(["get", "post", "put", "delete"])
            pp = Enum.random(["id", "9x", "p_1", "constructor", "prototype", "rest"])
            glob? = :rand.uniform(4) == 1
            path = if glob?, do: "/r/#{i}/*#{pp}", else: "/r/#{i}/:#{pp}"
            names = Enum.reject(names, &(&1 == pp or not oracle_domain?(&1)))
            # client-facing schema keys are emitted (formatted) names, not declared ones
            # (reference: ash_typescript route_renderer.ex format_output_field)
            emit = fn ns -> Enum.map(ns, &ref_emit/1) end

            route = %{
              "name" => "r#{i}",
              "method" => method,
              "path" => path,
              "arguments" => [str(pp) | Enum.map(names, &str/1)],
              "returns" => %{"type" => %{"kind" => "string"}}
            }

            case RouteSchema.build([route]) do
              {:error, e} ->
                assert is_tuple(e) or is_atom(e)
                {acc, errs + 1}

              {:ok, [b]} ->
                rest = if method in ["get", "head"], do: "query", else: "body"

                {[
                   {{i, "params"}, b["params"], emit.([pp])},
                   {{i, rest}, b[rest], emit.(names)}
                 ] ++ acc, errs}
            end
          end)

        # query values of GET are all optional (nullable): valid payload still carries all names
        _ = errors
        assert items != [], "every case refused; court vacuous"
        n = verify!("RouteSchema seed=#{unquote(seed)}", items)
        assert n > 0
      end
    end

    test "literal reference table: declared name -> client key (ash_typescript @5d6e80ae)" do
      table = [
        {"p_1", "p1"},
        {"user_id", "userId"},
        {"line_1", "line1"},
        {"a_b_2c", "aB2c"},
        {"id", "id"},
        {"is_ready?", "isReady?"},
        {"_p", "_p"}
      ]

      for {declared, client} <- table do
        {:ok, [b]} =
          RouteSchema.build([
            %{"name" => "t", "method" => "post", "path" => "/t", "arguments" => [str(declared)]}
          ])

        assert b["body"] =~ "#{client}:" or b["body"] =~ ~s("#{client}":), "#{declared}: expected key #{client} in #{b["body"]}"
        assert ref_emit(declared) == client
      end

      {:ok, [b]} =
        RouteSchema.build([
          %{"name" => "t", "method" => "get", "path" => "/t/:p_1", "arguments" => [str("p_1")]}
        ])

      assert b["params"] =~ "p1:"
      assert b["path"] == "/t/:p_1"
    end

    test "empty / duplicate / non-binary argument names are typed errors" do
      r = fn args -> %{"name" => "x", "method" => "post", "path" => "/x", "arguments" => args} end

      assert {:error, {:denied_argument_name, "x", "__proto__"}} =
               RouteSchema.build([r.([str("__proto__")])])

      assert {:error, {:duplicate_argument, "x", "a"}} =
               RouteSchema.build([r.([str("a"), str("a")])])

      assert {:error, {:argument_without_name, "x", ""}} = RouteSchema.build([r.([str("")])])

      assert {:error, {:argument_without_name, "x", nil}} =
               RouteSchema.build([r.([%{"type" => %{"kind" => "string"}}])])
    end

    test "path_params over hostile paths" do
      assert RouteSchema.path_params("/a/:page[size]") == ["page"]
      assert RouteSchema.path_params("/a/*glob/b/:user-id") == ["glob", "user"]
      assert RouteSchema.path_params("/a/:\u2028x") == []
      assert RouteSchema.path_params("/a/:__proto__") == ["__proto__"]
    end
  end

  describe "Section.Channel payload fields" do
    for seed <- [211] do
      test "seed=#{seed}: #{@cases} hostile payload field names: typed error or guarded+executed" do
        :rand.seed(:exsss, {unquote(seed), unquote(seed), unquote(seed)})

        items =
          Enum.flat_map(1..@cases, fn i ->
            # __proto__ as an embedded field name is DEFECT S2-01 (EmbeddedSchema, other lane)
            names = pick_names(:rand.uniform(3), false)
            ev = Enum.random(pool())

            discovery = %{
              "channels" => [
                %{
                  "name" => "c#{i}",
                  "topic" => ev,
                  "events" => [
                    %{
                      "event" => ev <> "#{i}",
                      "returns_kind" => "typed_map",
                      "payload" => %{
                        "type" => %{
                          "kind" => "typed_map",
                          "fields" => Enum.map(names, &Map.put(str(&1), "wire", true))
                        }
                      }
                    }
                  ]
                }
              ]
            }

            case Channel.build(discovery) do
              {:error, e} ->
                assert is_tuple(e) or is_atom(e)
                []

              {:ok, [c]} ->
                [e] = c.events
                assert e.event == ev <> "#{i}"
                assert e.payload_name =~ ~r/\A[A-Za-z_][A-Za-z0-9_]*\z/
                [{{i, e.event}, e.zod, names}]
            end
          end)

        assert items != [], "every case refused; court vacuous"
        verify!("Channel seed=#{unquote(seed)}", items)
      end
    end

    test "hostile event names: payload names are identifiers, duplicates refused" do
      for n <- pool() do
        d = fn evs ->
          %{"channels" => [%{"name" => n, "events" => Enum.map(evs, &%{"event" => &1})}]}
        end

        assert {:ok, [c]} = Channel.build(d.([n <> "a", n <> "b"]))
        assert Enum.all?(c.events, &(&1.payload_name =~ ~r/\A[A-Za-z_][A-Za-z0-9_]*\z/))
        assert {:error, {:duplicate_event, ^n, "dup"}} = Channel.build(d.(["dup", "dup"]))
      end
    end
  end

  describe "ChannelDiscovery.verify" do
    for seed <- [221] do
      test "seed=#{seed}: #{@cases} hostile channel/event names are ok or typed, never raise" do
        :rand.seed(:exsss, {unquote(seed), unquote(seed), unquote(seed)})

        for i <- 1..@cases do
          [a, b] = (pick_names(2, true) ++ [""]) |> Enum.take(2)

          evs =
            Enum.map(
              [a, b, a],
              &%{"event" => &1, "returns_kind" => Enum.random([nil, "map", "string"])}
            )

          res = ChannelDiscovery.verify(%{"channels" => [%{"name" => "c#{i}", "events" => evs}]})
          assert match?({:error, {:duplicate_event, _, _}}, res), inspect(res)
        end
      end
    end

    test "verify typed errors; discover([]) is ok" do
      assert {:error, {:invalid_discovery, 1}} = ChannelDiscovery.verify(1)
      assert {:ok, %{"channels" => []}} = ChannelDiscovery.discover([])
    end
  end
end
