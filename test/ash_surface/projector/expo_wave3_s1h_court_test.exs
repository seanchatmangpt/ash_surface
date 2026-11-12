defmodule AshSurface.Projector.ExpoWave3S1hCourtTest do
  @moduledoc """
  Wave-3 S1-H courts (M9/M10/M11), executed under Node with real zod.
  """
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.RouteSchema
  alias AshSurface.Projector.Expo
  alias AshSurface.ZodFixtures.Harness

  defp node_run!(files, main_js) do
    dir = Path.join(System.tmp_dir!(), "s1h_#{AshSurface.TestTmp.suffix()}")
    File.mkdir_p!(dir)
    File.ln_s!(Path.join(Harness.repo_root(), "node_modules"), Path.join(dir, "node_modules"))
    Harness.zod!()
    Enum.each(files, fn {n, c} -> File.write!(Path.join(dir, n), c) end)
    File.write!(Path.join(dir, "run.mjs"), main_js)
    {out, 0} = Harness.run(Harness.tool!("node"), ["run.mjs"], dir)
    File.rm_rf!(dir)
    Jason.decode!(out)
  end

  defp surface(actions, resources) do
    AshSurface.TestSupport.VerifiedSurface.seal(%AshSurface.Surface{
      manifest: nil,
      contract: %{
        "surface" => %{"actions" => actions},
        "manifest" => %{"resources" => resources}
      },
      digest: "digest-test",
      action_ids: Enum.map(actions, & &1["id"])
    })
  end

  defp project(actions, resources),
    do: AshSurface.project(surface(actions, resources), Expo, prefix: "p")

  defp fld(kind, extra \\ %{}), do: Map.merge(%{"type" => %{"kind" => kind}}, extra)

  test "M9: create input excludes non-writable fields, honours defaults, requires the rest" do
    resources = %{
      "r" => %{
        "name" => "R",
        "fields" => %{
          "id" => fld("uuid", %{"writable" => false, "has_default" => true}),
          "inserted_at" => fld("utc_datetime", %{"writable" => false}),
          "secret" => fld("string", %{"private?" => true}),
          "calc" => fld("string", %{"kind" => "calculation"}),
          "title" => fld("string"),
          "n" => fld("integer", %{"has_default" => true})
        }
      }
    }

    assert {:ok, art, _} = project([%{"id" => "r.create", "resource" => "R"}], resources)

    [ok?, extra] =
      node_run!(
        %{"s.mjs" => art["p.schemas.mjs"]},
        """
        import { SCHEMAS } from "./s.mjs";
        const s = SCHEMAS["r.create"].input;
        process.stdout.write(JSON.stringify([
          s.safeParse({ title: "x" }).success,
          [s.safeParse({}).success, s.safeParse({ title: 1 }).success]
        ]));
        """
      )

    assert ok? == true
    assert extra == [false, false]
    refute art["p.schemas.mjs"] =~ "inserted_at:"
    refute art["p.schemas.mjs"] =~ "secret:"
    refute art["p.schemas.mjs"] =~ "calc:"
  end

  test "M9: unknown resource is a typed error, not a passthrough accept-all" do
    assert {:error, {:unknown_resource, "a", "Missing"}} =
             project([%{"id" => "a", "resource" => "Missing"}], %{})
  end

  test "M10: colliding, digit-leading and hostile ids load as a clean module under node" do
    ids = ["orders.create", "orders_create", "1x", "\e", "__proto__", "a b"]
    actions = Enum.map(ids, &%{"id" => &1})
    assert {:ok, art, _} = project(actions, %{})

    result =
      node_run!(
        %{"s.mjs" => art["p.schemas.mjs"], "a.mjs" => art["p.actions.mjs"]},
        """
        import { SCHEMAS } from "./s.mjs";
        process.stdout.write(JSON.stringify({
          keys: Object.keys(SCHEMAS),
          protoOwn: Object.prototype.hasOwnProperty.call(SCHEMAS, "__proto__"),
          protoPolluted: Object.getPrototypeOf(SCHEMAS) !== Object.prototype
        }));
        """
      )

    assert Enum.sort(result["keys"]) == Enum.sort(ids)
    assert result["protoOwn"] == true
    assert result["protoPolluted"] == false
  end

  test "M10: nil id is a typed error; ACTIONS refuses a __proto__ key; output is deterministic" do
    assert {:error, {:action_without_id, %{"id" => nil}}} = project([%{"id" => nil}], %{})

    assert {:error, {:proto_key_refused, "ACTIONS"}} =
             project([%{"id" => "a", "extra" => %{"__proto__" => 1}}], %{})

    big = for i <- 1..60, into: %{}, do: {"k#{i}", i}
    {:ok, a1, _} = project([%{"id" => "a", "meta" => big}], %{})
    {:ok, a2, _} = project([%{"id" => "a", "meta" => big}], %{})
    assert a1 == a2
    [first | _] = Regex.run(~r/"k1":/, a1["p.actions.mjs"])
    assert first == "\"k1\":"

    assert :binary.match(a1["p.actions.mjs"], "\"k1\":") <
             :binary.match(a1["p.actions.mjs"], "\"k2\":")
  end

  describe "M11 route schema" do
    defp route(path, args, method \\ "get"),
      do: %{"name" => "r", "method" => method, "path" => path, "arguments" => args}

    defp arg(name, kind, extra \\ %{}),
      do: Map.merge(%{"name" => name, "type" => %{"kind" => kind}}, extra)

    test "hostile keys are quoted/computed and parse under node" do
      {:ok, [r]} =
        RouteSchema.build([
          route("/u/:user_id", [
            arg("user_id", "string", %{"allow_nil?" => false}),
            arg("page[size]", "integer"),
            arg("user-id", "string")
          ])
        ])

      # "__proto__" is a typed refusal (S2b-b), not a quoted key.
      assert {:error, {:denied_argument_name, "r", "__proto__"}} =
               RouteSchema.build([route("/x", [arg("__proto__", "string")])])

      [q] =
        node_run!(
          %{},
          """
          import { z } from "zod";
          const q = #{r["query"]};
          process.stdout.write(JSON.stringify([[
            q.safeParse(JSON.parse('{"page[size]":"5","user-id":"u"}')).success,
            q.safeParse(JSON.parse('{"page[size]":"x"}')).success,
            Object.keys(q.shape).sort()
          ]]));
          """
        )

      assert q == [true, false, ["page[size]", "user-id"]]
    end

    test "nil name and duplicate names are refused" do
      assert {:error, {:argument_without_name, "r", nil}} =
               RouteSchema.build([route("/x", [%{"type" => %{"kind" => "string"}}])])

      assert {:error, {:duplicate_argument, "r", "a"}} =
               RouteSchema.build([route("/x", [arg("a", "string"), arg("a", "integer")])])
    end

    test "glob params are extracted" do
      assert RouteSchema.path_params("/files/*path") == ["path"]
      assert RouteSchema.path_params("/a/:id/f/*rest") == ["id", "rest"]
      assert RouteSchema.path_params("/a/:id") == ["id"]

      assert {:error, {:path_param_missing_arg, "r", "path"}} =
               RouteSchema.build([route("/files/*path", [])])
    end

    test "integer path/query args accept numeric strings (executed), reject junk and blanks" do
      {:ok, [r]} =
        RouteSchema.build([
          route("/u/:id", [
            arg("id", "integer", %{"allow_nil?" => false}),
            arg("page", "integer")
          ])
        ])

      [p, q] =
        node_run!(
          %{},
          """
          import { z } from "zod";
          const p = #{r["params"]};
          const q = #{r["query"]};
          process.stdout.write(JSON.stringify([
            [p.safeParse({ id: "42" }).success, p.safeParse({ id: 42 }).success,
             p.safeParse({ id: "abc" }).success, p.safeParse({ id: "" }).success,
             p.safeParse({ id: "1.5" }).success],
            [q.safeParse({ page: "3" }).success, q.safeParse({}).success,
             q.safeParse({ page: null }).success, q.safeParse({ page: "" }).success]
          ]));
          """
        )

      assert p == [true, true, false, false, false]
      assert q == [true, true, true, false]
    end
  end
end
