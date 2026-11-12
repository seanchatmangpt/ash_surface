defmodule AshSurface.Compiler.IdentitySchemaTest do
  use ExUnit.Case, async: false

  alias AshSurface.Compiler.IdentitySchema
  alias AshSurface.Projectors.JS.ZodGuard
  alias AshSurface.ZodFixtures.Harness

  defp key(name, kind, extra \\ %{}),
    do: Map.merge(%{"name" => name, "type" => %{"kind" => kind}}, extra)

  defp ident(name, keys), do: %{"name" => name, "keys" => keys}

  defp identities do
    [
      ident("email", [key("email", "string")]),
      ident("by_id", [key("id", "uuid")]),
      ident("org_slug", [key("org", "string"), key("slug", "string", %{"allow_nil?" => true})])
    ]
  end

  test "primary_key aliasing and per-identity names" do
    {:ok, m} = IdentitySchema.render_get_schema(identities(), ["id"])
    assert Enum.sort(Map.keys(m)) == ["email", "org_slug", "primary_key"]
  end

  test "composite primary key aliasing is order-insensitive" do
    ids = [ident("pk", [key("b", "string"), key("a", "integer")])]
    assert {:ok, %{"primary_key" => _}} = IdentitySchema.render_get_schema(ids, ["a", "b"])
  end

  test "refusals" do
    assert {:error, :no_admitted_identities} = IdentitySchema.render_get_schema([], ["id"])
    assert {:error, :no_admitted_identities} = IdentitySchema.render_get_schema(:x, ["id"])

    assert {:error, :no_admitted_identities} =
             IdentitySchema.render_get_schema([ident("e", [])], [])

    assert {:error, :no_admitted_identities} =
             IdentitySchema.render_get_schema([%{"name" => 1}], [])

    # scalar-only guard: structured key kinds are not lookup values
    assert {:error, :no_admitted_identities} =
             IdentitySchema.render_get_schema([ident("m", [key("m", "map")])], [])
  end

  test "tenant required / optional / absent" do
    # Re-pinned (F1-errcfg): unset require_tenant_parameters follows Config (false,
    # ash_typescript rpc.ex:301), so a tenant-bearing resource is optional by default.
    assert {:ok, "z.string().min(1)"} = IdentitySchema.render_tenant_schema()

    assert {:ok, "z.string().min(1).optional()"} =
             IdentitySchema.render_tenant_schema(%{"strategy" => "attribute"})

    assert {:ok, "z.string().min(1)"} =
             IdentitySchema.render_tenant_schema(%{strategy: :context, global?: false}, true)

    assert {:ok, "z.string().min(1)"} =
             IdentitySchema.render_tenant_schema(%{
               "strategy" => "attribute",
               "require_tenant_parameters" => true
             })

    assert {:ok, "z.string().min(1).optional()"} =
             IdentitySchema.render_tenant_schema(%{
               "strategy" => "attribute",
               "require_tenant_parameters" => false
             })

    assert {:ok, nil} =
             IdentitySchema.render_tenant_schema(%{"strategy" => "attribute", "global?" => true})

    assert {:ok, nil} = IdentitySchema.render_tenant_schema(%{"strategy" => nil})
    assert {:ok, nil} = IdentitySchema.render_tenant_schema(nil)
  end

  test "deterministic, key-ordered, no optional on keys, ZodGuard-admitted" do
    {:ok, a} = IdentitySchema.render_get_schema(identities(), ["id"])
    {:ok, b} = IdentitySchema.render_get_schema(Enum.reverse(identities()), ["id"])
    assert a == b

    assert a["org_slug"] =~ ~r/org: .*slug: /
    refute a["org_slug"] =~ ".optional()"
    assert a["org_slug"] =~ ".nullable()"
    assert a["email"] =~ ".strict()"

    for zod <- Map.values(a) ++ ["z.string().min(1)", "z.string().min(1).optional()"] do
      assert {:ok, :expression, _} = ZodGuard.admit(zod)
    end
  end

  test "strict rejection and required tenant executed under node with real zod" do
    {:ok, m} = IdentitySchema.render_get_schema(identities(), ["id"])
    {:ok, tenant} = IdentitySchema.render_tenant_schema(%{"strategy" => "attribute"}, true)
    zod_dir = Harness.zod!()
    node = Harness.tool!("node")
    dir = Path.join(System.tmp_dir!(), "identity_schema_#{AshSurface.TestTmp.suffix()}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    File.ln_s!(Path.dirname(zod_dir), Path.join(dir, "node_modules"))

    script = """
    import { z } from "zod";
    const email = #{m["email"]};
    const pk = #{m["primary_key"]};
    const org = #{m["org_slug"]};
    const tenant = #{tenant};
    const ok = (s, v) => s.safeParse(v).success;
    console.log(JSON.stringify({
      emailOk: ok(email, { email: "a@b.c" }),
      emailExtra: ok(email, { email: "a@b.c", x: 1 }),
      emailWrong: ok(email, { other: "a" }),
      emailNum: ok(email, { email: 1 }),
      pkOk: ok(pk, { id: "123e4567-e89b-42d3-a456-426614174000" }),
      pkBad: ok(pk, { id: "nope" }),
      orgNull: ok(org, { org: "o", slug: null }),
      orgMissing: ok(org, { org: "o" }),
      tenantOk: ok(tenant, "t1"),
      tenantEmpty: ok(tenant, ""),
      tenantMissing: ok(tenant, undefined),
    }));
    """

    File.write!(Path.join(dir, "run.mjs"), script)
    {out, status} = Harness.run(node, ["run.mjs"], dir)
    assert status == 0, out
    r = out |> String.trim() |> String.split("\n") |> List.last() |> Jason.decode!()

    assert r == %{
             "emailOk" => true,
             "emailExtra" => false,
             "emailWrong" => false,
             "emailNum" => false,
             "pkOk" => true,
             "pkBad" => false,
             "orgNull" => true,
             "orgMissing" => false,
             "tenantOk" => true,
             "tenantEmpty" => false,
             "tenantMissing" => false
           }
  end
end
