defmodule AshSurface.Compiler.SchemaSectionTest do
  @moduledoc """
  State-based content contract for the schema section of the AshSurface
  compiler (`AshSurface.Compiler.Schema`).

  The section practices shared-manufacture: `build/2` receives the ash
  section's discovery (action argument/return descriptions) as its only
  semantic input and performs no discovery of its own. These tests freeze:

  - argument types -> exact zod fragments (golden strings, byte-mirroring
    `AshSurface.Projector.Expo`'s mapping table)
  - the paired input/output zod projection text per action
  - nil-returning actions -> `z.undefined()` output
  - input/output/aria IR descriptions
  - the no-second-discovery contract, asserted three ways: the section never
    references `Ash.Resource.Info` / `Ash.Info.Manifest` in source, the
    COMPILED bytecode of the section carries no reference to them either
    (the artifact, not the text, is the contract), and an injected
    sentinel-double discovery — data that no Ash introspection could ever
    produce — flows verbatim into the manufactured schemas
  - byte-compatibility of the per-argument zod fragments with the LIVE
    `AshSurface.Projector.Expo` canon (one mapping, machine-checked, not
    just duplicated golden strings)
  """

  use ExUnit.Case, async: true

  alias AshSurface.Compiler.Schema

  # State builders: concrete discovery state, no mocks, no env/db/network.

  defp discovery(actions), do: %{"actions" => actions}

  defp action(id, args, returns \\ nil),
    do: %{"id" => id, "arguments" => args, "returns" => returns}

  defp arg(name, kind, allow_nil? \\ false),
    do: %{"name" => name, "type" => %{"kind" => kind}, "allow_nil?" => allow_nil?}

  defp build!(actions) do
    assert {:ok, ir, _meta} = Schema.build(discovery(actions))
    ir
  end

  defp input_block(schema), do: extract_input_block(schema.zod)

  describe "argument types map to exact zod fragments (golden strings)" do
    @kinds [
      {"string", "z.string()"},
      {"integer", "z.number().int()"},
      {"boolean", "z.boolean()"},
      {"uuid", "z.string().uuid()"},
      {"float", "z.number()"},
      {"decimal", "z.number()"},
      {"utc_datetime", "z.string()"},
      {"datetime", "z.string()"},
      {"map", "z.record(z.string(), z.unknown())"},
      {"array", "z.array(z.unknown())"},
      {"exotic_unmapped", "z.unknown()"}
    ]

    test "each admitted kind maps to its frozen zod expression" do
      for {kind, zod} <- @kinds do
        schema = build!([action("act", [arg("f", kind)])])["act"]

        assert input_block(schema) == "  f: #{zod}"
      end
    end

    test "allow_nil? arguments gain .optional().nullable()" do
      schema = build!([action("act", [arg("f", "integer", true)])])["act"]

      assert input_block(schema) == "  f: z.number().int().optional().nullable()"
    end

    test "argument definitions without a type degrade to optional unknown" do
      schema = build!([action("act", [%{"name" => "f", "allow_nil?" => false}])])["act"]

      assert input_block(schema) == "  f: z.unknown().optional()"
    end

    test "multiple arguments join deterministically in discovery order" do
      schema =
        build!([
          action(
            "Volunteer.Milestone#record",
            [
              arg("member_id", "string"),
              arg("cost_physical", "integer"),
              arg("note", "string", true)
            ]
          )
        ])["Volunteer.Milestone#record"]

      assert input_block(schema) ==
               """
                 member_id: z.string(),
                 cost_physical: z.number().int(),
                 note: z.string().optional().nullable()
               """
               |> String.trim_trailing()
    end
  end

  describe "output projection" do
    test "nil-returning actions project to z.undefined output" do
      schema = build!([action("act", [], nil)])["act"]

      assert schema.zod =~ ~r/export const act_outputSchema = z\.undefined\(\);\n\z/
    end

    test "actions with no returns key at all are nil-returning too" do
      assert {:ok, ir, _meta} = Schema.build(discovery([%{"id" => "act", "arguments" => []}]))
      assert ir["act"].output == nil
      assert ir["act"].zod =~ "act_outputSchema = z.undefined();"
    end

    test "declared returns map through the same frozen table" do
      schema = build!([action("act", [], %{"type" => %{"kind" => "uuid"}})])["act"]

      assert schema.zod =~ ~r/export const act_outputSchema = z\.string\(\)\.uuid\(\);\n\z/
    end

    test "allow_nil? returns gain .optional().nullable()" do
      schema =
        build!([
          action("act", [], %{"type" => %{"kind" => "integer"}, "allow_nil?" => true})
        ])["act"]

      assert schema.zod =~ "act_outputSchema = z.number().int().optional().nullable();"
    end
  end

  describe "golden-frozen zod emission (drift detection)" do
    test "a representative action projects to the exact frozen zod text" do
      schema =
        build!([
          action(
            "Volunteer.Milestone#record-milestone",
            [arg("member_id", "string"), arg("cost_physical", "integer", true)]
          )
        ])["Volunteer.Milestone#record-milestone"]

      assert schema.zod == """
             export const Volunteer_Milestone_record_milestone_inputSchema = z.object({
               member_id: z.string(),
               cost_physical: z.number().int().optional().nullable()
             }).passthrough();

             export const Volunteer_Milestone_record_milestone_outputSchema = z.undefined();
             """
    end

    test "argument-less actions emit the empty passthrough object, mirroring the projector" do
      schema = build!([action("ping", [])])["ping"]

      assert schema.zod == """
             export const ping_inputSchema = z.object({

             }).passthrough();

             export const ping_outputSchema = z.undefined();
             """
    end
  end

  describe "IR descriptions" do
    test "input is the argument name -> type description map" do
      schema = build!([action("act", [arg("f", "string", true)])])["act"]

      assert schema.input == %{"f" => %{"type" => %{"kind" => "string"}, "allow_nil?" => true}}
    end

    test "output carries the return description verbatim, nil when nothing is returned" do
      returns = %{"type" => %{"kind" => "string"}}

      assert build!([action("act", [], returns)])["act"].output == returns
      assert build!([action("act", [])])["act"].output == nil
    end

    test "aria labels derive zero-config from names only" do
      schema =
        build!([action("Volunteer.Milestone#record", [arg("member_id", "string")])])[
          "Volunteer.Milestone#record"
        ]

      assert schema.aria == %{
               "actionId" => "Volunteer.Milestone#record",
               "label" => "Volunteer milestone record",
               "fields" => [
                 %{"name" => "member_id", "label" => "Member id", "required" => true}
               ]
             }
    end

    test "allow_nil? arguments are not required in aria" do
      schema = build!([action("act", [arg("note", "string", true)])])["act"]

      assert List.first(schema.aria["fields"])["required"] == false
    end
  end

  describe "section contract" do
    test "the IR is keyed by action id and meta carries section counts" do
      actions = [action("b.act", [arg("x", "string")]), action("a.act", [arg("y", "integer")])]

      assert {:ok, ir, meta} = Schema.build(discovery(actions))

      assert Map.keys(ir) == ["a.act", "b.act"]
      assert meta == %{action_count: 2, argument_count: 2}
    end

    test "empty discovery compiles to an empty IR" do
      assert {:ok, %{}, %{action_count: 0, argument_count: 0}} = Schema.build(discovery([]))
    end

    test "identical discovery compiles byte-identically (determinism)" do
      actions = [action("act", [arg("f", "map")])]

      assert {:ok, first, _} = Schema.build(discovery(actions))
      assert {:ok, second, _} = Schema.build(discovery(actions))
      assert first == second
    end

    test "malformed discovery is refused with tagged errors, never crashes" do
      assert {:error, :discovery_must_be_a_map} = Schema.build(:nope)
      assert {:error, :discovery_must_be_a_map} = Schema.build([action("act", [])])

      assert {:error, {:actions_must_be_a_list, :oops}} =
               Schema.build(%{"actions" => :oops})

      assert {:error, {:action_without_id, %{"arguments" => []}}} =
               Schema.build(discovery([%{"arguments" => []}]))

      assert {:error, {:argument_without_name, "act"}} =
               Schema.build(discovery([action("act", [%{"type" => %{"kind" => "string"}}])]))

      assert {:error, {:arguments_must_be_a_list, "act", :oops}} =
               Schema.build(discovery([%{"id" => "act", "arguments" => :oops}]))

      assert {:error, {:invalid_returns, "act", "string"}} =
               Schema.build(discovery([action("act", [], "string")]))
    end
  end

  describe "no second discovery" do
    test "the section never calls Ash introspection itself (source contract)" do
      source =
        Path.expand("../../../lib/ash_surface/compiler/schema.ex", __DIR__)
        |> File.read!()

      # Discovery is owned by the ash section; a call here would be a second
      # discovery pass and a silent re-coupling to Spark internals.
      for forbidden <- ["Ash.Resource.Info", "Ash.Info.Manifest", "AshSurface.from_manifest"] do
        refute source =~ forbidden, "schema section must not reference #{forbidden}"
      end
    end

    test "the compiled bytecode references no Ash introspection (artifact contract)" do
      # Source text can lie (string-built calls); the loaded artifact cannot.
      assert {:ok, {_, [abstract_code: {:raw_abstract_v1, forms}]}} =
               :beam_lib.chunks(beam_binary(AshSurface.Compiler.Schema), [:abstract_code])

      rendered = inspect(forms, limit: :infinity, printable_limit: :infinity)

      for forbidden <- ["Ash.Resource.Info", "Ash.Info.Manifest"] do
        refute rendered =~ forbidden,
               "schema section bytecode must not reference #{forbidden}"
      end
    end

    test "injected double: sentinel discovery flows verbatim, rediscovery is impossible" do
      # The double carries a sentinel type kind that exists in no Ash
      # catalog and a resource that exists nowhere. If the section performed
      # ANY re-discovery, the sentinel would vanish and the phantom resource
      # would fail to resolve. Surviving verbatim = manufactured from the
      # given state alone.
      assert {:ok, %{"phantom.Resource#ghost" => schema}, _meta} =
               Schema.build(
                 discovery([
                   action("phantom.Resource#ghost", [arg("wail", "sentinel_not_an_ash_type")])
                 ])
               )

      assert schema.input == %{
               "wail" => %{
                 "type" => %{"kind" => "sentinel_not_an_ash_type"},
                 "allow_nil?" => false
               }
             }

      # the unmapped sentinel still projects through the shared fallback
      assert schema.zod =~ "  wail: z.unknown()"
    end

    test "build/2 manufactures schemas purely from the given discovery state" do
      # Hand-built descriptions with no Ash resource loaded anywhere: if the
      # section tried to re-discover, this call could not succeed.
      assert {:ok, %{"phantom.Resource#ghost" => schema}, _meta} =
               Schema.build(
                 discovery([action("phantom.Resource#ghost", [arg("wail", "string")])])
               )

      assert schema.input == %{
               "wail" => %{"type" => %{"kind" => "string"}, "allow_nil?" => false}
             }
    end
  end

  describe "byte-compatibility with the Expo projector canon" do
    test "per-argument zod fragments match the live projector emission exactly" do
      # One canon: the frozen table above is golden, and this test proves it
      # against the projector itself. If either side drifts, this fails.
      fields =
        @kinds
        |> Enum.with_index()
        |> Map.new(fn {{kind, _zod}, i} ->
          {"f#{i}", %{"type" => %{"kind" => kind}, "allow_nil?" => rem(i, 2) == 0}}
        end)
        |> Map.put("f_untyped", %{"allow_nil?" => false})

      surface = %AshSurface.Surface{
        manifest: nil,
        action_ids: [],
        digest: nil,
        contract: %{
          "surface" => %{
            "actions" => [%{"id" => "Canon.Resource#act", "resource" => "Canon.Resource"}]
          },
          "manifest" => %{
            "resources" => %{"canon" => %{"name" => "Canon.Resource", "fields" => fields}}
          }
        }
      }

      assert {:ok, artifacts, _meta} =
               AshSurface.project(surface, AshSurface.Projector.Expo, [])

      expo_block = extract_input_block(artifacts["zoela_surface.schemas.mjs"])

      # The section's arguments iterate in the SAME order the projector
      # iterated its fields map, so the emitted text must be identical.
      args =
        Enum.map(fields, fn {name, fdef} -> Map.put(fdef, "name", name) end)

      assert {:ok, ir, _meta} = Schema.build(discovery([action("Canon.Resource#act", args)]))
      section_block = extract_input_block(ir["Canon.Resource#act"].zod)

      assert section_block == expo_block
    end
  end

  defp extract_input_block(text) do
    [block] =
      Regex.run(
        ~r/_inputSchema = z\.object\(\{\n(.*?)\n\}\)\.passthrough\(\);/s,
        text,
        capture: :all_but_first
      )

    block
  end

  # The law under test concerns the COMPILED ARTIFACT, not the loader. Under
  # `mix test --cover` every project module is cover-loaded and
  # `:code.which/1` answers the atom `:cover_compiled` instead of a path —
  # but the artifact the compiler wrote to the build path is the same beam.
  # Resolve both shapes to a binary so the artifact contract holds in the
  # plain elixir job and under the coverage battery alike (PR #7, L5 wave3,
  # 2026-09-26; CI runs 36229792940 + 36241226834 evidence).
  defp beam_binary(mod) do
    path =
      case :code.which(mod) do
        :cover_compiled -> Path.join(Mix.Project.compile_path(), "#{Atom.to_string(mod)}.beam")
        p when is_list(p) -> List.to_string(p)
      end

    assert File.exists?(path),
           "expected a compiled beam on disk for #{inspect(mod)}, got: #{inspect(path)}"

    File.read!(path)
  end
end
