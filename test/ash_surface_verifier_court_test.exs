defmodule AshSurface.Resource.Court.Sections do
  @moduledoc false

  # Rebuilds the spec's sections with the REAL generated entity structs
  # (AshSurface.Resource-family, defined by lib/ash_surface/resource.ex) so
  # ScratchTrail presents the identical section surface with `transformers: []`.

  def surface do
    %Spark.Dsl.Section{
      name: :surface,
      describe:
        "Declares consumer projection intent for public Ash actions without duplicating Ash semantics.",
      entities: [
        %Spark.Dsl.Entity{
          name: :projection,
          target: AshSurface.Dsl.Projection,
          args: [:action],
          identifier: :action,
          schema: [
            action: [
              type: :atom,
              required: true,
              doc: "Public Ash action name this projection describes."
            ],
            consumer: [
              type: :atom,
              required: false,
              doc: "Optional consumer class such as web, mobile, or internal."
            ],
            transport: [
              type: {:one_of, [:auto, :http, :phoenix_channel]},
              required: false,
              default: :auto,
              doc: "Pre-dispatch transport preference; auto preserves all admitted alternatives."
            ],
            name: [
              type: :atom,
              required: false,
              doc:
                "Wire/export name override for this projection (presentation fact; not an IR truth-section fact)."
            ],
            namespace: [
              type: :string,
              required: false,
              doc: "Optional export namespace grouping for the projection (presentation fact)."
            ],
            description: [
              type: :string,
              required: false,
              doc: "Human description of the projection (presentation fact)."
            ],
            deprecated: [
              type: :any,
              required: false,
              doc: "false, true, or a deprecation message string (presentation fact)."
            ],
            see: [
              type: {:list, :atom},
              required: false,
              doc: "Related projection or action names (presentation fact)."
            ],
            read_action: [
              type: :atom,
              required: false,
              doc:
                "Public read action used to resolve the projected resource; must be a public read action."
            ],
            get?: [
              type: :boolean,
              required: false,
              default: false,
              doc: "Project a single-record get; conflicts with get_by."
            ],
            get_by: [
              type: {:list, :atom},
              required: false,
              doc: "Attributes that identify a single record; each must be a public attribute."
            ],
            not_found_error?: [
              type: :boolean,
              required: false,
              default: true,
              doc: "Whether a missing record is an error rather than nil."
            ],
            identities: [
              type: {:list, :atom},
              required: false,
              doc: "Ash identities usable to look up a record; each must exist on the resource."
            ],
            enable_filter?: [
              type: :boolean,
              required: false,
              default: true,
              doc: "Whether the projection exposes filtering."
            ],
            enable_sort?: [
              type: :boolean,
              required: false,
              default: true,
              doc: "Whether the projection exposes sorting."
            ],
            allowed_loads: [
              type: :any,
              required: false,
              doc: "Allow-list of loadable fields; mutually exclusive with denied_loads."
            ],
            denied_loads: [
              type: :any,
              required: false,
              doc: "Deny-list of loadable fields; mutually exclusive with allowed_loads."
            ],
            show_metadata: [
              type: :any,
              required: false,
              doc: "Action metadata fields to expose: false or a list of atoms."
            ],
            metadata_field_names: [
              type: :any,
              required: false,
              doc: "Keyword map of action metadata name to wire name."
            ]
          ]
        },
        %Spark.Dsl.Entity{
          name: :typed_query,
          target: AshSurface.Dsl.TypedQuery,
          args: [:name, :action],
          identifier: :name,
          schema: [
            name: [
              type: :atom,
              required: true,
              doc: "Typed query name; unique within the resource and a valid identifier."
            ],
            action: [
              type: :atom,
              required: true,
              doc: "Public read action this typed query selects fields from."
            ],
            description: [
              type: :string,
              required: false,
              doc: "Human description of the typed query (presentation fact)."
            ],
            result_type_name: [
              type: :string,
              required: false,
              doc: "Name of the result type for the typed query (presentation fact)."
            ],
            fields_const_name: [
              type: :string,
              required: false,
              doc: "Name of the reusable fields constant (presentation fact)."
            ],
            fields: [
              type: :any,
              required: true,
              doc:
                "Field selection verified against the resource public attributes, calculations, aggregates and relationships."
            ]
          ]
        }
      ]
    }
  end
end

defmodule AshSurface.Resource.Court.ScratchTrail do
  @moduledoc false

  # Same surface, no transformers: the REAL AshSurface.Resource.Verify must still
  # refuse anything compiled under it, because nothing persists
  # :ash_surface_compiled.
  use Spark.Dsl.Extension,
    sections: [AshSurface.Resource.Court.Sections.surface()],
    transformers: [],
    verifiers: [AshSurface.Resource.Verify]
end

defmodule AshSurface.Resource.Court.Dsl do
  @moduledoc false

  use Spark.Dsl, default_extensions: [extensions: [AshSurface.Resource]]
end

defmodule AshSurface.Resource.Court.ScratchDsl do
  @moduledoc false

  use Spark.Dsl, default_extensions: [extensions: [AshSurface.Resource.Court.ScratchTrail]]
end

defmodule AshSurface.ResourceVerifierCourtTest do
  use ExUnit.Case, async: false

  # Specimen dir resolution is cwd-dependent: standalone fixture runs (mix test in
  # packs/ash-extension-pack/fixture) need the bare name; repo-root runs and the
  # live-fixture capsule need the fixture/-prefixed path. First existing wins;
  # ASH_PACK_FIXTURE_DIR overrides (the capsule chain exports it).
  @specimen_dir Enum.find(
                  [
                    System.get_env("ASH_PACK_FIXTURE_DIR") &&
                      Path.join(System.get_env("ASH_PACK_FIXTURE_DIR"), "malformed_specimens"),
                    Path.join(File.cwd!(), "malformed_specimens"),
                    Path.join(File.cwd!(), "fixture/malformed_specimens")
                  ]
                  |> Enum.reject(&is_nil/1),
                  &File.dir?/1
                ) || Path.join(File.cwd!(), "fixture/malformed_specimens")
  @verifiers [
    "allowed_and_denied_loads_conflict",
    "get_and_get_by_conflict",
    "typed_query_duplicate_name",
    "typed_query_invalid_fields",
    "typed_query_invalid_name",
    "typed_query_non_read_action",
    "typed_query_unknown_action",
    "unknown_action_projection"
  ]

  # Wave3-09 re-pin: the shared fixture dir carries other packages' specimens
  # (audit_trail et al.); ash_surface's own specimens live in test/malformed_specimens
  # and are the ones that witness this spec's declared verifiers.
  @own_specimen_dir Path.join(File.cwd!(), "test/malformed_specimens")
  @foreign_verifiers ["unique_event_name"]

  @specimens [@specimen_dir, @own_specimen_dir]
             |> Enum.flat_map(&Path.wildcard(Path.join(&1, "*.ex")))
             |> Enum.sort()
             |> Enum.map(fn path ->
               source = File.read!(path)

               meta = fn key ->
                 case Regex.run(~r/^# #{key}: (.*)$/m, source) do
                   [_, value] -> String.trim(value)
                   nil -> nil
                 end
               end

               %{
                 path: path,
                 name: path |> Path.basename(".ex"),
                 source: source,
                 verifier: meta.("VERIFIER"),
                 expect_raise: meta.("EXPECT-RAISE"),
                 expect_message: meta.("EXPECT-MESSAGE"),
                 scratch?: match?({:ok, _}, Regex.run(~r/use Court.ScratchDsl/, source))
               }
             end)

  # -- happy-path guard: the extension itself must accept a legal module, so any
  # -- specimen failure below is attributable to the refusal condition, not to a
  # -- broken extension render.
  @happy_path_source """
  defmodule Court.HappyPath do
    use AshSurface.Resource.Court.Dsl

    surface do
    end
    end
  """

  test "court is non-vacuous: specimens exist and cover declared verifiers" do
    refute @specimens == [],
           "no malformed specimens found in #{@specimen_dir} -- an empty court proves nothing"

    refute @verifiers == [],
           "spec declares no aex:Verifier rows -- nothing for the court to close"

    witnessed = Enum.map(@specimens, & &1.verifier)

    missing =
      Enum.reject(witnessed, fn v ->
        v in @verifiers or v in @foreign_verifiers or
          v in [
            "persist_before_verify",
            "verify_section_singleton_entities",
            "section_surface",
            "entity_surface"
          ]
      end)

    assert missing == [],
           "specimens witness unknown verifier(s): #{inspect(missing)} -- declared verifiers: #{inspect(@verifiers)}"
  end

  test "happy path: a legal module compiles against the real extension" do
    {mods, diagnostics} =
      Code.with_diagnostics(fn ->
        Code.compile_string(@happy_path_source)
      end)

    assert Enum.any?(mods, &match?({Court.HappyPath, _}, &1)),
           "the legal happy-path module failed to compile -- the extension render itself is broken, so any specimen refusal would be unattributable"

    error_diagnostics = Enum.filter(diagnostics, &(&1.severity == :error))

    assert error_diagnostics == [],
           "the legal happy-path module produced compiler error diagnostics: #{inspect(error_diagnostics)}"
  end

  test "every malformed specimen is refused by the real generated verifier" do
    # Specimens are spec-scoped (they call the spec's own section macros and cite
    # a VERIFIER header). A specimen whose VERIFIER is not declared by THIS spec is
    # not applicable: compiling it here would produce a section-macro CompileError
    # that proves nothing about this spec's verifiers. With verifiers declared but
    # zero applicable specimens the refusal leg is UNPROVEN, not passing.
    if @verifiers == [] do
      IO.puts(
        "NOTE(verifier-court ash_surface): spec declares no aex:Verifier rows -- " <>
          "specimen legs skipped; the non-vacuity test carries the typed refusal"
      )
    else
      applicable = Enum.filter(@specimens, &(&1.verifier in @verifiers))

      assert applicable != [],
             "no malformed specimen witnesses any declared verifier #{inspect(@verifiers)} -- refusal leg unproven"

      Enum.each(applicable, fn specimen ->
        source =
          specimen.source
          |> String.split("\n")
          |> Enum.reject(&String.starts_with?(&1, "#"))
          |> Enum.join("\n")
          |> String.replace("Court.ScratchDsl", "AshSurface.Resource.Court.ScratchDsl")
          |> String.replace("Court.Dsl", "AshSurface.Resource.Court.Dsl")

        # Elixir 1.19+ hazards: a Spark verifier raising inside the parallel checker
        # can surface as a swallowed warning with a SUCCESSFUL compile. The court
        # therefore treats a refusal as: a real raise OR a captured compiler
        # diagnostic carrying the specimen's EXPECT-MESSAGE substring. A clean
        # compile with no matching diagnostic = vacuous verifier.
        {outcome, diagnostics} =
          Code.with_diagnostics(fn ->
            try do
              Code.compile_string(source)
              :compiled_clean
            rescue
              e ->
                {:raised, e.__struct__ |> Module.split() |> Enum.join("."), Exception.message(e)}
            end
          end)

        case outcome do
          {:raised, kind, message} ->
            matched? =
              String.contains?(message, specimen.expect_message) or
                Enum.any?(diagnostics, fn d ->
                  d.severity in [:error, :warning] and
                    String.contains?(d.message, specimen.expect_message)
                end)

            assert kind == specimen.expect_raise and matched?,
                   "specimen #{specimen.name}: expected #{specimen.expect_raise} matching \"#{specimen.expect_message}\", " <>
                     "got #{kind}: #{message}" <>
                     if(diagnostics == [],
                       do: "",
                       else:
                         "\n  captured diagnostics: " <>
                           inspect(Enum.map(diagnostics, &{&1.severity, &1.message}),
                             limit: :infinity
                           )
                     )

          :compiled_clean ->
            diagnostic =
              Enum.find(diagnostics, fn d ->
                d.severity in [:error, :warning] and
                  String.contains?(d.message, specimen.expect_message)
              end)

            unless diagnostic do
              flunk(
                "VACUOUS VERIFIER #{specimen.verifier || "?"}: specimen #{specimen.name} " <>
                  "(#{specimen.path}) compiled CLEANLY with no matching refusal diagnostic -- " <>
                  "refusal condition never fires, so the verifier carries no bits. " <>
                  "Expected raise #{specimen.expect_raise} matching \"#{specimen.expect_message}\". " <>
                  "Captured diagnostics: #{inspect(Enum.map(diagnostics, &{&1.severity, String.slice(&1.message, 0, 120)}))}"
              )
            end
        end
      end)
    end
  end
end
