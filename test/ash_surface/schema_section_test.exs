defmodule AshSurface.SchemaSectionTest do
  @moduledoc """
  Depth contract for the zod schema section of `AshSurface.Projector.Expo`'s
  `{prefix}.schemas.mjs` emission — deepening the v07 basics
  (`AshSurface.Projector.ExpoSchemasTest`) without duplicating them.

  v07 froze the flat contract: the scalar kind table, `allow_nil?` decoration,
  identifier sanitization, resource resolution, and the one-action golden file.
  This file declares the same contract locally and goes deeper on four axes:

  * **Nested map/array arguments.** Types carrying the nesting Ash actually
    serializes (`"fields"` for maps, `"item_type"` for arrays, shaped exactly
    as `Ash.Info.Manifest.JsonSerializer.serialize_type/1`) project to the
    flat canon, byte-for-byte matching `expo.ex`'s `map_zod_type/1`. One canon:
    nesting depth never produces a second interpretation.
  * **Enums and unions where Ash carries them** (`"values"` on `kind: "enum"`,
    `"members"` on `kind: "union"`).
  * **Eight golden zod strings** for drift detection.
  * **NO-REDISCOVERY.** Projection consumes an injected wrapper double — a
    fully serialized surface whose resource name resolves to no loaded module —
    and the projector's compiled beam carries zero `Ash.Resource.Info`
    references, so the call cannot exist.

  All tests are pure state over hand-built serialized surfaces: no mocks, env,
  db, or network.
  """

  use ExUnit.Case, async: true

  alias AshSurface.Projector.Expo

  # ---------------------------------------------------------------------------
  # Local contract (same as v07; helpers are declared here, not shared).
  # ---------------------------------------------------------------------------

  defp surface(actions, resources) do
    %AshSurface.Surface{
      manifest: nil,
      contract: %{
        "surface" => %{"actions" => actions},
        "manifest" => %{"resources" => resources}
      },
      digest: "digest-schema-section",
      action_ids: Enum.map(actions, & &1["id"])
    }
  end

  defp project_schemas(actions, resources) do
    assert {:ok, artifacts, _meta} = Expo.project(surface(actions, resources), prefix: "z")
    artifacts["z.schemas.mjs"]
  end

  defp input_block(code, safe_name) do
    [block] =
      Regex.run(
        ~r/export const #{safe_name}_inputSchema = z\.object\(\{\n(.*?)\n\}\)\.passthrough\(\);/s,
        code,
        capture: :all_but_first
      )

    block
  end

  defp projected_block(fields) do
    code =
      project_schemas(
        [%{"id" => "act", "resource" => "Res"}],
        %{"res" => %{"name" => "Res", "fields" => fields}}
      )

    input_block(code, "act")
  end

  defp projected_code(fields),
    do: project_schemas([%{"id" => "act", "resource" => "Res"}], fields_resource(fields))

  defp fields_resource(fields), do: %{"res" => %{"name" => "Res", "fields" => fields}}

  defp typed_field(type), do: %{"f" => %{"type" => type}}

  # ---------------------------------------------------------------------------
  # Serialized type payloads — shaped exactly as
  # Ash.Info.Manifest.JsonSerializer.serialize_type/1 emits them.
  # ---------------------------------------------------------------------------

  defp s_type(kind), do: %{"kind" => kind, "name" => kind, "allow_nil" => false}

  defp nested_map_type(fields), do: Map.put(s_type("map"), "fields", fields)

  defp nested_array_type(item_type), do: Map.put(s_type("array"), "item_type", item_type)

  defp enum_type(values),
    do: s_type("enum") |> Map.merge(%{"module" => "Volunteer.Status", "values" => values})

  defp union_type(members), do: Map.put(s_type("union"), "members", members)

  defp member(name, type), do: %{"name" => name, "type" => type}

  defp tfield(name, type), do: %{"name" => name, "type" => type, "allow_nil" => false}

  # The one canon: expo.ex's map_zod_type/1 bytes for nesting-bearing kinds.
  @canon_nested_map "z.record(z.string(), z.unknown())"
  @canon_nested_array "z.array(z.unknown())"
  @canon_enum "z.unknown()"
  @canon_union "z.unknown()"
  @canon_enum_optional "z.unknown().optional().nullable()"
  @canon_array_optional "z.array(z.unknown()).optional().nullable()"

  # A maximal serialized resource: nested map (carrying enum + nested array of
  # maps inside), enum with values, array with item_type, union with members.
  defp deep_double_fields do
    %{
      "alerts" => %{
        "type" =>
          nested_map_type([
            tfield("channel", enum_type(["push", "sms"])),
            tfield(
              "quiet_hours",
              nested_array_type(nested_map_type([tfield("start", s_type("integer"))]))
            )
          ])
      },
      "status" => %{"type" => enum_type(["active", "paused"])},
      "tags" => %{"type" => nested_array_type(s_type("string"))},
      "target" => %{
        "type" =>
          union_type([member("url", s_type("string")), member("record_id", s_type("uuid"))])
      }
    }
  end

  defp deep_double_block do
    [
      "  alerts: #{@canon_nested_map},",
      "  status: #{@canon_enum},",
      "  tags: #{@canon_nested_array},",
      "  target: #{@canon_union}"
    ]
    |> Enum.join("\n")
  end

  describe "nested map arguments project to the flat canon, byte-for-byte" do
    test "a map carrying Ash-serialized nested fields emits exactly the flat record expression" do
      type = nested_map_type([tfield("theme", s_type("string"))])

      assert projected_block(typed_field(type)) == "  f: #{@canon_nested_map}"
    end

    test "map nesting at any depth (map -> map field -> array of maps) stays flat" do
      type =
        nested_map_type([
          tfield(
            "webhook",
            nested_map_type([
              tfield(
                "events",
                nested_array_type(nested_map_type([tfield("kind", s_type("string"))]))
              )
            ])
          )
        ])

      assert projected_block(typed_field(type)) == "  f: #{@canon_nested_map}"
    end

    test "a map whose nested field is an array with an item_type still emits the record canon" do
      type = nested_map_type([tfield("lanes", nested_array_type(s_type("integer")))])

      assert projected_block(typed_field(type)) == "  f: #{@canon_nested_map}"
    end

    test "nested payload structure never leaks into the emission" do
      code = projected_code(typed_field(nested_map_type([tfield("theme", s_type("string"))])))

      for leak <- ["\"fields\"", "theme", "z.enum(", "z.union("] do
        refute code =~ leak, "expected no #{inspect(leak)} in emitted JS"
      end
    end
  end

  describe "nested array arguments project to the flat canon, byte-for-byte" do
    test "an array carrying an Ash-serialized item_type emits exactly the flat array expression" do
      assert projected_block(typed_field(nested_array_type(s_type("uuid")))) ==
               "  f: #{@canon_nested_array}"
    end

    test "an array of maps with nested fields (double nesting) stays flat" do
      type = nested_array_type(nested_map_type([tfield("score", s_type("float"))]))

      assert projected_block(typed_field(type)) == "  f: #{@canon_nested_array}"
    end

    test "an array of arrays stays flat and the item_type payload never leaks" do
      code = projected_code(typed_field(nested_array_type(nested_array_type(s_type("boolean")))))

      assert projected_block(typed_field(nested_array_type(nested_array_type(s_type("boolean"))))) ==
               "  f: #{@canon_nested_array}"

      refute code =~ "\"item_type\""
    end
  end

  describe "enums and unions where Ash carries them" do
    test "an enum with an Ash-carried values payload projects to the unknown canon" do
      assert projected_block(typed_field(enum_type(["active", "paused", "archived"]))) ==
               "  f: #{@canon_enum}"
    end

    test "no enum literal is fabricated from the values payload (one canon, no second reading)" do
      code = projected_code(typed_field(enum_type(["active", "paused"])))

      for fabrication <- ["z.enum(", "z.literal(", "active", "paused"] do
        refute code =~ fabrication, "fabricated #{inspect(fabrication)} from enum values"
      end
    end

    test "a union with Ash-carried members projects to the unknown canon" do
      type = union_type([member("url", s_type("string")), member("record_id", s_type("uuid"))])

      assert projected_block(typed_field(type)) == "  f: #{@canon_union}"
    end

    test "no union combinator or member name is fabricated from the members payload" do
      code = projected_code(typed_field(union_type([member("url", s_type("string"))])))

      for fabrication <- ["z.union(", "z.discriminatedUnion(", "\"url\""] do
        refute code =~ fabrication, "fabricated #{inspect(fabrication)} from union members"
      end
    end

    test "a mixed nested resource projects its whole input block byte-for-byte" do
      code =
        project_schemas(
          [%{"id" => "deep.record", "resource" => "Res"}],
          fields_resource(deep_double_fields())
        )

      assert input_block(code, "deep_record") == deep_double_block()
    end

    test "the serializer's field key (\"allow_nil\") is not the canon's (\"allow_nil?\")" do
      # JsonSerializer emits "allow_nil" on fields; expo.ex's canon reads
      # "allow_nil?". Byte-for-byte canon freeze: the real key does not
      # decorate. Drift here must be a conscious canon change, not silence.
      fields = %{"f" => %{"type" => enum_type(["a"]), "allow_nil" => true}}

      assert projected_block(fields) == "  f: #{@canon_enum}"
    end

    test "same kinds with rebuilt nested payload content and ordering project byte-identically" do
      rebuilt = %{
        "target" => %{
          "type" => union_type([member("url", s_type("string")), member("id", s_type("uuid"))])
        },
        "alerts" => %{"type" => nested_map_type([tfield("channel", enum_type(["push"]))])}
      }

      first = projected_code(deep_double_fields())
      second = projected_code(Map.merge(deep_double_fields(), rebuilt))

      assert first == second
    end
  end

  describe "golden zod strings (drift detection)" do
    test "the eight nesting/enum/union goldens are frozen byte-for-byte" do
      goldens = [
        {"nested map with ash-carried fields",
         %{"f" => %{"type" => nested_map_type([tfield("theme", s_type("string"))])}},
         @canon_nested_map},
        {"map containing a nested array field",
         %{
           "f" => %{
             "type" => nested_map_type([tfield("lanes", nested_array_type(s_type("integer")))])
           }
         }, @canon_nested_map},
        {"nested array with ash-carried item_type",
         %{"f" => %{"type" => nested_array_type(s_type("uuid"))}}, @canon_nested_array},
        {"array of maps with nested fields",
         %{
           "f" => %{
             "type" => nested_array_type(nested_map_type([tfield("score", s_type("float"))]))
           }
         }, @canon_nested_array},
        {"enum with ash-carried values", %{"f" => %{"type" => enum_type(["active", "paused"])}},
         @canon_enum},
        {"union with ash-carried members",
         %{"f" => %{"type" => union_type([member("url", s_type("string"))])}}, @canon_union},
        {"enum with allow_nil?", %{"f" => %{"type" => enum_type(["a"]), "allow_nil?" => true}},
         @canon_enum_optional},
        {"nested array with allow_nil?",
         %{"f" => %{"type" => nested_array_type(s_type("uuid")), "allow_nil?" => true}},
         @canon_array_optional}
      ]

      assert length(goldens) == 8

      for {label, fields, golden} <- goldens do
        assert projected_block(fields) == "  f: #{golden}", label
      end
    end
  end

  describe "no-rediscovery: zero Ash.Resource.Info calls" do
    test "projection runs purely from the injected wrapper double — no Ash module is resolvable" do
      # The wrapper double carries the ENTIRE Ash truth, serialized; its
      # resource name matches no loaded module, so no Spark introspection
      # could answer for it even if the projector asked.
      resource_name = "Volunteer.DeepDouble"

      assert {:error, _} = Code.ensure_compiled(Module.concat([Volunteer, DeepDouble]))

      code =
        project_schemas(
          [%{"id" => "volunteer.deep_double#record", "resource" => resource_name}],
          %{"res" => %{"name" => resource_name, "fields" => deep_double_fields()}}
        )

      assert input_block(code, "volunteer_deep_double_record") == deep_double_block()
    end

    test "the projector beam carries zero Ash.Resource.Info references (static proof)" do
      {:ok, {_mod, [atoms: atoms]}} =
        :beam_lib.chunks(beam_binary(AshSurface.Projector.Expo), [:atoms])

      names = for {_index, name} <- atoms, do: name

      # No atom -> no call site can exist: the compiled projector cannot
      # reference, let alone call, Ash.Resource.Info.
      refute :"Elixir.Ash.Resource.Info" in names
    end

    test "audit falsifier: a module that does consult Ash.Resource.Info is detected" do
      # AshSurface.Resource.Validator legitimately rediscovers the exact
      # public action set; the audit must see its call site or the static
      # proof above is dead.
      {:ok, {_mod, [atoms: atoms]}} =
        :beam_lib.chunks(beam_binary(AshSurface.Resource.Validator), [:atoms])

      names = for {_index, name} <- atoms, do: name

      assert :"Elixir.Ash.Resource.Info" in names
    end
  end

  # The law under test concerns the COMPILED ARTIFACT, not the loader. Under
  # `mix test --cover` every project module is cover-loaded and
  # `:code.which/1` answers the atom `:cover_compiled` instead of a path —
  # but the artifact the compiler wrote to the build path is the same beam.
  # Resolve both shapes to a binary so the static proofs hold in the plain
  # elixir job and under the coverage battery alike (PR #7, L5 wave3,
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
