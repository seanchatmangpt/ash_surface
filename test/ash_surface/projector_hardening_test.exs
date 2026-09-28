defmodule AshSurface.ProjectorHardeningTest do
  @moduledoc """
  Chicago state tests pinning projector hardening over compiler-produced and
  adversarial IR.

  Laws pinned here:

    * **Compiled IR projects end-to-end.** A real domain holding an
      `AshR2RML`-mapped resource, an `AshA2A` resource and a plain resource
      (neither extension) compiles with `AshSurface.Compiler.compile/1`, and
      every IR projector — LiveView, JS, ARIA, and `Projector.IR` dispatch —
      returns a result over that exact IR instead of raising. Nil sections
      (`semantic: nil`, `capability: nil`, `presentation: nil`) read as
      UNKNOWN facts; the compiler's list-form `predicates` declares no
      relationships.
    * **JS names are admitted, never trusted.** The JS projector refuses a
      short-name namespace collision, a namespace that is not a safe binding
      (reserved word, ECMAScript global, artifact-declared binding,
      non-identifier), an unsafe member, duplicate ids and top-level binding
      collisions — typed `{:error, _}`, no artifact.
    * **Comment text cannot break out.** `*/` in interpolated comment text is
      neutralized.
    * **Zod text is admitted by grammar.** `IR.Schema.zod` is embedded as
      code, so strings outside `AshSurface.Projectors.JS.ZodGuard`'s grammar
      (including ones arriving through `IR.Codec.from_map/1`) are refused;
      the compiler's own zod program form is admitted and its input schema
      embedded.

  Every generated artifact is checked with `node --check`; the compiled-IR
  artifact is imported and executed by Node against the real `zod` package.
  Delegation subjects are real inline Ash resources registering the real
  extensions (TESTING.md section 3); no fakes of either extension.
  """

  use ExUnit.Case, async: true

  alias AshSurface.IR
  alias AshSurface.Projector.IR, as: ProjectorIR
  alias AshSurface.Projector.VoiceKiosk
  alias AshSurface.Projectors.{ARIA, JS, LiveView}
  alias AshSurface.Projectors.JS.ZodGuard

  defmodule HardenDomain do
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource(AshSurface.ProjectorHardeningTest.Shelf)
      resource(AshSurface.ProjectorHardeningTest.Crate)
      resource(AshSurface.ProjectorHardeningTest.Note)
    end
  end

  defmodule Shelf do
    @moduledoc "Mapped subject: real Ets resource with the AshR2RML extension."

    use Ash.Resource,
      domain: AshSurface.ProjectorHardeningTest.HardenDomain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshR2RML.Resource]

    r2rml do
      table_name("shelves")
      class("https://vocab.example/Shelf")

      subject do
        template("https://data.example/shelves/{id}")
      end

      property(:label, "https://vocab.example/label")
      graph("https://vocab.example/graph")
    end

    attributes do
      uuid_primary_key(:id)
      attribute(:label, :string, public?: true)
    end

    actions do
      defaults([:read])
    end
  end

  defmodule Crate do
    @moduledoc "Registered subject: real Ets resource with the AshA2A extension."

    use Ash.Resource,
      domain: AshSurface.ProjectorHardeningTest.HardenDomain,
      data_layer: Ash.DataLayer.Ets,
      extensions: [AshA2A]

    attributes do
      uuid_primary_key(:id)
      attribute(:sku, :string, public?: true, allow_nil?: false)
    end

    actions do
      defaults([:read, create: [:sku]])
    end
  end

  defmodule Note do
    @moduledoc "Plain subject: neither AshR2RML nor AshA2A."

    use Ash.Resource,
      domain: AshSurface.ProjectorHardeningTest.HardenDomain,
      data_layer: Ash.DataLayer.Ets

    attributes do
      uuid_primary_key(:id)
      attribute(:body, :string, public?: true)
    end

    actions do
      defaults([:read, :destroy])
    end
  end

  @shelf "AshSurface.ProjectorHardeningTest.Shelf"
  @crate "AshSurface.ProjectorHardeningTest.Crate"
  @note "AshSurface.ProjectorHardeningTest.Note"

  @compiled_ids ~w(Crate.create Crate.read Note.destroy Note.read Shelf.read)

  @scratch Path.join(Mix.Project.build_path(), "projector_hardening")

  setup_all do
    {:ok, irs} = AshSurface.Compiler.compile(HardenDomain)
    %{irs: irs}
  end

  ## A. Compiled IR through every projector

  describe "compiled IR carries honest nil and list-form sections" do
    test "the subjects compile to the section shapes the projectors must accept", %{irs: irs} do
      by_id = Map.new(irs, &{{&1.ash.resource, &1.ash.action}, &1})

      shelf = by_id[{Shelf, :read}]
      assert shelf.semantic.predicates == ["https://vocab.example/label"]
      assert shelf.semantic.ontology == ["https://vocab.example/graph"]
      assert shelf.capability == nil

      assert by_id[{Crate, :create}].semantic == nil
      assert by_id[{Crate, :create}].capability.consequence_class != nil

      note = by_id[{Note, :destroy}]
      assert {note.semantic, note.capability} == {nil, nil}
    end

    test "IR.Semantic's type admits the compiled list shapes it carries" do
      {:ok, types} = Code.Typespec.fetch_types(IR.Semantic)
      [{:type, {:t, spec, []}}] = Enum.filter(types, &match?({:type, {:t, _, _}}, &1))
      rendered = spec |> then(&Code.Typespec.type_to_quoted({:t, &1, []})) |> Macro.to_string()

      assert rendered =~ "predicates: [String.t()] |"
      assert rendered =~ "ontology: [String.t()] | String.t() | nil"
    end
  end

  describe "LiveView over compiled IR" do
    test "projects the mapped, registered and plain resources without raising", %{irs: irs} do
      assert {:ok, view, meta} = LiveView.project_ir(irs, [])

      assert meta == %{
               "projector" => "AshSurface.Projectors.LiveView",
               "resource_count" => 3,
               "group_count" => 1,
               "action_count" => 5
             }

      assert view["kind"] == "ash_admin"
      assert view["resources"] |> Map.keys() |> Enum.sort() == Enum.sort([@shelf, @crate, @note])

      # List-form predicates (flat IRIs) declare no relationships.
      assert view["resources"][@shelf]["relationships"] == []
      assert view["resources"][@shelf]["table"]["surface_action_id"] == "#{@shelf}#read"

      # A plain resource: nil capability reads as UNKNOWN, never a crash.
      note_controls = view["resources"][@note]["actions"]

      assert Enum.map(note_controls, &{&1["action"], &1["consequence_class"]}) ==
               [{"destroy", nil}, {"read", nil}]

      assert Enum.all?(note_controls, &(&1["authority_required"] == false))
      assert Enum.all?(note_controls, &(&1["receipt_required"] == false))

      # The AshA2A resource carries its delegated consequence classes.
      crate_classes =
        view["resources"][@crate]["actions"] |> Map.new(&{&1["action"], &1["consequence_class"]})

      assert crate_classes["read"] != nil
      assert crate_classes["create"] != nil

      assert [%{"group" => "Resources", "resources" => nav}] = view["navigation"]["groups"]
      assert length(nav) == 3
    end

    test "is byte-stable under permutation of compiled IR", %{irs: irs} do
      assert LiveView.project_ir(irs, []) == LiveView.project_ir(Enum.reverse(irs), [])
    end

    test "projects compiled IR round-tripped through IR.Codec", %{irs: irs} do
      decoded =
        Enum.map(irs, fn ir ->
          {:ok, back} = ir |> IR.Codec.to_map() |> IR.Codec.from_map()
          back
        end)

      assert {:ok, view, %{"action_count" => 5}} = LiveView.project_ir(decoded, [])
      assert view["resources"][@shelf]["relationships"] == []
    end

    test "every section but ash may be nil" do
      bare = %IR{
        version: "v1",
        ash: %IR.Ash{resource: "Shop.Widget", action: :create, action_type: :create}
      }

      assert {:ok, view, _meta} = LiveView.project_ir(bare, [])
      block = view["resources"]["Shop.Widget"]

      assert block["label"] == "Shop.Widget"
      assert block["group"] == "Resources"
      assert block["relationships"] == []

      assert [%{"fields" => [], "format" => nil, "label" => nil}] = block["forms"]

      assert [
               %{
                 "consequence_class" => nil,
                 "authority_required" => false,
                 "receipt_required" => false
               }
             ] = block["actions"]
    end

    test "the authored map shape still declares relationships; the list shape declares none" do
      ir = fn predicates ->
        %IR{
          version: "v1",
          ash: %IR.Ash{resource: "Shop.Order", action: :read, action_type: :read},
          semantic: %IR.Semantic{predicates: predicates}
        }
      end

      map_form = %{"relationships" => [%{"name" => "lines", "destination" => "Shop.Line"}]}

      assert {:ok, view, _} = LiveView.project_ir(ir.(map_form), [])

      assert [%{"name" => "lines", "destination" => "Shop.Line", "cardinality" => "many"}] =
               view["resources"]["Shop.Order"]["relationships"]

      assert {:ok, view, _} = LiveView.project_ir(ir.(["https://vocab.example/lines"]), [])
      assert view["resources"]["Shop.Order"]["relationships"] == []
    end
  end

  describe "the other projectors over the same compiled IR" do
    test "JS emits an artifact Node checks, imports and executes", %{irs: irs} do
      assert {:ok, %{"ash_surface_client.mjs" => code}, meta} = JS.project_ir(irs)
      assert meta.action_count == 5
      assert meta.namespace_count == 3

      # The compiled zod PROGRAM is not embedded as an expression; its input
      # schema is.
      refute code =~ "= export const"

      assert code =~
               "/** Zod boundary schema for `Crate.create` (input schema of the compiled IR.Schema.zod program). */\n" <>
                 "export const Crate_create_schema = z.object({\n\n}).passthrough();"

      path = write_artifact!("compiled_client.mjs", code)
      assert {_, 0} = node_check(path)

      script = """
      const m = await import(#{Jason.encode!(path)});
      const ids = m.ACTIONS.map((a) => a.id);
      const parsed = m.SCHEMAS["Crate.create"].parse({ sku: "A-1" });
      console.log(JSON.stringify({ ids, parsed, namespaces: Object.keys(m.NAMESPACES) }));
      """

      {out, 0} = System.cmd("node", ["--input-type=module", "-e", script], cd: File.cwd!())

      assert Jason.decode!(out) == %{
               "ids" => @compiled_ids,
               "parsed" => %{"sku" => "A-1"},
               "namespaces" => ["Crate", "Note", "Shelf"]
             }
    end

    test "ARIA projects one surface per compiled action", %{irs: irs} do
      assert {:ok, contract, %{surface_count: 5}} = ARIA.project_ir(irs)
      assert Enum.map(contract["surfaces"], & &1["id"]) == @compiled_ids
    end

    test "Projector.IR dispatch returns results, never raises", %{irs: irs} do
      assert {:ok, _view, %{"action_count" => 5}} = ProjectorIR.project(LiveView, irs, [])
      assert {:ok, %{"ash_surface_client.mjs" => _}, _} = ProjectorIR.project(JS, irs, [])
      assert {:ok, _contract, %{surface_count: 5}} = ProjectorIR.project(ARIA, irs, [])

      # VoiceKiosk's own project_ir/2 takes a verified Surface; it is a
      # legacy projector and is refused typed rather than crashed into.
      assert ProjectorIR.project(VoiceKiosk, irs, []) ==
               {:error, {:unknown_projector_kind, VoiceKiosk}}

      assert ProjectorIR.project(AshSurface.Projector.Expo, irs, []) ==
               {:error, {:unknown_projector_kind, AshSurface.Projector.Expo}}

      # Wrapped legacy projectors refuse non-surface IR typed.
      {:ok, adapter} = ProjectorIR.from_manifest_projector(VoiceKiosk)
      assert {:error, {:missing_surface_ir, 5}} = ProjectorIR.project(adapter, irs, [])
    end
  end

  ## B. JS name and code admission

  describe "JS namespace admission" do
    test "refuses two resources that share a short name" do
      irs = [js_ir("MyApp.Blog.Post", :create), js_ir("MyApp.Forum.Post", :create)]

      assert JS.project_ir(irs) ==
               {:error,
                {:js_namespace_collision, "Post", ["MyApp.Blog.Post", "MyApp.Forum.Post"]}}
    end

    test "refuses the collision for atom-named resources too" do
      irs = [js_ir(MyApp.Blog.Post, :read), js_ir(MyApp.Forum.Post, :create)]

      assert JS.project_ir(irs) ==
               {:error,
                {:js_namespace_collision, "Post", ["MyApp.Blog.Post", "MyApp.Forum.Post"]}}
    end

    test "refuses the same action id projected twice" do
      irs = [js_ir("MyApp.Blog.Post", :create), js_ir("MyApp.Blog.Post", :create)]
      assert JS.project_ir(irs) == {:error, {:duplicate_js_member, "Post.create"}}
    end

    test "refuses globals, reserved words, artifact bindings and non-identifiers" do
      for short <-
            ~w(Object Error Array Promise JSON undefined globalThis z ACTIONS SCHEMAS NAMESPACES getAction dispatchIntent class await let yield eval arguments) ++
              ["my-thing", "1st", "", "Post Office"] do
        ir = js_ir("MyApp." <> short, :read)

        assert JS.project_ir(ir) == {:error, {:unsafe_js_namespace, short}},
               "expected #{inspect(short)} to be refused"
      end
    end

    test "refuses unsafe members and admits reserved-word members as property keys" do
      assert JS.project_ir(js_ir("Shop.Cart", "add-item")) ==
               {:error, {:unsafe_js_member, "Cart.add-item"}}

      assert JS.project_ir(js_ir("Shop.Cart", "__proto__")) ==
               {:error, {:unsafe_js_member, "Cart.__proto__"}}

      assert {:ok, %{"ash_surface_client.mjs" => code}, _} =
               JS.project_ir([js_ir("Shop.Cart", :delete), js_ir("Shop.Cart", :new)])

      assert code =~ "  delete: Object.freeze({"
      assert {_, 0} = code |> then(&write_artifact!("reserved_members.mjs", &1)) |> node_check()
    end

    test "refuses top-level binding collisions between schema consts and namespaces" do
      zod = "z.object({})"

      assert JS.project_ir([js_ir("X.A_b", :c, zod: zod), js_ir("X.A", :b_c, zod: zod)]) ==
               {:error, {:js_binding_collision, "A_b_c_schema"}}

      assert JS.project_ir([
               js_ir("X.Todo", :create, zod: zod),
               js_ir("X.Todo_create_schema", :read)
             ]) ==
               {:error, {:js_binding_collision, "Todo_create_schema"}}
    end
  end

  describe "JS comment escaping" do
    test "*/ in a delegated fact cannot close the doc comment" do
      ir =
        js_ir("Shop.Cart", :read,
          policies: [%{"authorityBoundary" => "OBSERVE */ globalThis.pwned = 1; /*"}]
        )

      assert {:ok, %{"ash_surface_client.mjs" => code}, _} = JS.project_ir(ir)
      # Neither doc-comment site carries the raw terminator...
      refute code =~ ~S[(authorityBoundary: "OBSERVE */]
      refute code =~ ~S[— "OBSERVE */]
      assert code =~ ~S(OBSERVE *\/ globalThis.pwned = 1; /*)
      # The descriptor still carries the fact verbatim as a JSON string.
      assert code =~ ~S(authorityBoundary: "OBSERVE */ globalThis.pwned = 1; /*")

      path = write_artifact!("comment_escape.mjs", code)
      assert {_, 0} = node_check(path)

      script = """
      await import(#{Jason.encode!(path)});
      console.log(String(globalThis.pwned));
      """

      assert {"undefined\n", 0} =
               System.cmd("node", ["--input-type=module", "-e", script], cd: File.cwd!())
    end

    test "U+2028 in the prefix cannot end the header line comment" do
      assert {:ok, artifacts, _} = JS.project_ir([], prefix: "p\u2028globalThis.x=1")
      [code] = Map.values(artifacts)
      assert code =~ ~S(prefix "p\u2028globalThis.x=1")
    end
  end

  describe "JS zod admission" do
    @admitted [
      "z.object({\n  title: z.string().min(1),\n  due_on: z.string().optional()\n})",
      "z.object({\n  status: z.enum([\"open\", \"done\"]).optional()\n})",
      "z.record(z.string(), z.unknown())",
      "z.string().uuid().optional().nullable()",
      "z.number().int().min(-1.5e3).max(10,)",
      "z.object({\"quoted key\": z.boolean(), n: z.literal(null)}).passthrough()",
      "z.coerce.number()"
    ]

    @refused [
      "z.string(); globalThis.pwned = 1",
      "(() => { globalThis.pwned = 1 })()",
      "z.string().constructor.constructor(\"return 1\")()",
      "z.string().transform((v) => v)",
      "z.object({__proto__: z.string()})",
      "z.object({\"__pro\\u0074o__\": z.string()})",
      "z.string()[\"constructor\"]",
      "z.string().refine(eval)",
      "z.string() // trailing comment",
      "z.string().regex(/a/)",
      "z.string().default(`x`)",
      "z",
      "",
      "y.string()",
      "z.string().__defineGetter__(\"a\", z.string())"
    ]

    test "admits the compiler's fragments and authored zod expressions" do
      for zod <- @admitted do
        assert ZodGuard.admit(zod) == {:ok, :expression, zod}, inspect(zod)
      end
    end

    test "refuses text outside the grammar, and the projector refuses it typed" do
      for zod <- @refused do
        assert {:error, reason} = ZodGuard.admit(zod), inspect(zod)

        assert JS.project_ir(js_ir("Shop.Cart", :read, zod: zod)) ==
                 {:error, {:unadmitted_zod, "Cart.read", reason}}
      end
    end

    test "refuses injected zod arriving through IR.Codec.from_map" do
      staged = js_ir("Shop.Cart", :read, zod: "z.string()") |> IR.Codec.to_map()
      tampered = put_in(staged, ["schema", "zod"], "z.string(); globalThis.pwned = 1")

      assert {:ok, decoded} = IR.Codec.from_map(tampered)

      assert {:error, {:unadmitted_zod, "Cart.read", {:zod_unadmitted_text, _}}} =
               JS.project_ir(decoded)
    end

    test "admits the compiler's program form and refuses a tampered one", %{irs: irs} do
      program = Enum.find_value(irs, &(&1.ash.action == :create && &1.schema.zod))

      assert {:ok, :program, "z.object({\n\n}).passthrough()"} = ZodGuard.admit(program)

      tampered = String.replace(program, "z.undefined()", "z.undefined(); globalThis.pwned = 1")
      assert {:error, _} = ZodGuard.admit(tampered)
    end

    test "every admitted form projects into an artifact Node accepts" do
      irs =
        @admitted
        |> Enum.with_index()
        |> Enum.map(fn {zod, i} -> js_ir("Shop.Cart", "a#{i}", zod: zod) end)

      assert {:ok, %{"ash_surface_client.mjs" => code}, %{action_count: 7}} = JS.project_ir(irs)
      for zod <- @admitted, do: assert(code =~ zod)
      assert {_, 0} = code |> then(&write_artifact!("admitted_zod.mjs", &1)) |> node_check()
    end
  end

  ## Helpers

  defp js_ir(resource, action, opts \\ []) do
    %IR{
      version: "v1",
      ash: %IR.Ash{
        resource: resource,
        action: action,
        action_type: :read,
        policies: Keyword.get(opts, :policies, [])
      },
      schema: %IR.Schema{zod: Keyword.get(opts, :zod)}
    }
  end

  defp write_artifact!(name, code) do
    dir = Path.join(@scratch, "#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    path = Path.join(dir, name)
    File.write!(path, code)
    path
  end

  defp node_check(path), do: System.cmd("node", ["--check", path], stderr_to_stdout: true)
end
