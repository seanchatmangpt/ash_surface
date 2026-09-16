defmodule AshSurface.Projector.ExpoSchemasTest do
  @moduledoc """
  State-based content contract for the `{prefix}.schemas.mjs` emission of
  `AshSurface.Projector.Expo`.

  Unlike `ExpoTest` (real Ash manifest, artifact existence, node gate), these
  tests drive the projector with hand-built `AshSurface.Surface` state and
  freeze the emitted JavaScript: paired zod input/output schemas for every
  admitted action, deterministic identifier sanitization, zod type mapping,
  resource resolution, golden fragments for drift detection, and structural
  JS validity without requiring node.
  """

  use ExUnit.Case, async: true

  alias AshSurface.Projector.Expo

  # State builders: concrete contract state, no mocks, no env/db/network.

  defp surface(actions, resources) do
    %AshSurface.Surface{
      manifest: nil,
      contract: %{
        "surface" => %{"actions" => actions},
        "manifest" => %{"resources" => resources}
      },
      digest: "digest-test",
      action_ids: Enum.map(actions, & &1["id"])
    }
  end

  defp project_schemas(actions, resources \\ %{}, opts \\ [prefix: "zoela_surface"]) do
    prefix = Keyword.get(opts, :prefix, "zoela_surface")
    assert {:ok, artifacts, _meta} = Expo.project(surface(actions, resources), opts)
    assert is_binary(artifacts["#{prefix}.schemas.mjs"])
    artifacts["#{prefix}.schemas.mjs"]
  end

  defp fielded_action(id, resource, fields) do
    {[%{"id" => id, "resource" => resource}],
     %{"res" => %{"name" => resource, "fields" => fields}}}
  end

  defp input_block(code, safe_name) do
    assert [_] = Regex.run(~r/export const #{safe_name}_inputSchema/, code),
           "expected an inputSchema export for #{safe_name}"

    [block] =
      Regex.run(
        ~r/export const #{safe_name}_inputSchema = z\.object\(\{\n(.*?)\n\}\)\.passthrough\(\);/s,
        code,
        capture: :all_but_first
      )

    block
  end

  defp output_block(code, safe_name) do
    [block] =
      Regex.run(
        ~r/export const #{safe_name}_outputSchema = z\.object\(\{\n(.*?)\n\}\)\.passthrough\(\);/s,
        code,
        capture: :all_but_first
      )

    block
  end

  describe "admitted action coverage" do
    test "every admitted action gets paired input/output zod schemas and a SCHEMAS binding" do
      actions = [
        %{"id" => "feed.list"},
        %{"id" => "feed.create"},
        %{"id" => "milestone.record"}
      ]

      code = project_schemas(actions)

      for id <- actions do
        safe = String.replace(id["id"], ~r/[^a-zA-Z0-9_]/, "_")

        assert code =~ "export const #{safe}_inputSchema = z.object({"
        assert code =~ "}).passthrough();"

        assert code =~
                 ~s("#{id["id"]}": { input: #{safe}_inputSchema, output: #{safe}_outputSchema })
      end

      assert length(Regex.scan(~r/_inputSchema = z\.object/, code)) == 3
      assert length(Regex.scan(~r/_outputSchema = z\.object/, code)) == 3
      assert length(Regex.scan(~r/export const SCHEMAS = \{/, code)) == 1
    end

    test "SCHEMAS map is emitted even with no admitted actions" do
      code = project_schemas([], %{})

      assert code =~ "export const SCHEMAS = {\n\n};"
      assert code =~ "import { z } from \"zod\";"
      refute code =~ "_inputSchema"
      refute code =~ "_outputSchema"
    end
  end

  describe "deterministic names" do
    test "action ids are sanitized to JS identifiers by replacing non-word characters" do
      code = project_schemas([%{"id" => "Volunteer.Milestone#record-milestone"}])

      assert code =~ "export const Volunteer_Milestone_record_milestone_inputSchema"
      assert code =~ "export const Volunteer_Milestone_record_milestone_outputSchema"
      # SCHEMAS keys keep the raw semantic id, projections use the sanitized name.
      assert code =~ ~s("Volunteer.Milestone#record-milestone":)
    end

    test "already-safe ids pass through unchanged" do
      code = project_schemas([%{"id" => "ping"}])
      assert code =~ "export const ping_inputSchema"
    end

    test "identical state re-projects to byte-identical schemas.mjs" do
      actions = [%{"id" => "a.b", "resource" => "R"}, %{"id" => "c"}]

      resources = %{
        "res" => %{"name" => "R", "fields" => %{"x" => %{"type" => %{"kind" => "string"}}}}
      }

      first = project_schemas(actions, resources)
      second = project_schemas(actions, resources)
      assert first == second
    end

    test "schemas.mjs content is independent of the artifact prefix" do
      actions = [%{"id" => "ping"}]

      assert project_schemas(actions, %{}, prefix: "zoela_surface") ==
               project_schemas(actions, %{}, prefix: "other_prefix")
    end
  end

  describe "zod type mapping from manifest resource fields" do
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
        {actions, resources} =
          fielded_action("act", "Res", %{"f" => %{"type" => %{"kind" => kind}}})

        assert input_block(project_schemas(actions, resources), "act") == "  f: #{zod}"
      end
    end

    test "allow_nil? fields gain .optional().nullable()" do
      {actions, resources} =
        fielded_action("act", "Res", %{
          "f" => %{"type" => %{"kind" => "integer"}, "allow_nil?" => true}
        })

      assert input_block(project_schemas(actions, resources), "act") ==
               "  f: z.number().int().optional().nullable()"
    end

    test "field definitions without a type degrade to optional unknown" do
      {actions, resources} = fielded_action("act", "Res", %{"f" => %{}})

      assert input_block(project_schemas(actions, resources), "act") ==
               "  f: z.unknown().optional()"
    end

    test "output schema boundary shape is frozen for every action" do
      code = project_schemas([%{"id" => "ping"}])

      assert output_block(code, "ping") ==
               String.trim_trailing("""
                 success: z.boolean(),
                 data: z.record(z.string(), z.unknown()).optional(),
                 receiptRef: z.string().optional(),
                 error: z.string().optional()
               """)
    end
  end

  describe "resource resolution" do
    test "map-form resources resolve by name and by module" do
      code =
        project_schemas(
          [%{"id" => "act", "resource" => "Res"}],
          %{"res" => %{"name" => "Res", "fields" => %{"n" => %{"type" => %{"kind" => "string"}}}}}
        )

      assert input_block(code, "act") == "  n: z.string()"

      code =
        project_schemas(
          [%{"id" => "act", "resource" => "Res"}],
          %{
            "res" => %{
              "module" => "Res",
              "fields" => %{"m" => %{"type" => %{"kind" => "boolean"}}}
            }
          }
        )

      assert input_block(code, "act") == "  m: z.boolean()"
    end

    test "list-form resources resolve by name and by module" do
      for key <- ["name", "module"] do
        resources = [%{key => "Res", "fields" => %{"f" => %{"type" => %{"kind" => "uuid"}}}}]
        code = project_schemas([%{"id" => "act", "resource" => "Res"}], resources)
        assert input_block(code, "act") == "  f: z.string().uuid()"
      end
    end

    test "unresolvable or field-less resources degrade to empty passthrough input objects" do
      action = %{"id" => "act", "resource" => "Res"}

      degenerate = [
        # no matching resource
        %{"res" => %{"name" => "Other"}},
        # matching resource without a fields map
        %{"res" => %{"name" => "Res"}},
        # fields present but not a map
        %{"res" => %{"name" => "Res", "fields" => []}}
      ]

      for resources <- degenerate do
        assert input_block(project_schemas([action], resources), "act") == ""
      end

      # an action with no resource reference at all resolves nothing
      assert input_block(
               project_schemas([%{"id" => "act"}], %{"res" => %{"name" => "Res"}}),
               "act"
             ) == ""
    end
  end

  describe "golden-frozen emission (drift detection)" do
    test "header and import preamble are frozen" do
      code = project_schemas([%{"id" => "ping"}])

      assert String.starts_with?(code, """
             // @generated by AshSurface.Projector.Expo (CalVer 26.9.16)
             // Do not edit directly; modify authoritative Ash resources or ontology instead.

             import { z } from "zod";
             """)
    end

    test "minimal one-action surface projects to the exact frozen file" do
      code = project_schemas([%{"id" => "ping"}])

      assert code == """
             // @generated by AshSurface.Projector.Expo (CalVer 26.9.16)
             // Do not edit directly; modify authoritative Ash resources or ontology instead.

             import { z } from "zod";

             export const ping_inputSchema = z.object({

             }).passthrough();

             export const ping_outputSchema = z.object({
               success: z.boolean(),
               data: z.record(z.string(), z.unknown()).optional(),
               receiptRef: z.string().optional(),
               error: z.string().optional()
             }).passthrough();


             export const SCHEMAS = {
               "ping": { input: ping_inputSchema, output: ping_outputSchema }
             };
             """
    end
  end

  describe "structural JS validity (zero-config)" do
    test "braces and parens are balanced and no Elixir terms leak into the emission" do
      code =
        project_schemas(
          [%{"id" => "a.b#c", "resource" => "R"}, %{"id" => "plain"}],
          %{"res" => %{"name" => "R", "fields" => %{"f" => %{"type" => %{"kind" => "map"}}}}}
        )

      assert String.ends_with?(code, "};\n")
      assert count(code, "{") == count(code, "}")
      assert count(code, "(") == count(code, ")")

      # Elixir rendering leakage would break JS parsing downstream.
      for leakage <- ["%{", "nil", "Elixir.", "<<"] do
        refute code =~ leakage, "expected no #{inspect(leakage)} in emitted JS"
      end
    end

    test "node --check accepts the emission when node is available (skipped otherwise)" do
      code =
        project_schemas(
          [%{"id" => "act", "resource" => "R"}],
          %{
            "res" => %{
              "name" => "R",
              "fields" => %{"f" => %{"type" => %{"kind" => "string"}, "allow_nil?" => true}}
            }
          }
        )

      if node = System.find_executable("node") do
        path =
          Path.join(System.tmp_dir!(), "t19_schemas_#{System.unique_integer([:positive])}.mjs")

        File.write!(path, code)

        {output, status} = System.cmd(node, ["--check", path], stderr_to_stdout: true)
        File.rm!(path)
        assert status == 0, "node --check rejected schemas.mjs emission:\n#{output}"
      else
        # Zero-config fallback: structural balance + frozen golden already pin validity.
        assert count(code, "{") == count(code, "}")
      end
    end
  end

  defp count(code, char), do: length(:binary.matches(code, char))
end
