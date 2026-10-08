










defmodule AshA2A.Dsl.Court.Sections do
  @moduledoc false

  # Rebuilds the spec's sections with the REAL generated entity structs
  # (AshA2A.Dsl-family, defined by lib/ash_a2a/resource.ex) so
  # ScratchTrail presents the identical section surface with `transformers: []`.

  def a2a do
    %Spark.Dsl.Section{
      name: :a2a,
      describe: "Optional residual A2A overrides. Public Ash actions are exposed without declarations.",
      schema: [
        semantic_requests: [type: :boolean],
      ],
      entities: [
        %Spark.Dsl.Entity{
          name: :skill,
          target: AshA2A.Skill,
          args: [:name, :resource, :action],
          identifier: :name,
          schema: [
            name: [type: :atom, required: true, doc: "A2A display/selector name override for the referenced public Ash action."],
            resource: [type: :module, required: false, doc: "Target resource. Required on a domain; implicit on a resource. Real Spark type {:spark, Ash.Resource}."],
            action: [type: :atom, required: true, doc: "Canonical public Ash action to override."],
            description: [type: :string, required: false, doc: "Optional A2A-only description override."],
            tags: [type: {:list, :string}, required: false, doc: "Optional A2A-only tags override."],
            expose?: [type: :boolean, required: false, default: true, doc: "Whether this otherwise-public Ash action is exposed through AshA2A.Protocol."],
            consequence: [type: {:one_of, [:observe, :change, :external_do, :unknown]}, required: false, doc: "Explicit consequence classification (AshA2A.Skill @moduledoc); observe_on_mutating_action is a compile-time DslError (SEC-04)."],
            on_cancel: [type: :any, required: false, doc: "Real Ash-side compensation hook (AshA2A.OnCancel). Real Spark type {:or, [:module, :mfa]} (dsl.ex:58)."],
            argument_mapping: [type: :any, required: false, default: %{}, doc: "Map of wire (string) argument name to atom action argument name. Real Spark type {:map, :string, :atom}. Verified by AshA2A.Verifiers.VerifySkills (refused_argument_mapping_target, verify_skills.ex:184-199)."],
            get?: [type: :boolean, required: false, default: false, doc: "Marks a read skill as a single-record get (mirrors ash_json_api's get? semantic); read via the compiled capability index."],
            lease_required?: [type: :boolean, required: false, default: false, doc: "Governance boundary: dispatch under this skill requires a valid authority lease; the authorizer consequence is enforced by the architecture verifier. Compile-time refusal refused_lease_required_no_authorizer (verify_skills.ex:299-311)."],
          ]
        }
      ]
    }
  end

  def authority do
    %Spark.Dsl.Section{
      name: :authority,
      describe: "Declarative two-port gate policies and lease constraints for A2A actions.",
      schema: [
        gate: [type: :one_of],
        lease_duration_ms: [type: :integer],
      ],
      entities: [
      ]
    }
  end

  def hooks do
    %Spark.Dsl.Section{
      name: :hooks,
      describe: "Declarative binding of GraphLaw knowledge hooks to action lifecycle points.",
      schema: [
        pre_dispatch: [type: {:list, :atom}],
        post_dispatch: [type: {:list, :atom}],
      ],
      entities: [
      ]
    }
  end
end

defmodule AshA2A.Dsl.Court.ScratchTrail do
  @moduledoc false

  # Same surface, no transformers: the REAL AshA2A.Dsl.Verify must still
  # refuse anything compiled under it, because nothing persists
  # :ash_a2a_compiled.
  use Spark.Dsl.Extension,
    sections: [AshA2A.Dsl.Court.Sections.a2a(), AshA2A.Dsl.Court.Sections.authority(), AshA2A.Dsl.Court.Sections.hooks()],
    transformers: [],
    verifiers: [AshA2A.Dsl.Verify]
end

defmodule AshA2A.Dsl.Court.Dsl do
  @moduledoc false

  use Spark.Dsl, default_extensions: [extensions: [AshA2A.Dsl]]
end

defmodule AshA2A.Dsl.Court.ScratchDsl do
  @moduledoc false

  use Spark.Dsl, default_extensions: [extensions: [AshA2A.Dsl.Court.ScratchTrail]]
end

defmodule AshA2A.DslVerifierCourtTest do
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
  @verifiers []

  @specimens @specimen_dir
             |> Path.join("*.ex")
             |> Path.wildcard()
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
    use AshA2A.Dsl.Court.Dsl

    a2a do
    end
    authority do
    end
    hooks do
    end
    end
  """

  test "court is non-vacuous: specimens exist and cover declared verifiers" do
    refute @specimens == [], "no malformed specimens found in #{@specimen_dir} -- an empty court proves nothing"
    refute @verifiers == [], "spec declares no aex:Verifier rows -- nothing for the court to close"

    witnessed = Enum.map(@specimens, & &1.verifier)

    missing =
      Enum.reject(witnessed, fn v ->
        v in @verifiers or v in ["persist_before_verify", "verify_section_singleton_entities", "section_surface", "entity_surface"]
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
        "NOTE(verifier-court ash_a2a): spec declares no aex:Verifier rows -- " <>
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
        |> String.replace("Court.ScratchDsl", "AshA2A.Dsl.Court.ScratchDsl")
        |> String.replace("Court.Dsl", "AshA2A.Dsl.Court.Dsl")

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
            e -> {:raised, e.__struct__ |> Module.split() |> Enum.join("."), Exception.message(e)}
          end
        end)

      case outcome do
        {:raised, kind, message} ->
          matched? =
            String.contains?(message, specimen.expect_message) or
              Enum.any?(diagnostics, fn d ->
                d.severity in [:error, :warning] and String.contains?(d.message, specimen.expect_message)
              end)

          assert kind == specimen.expect_raise and matched?,
                 "specimen #{specimen.name}: expected #{specimen.expect_raise} matching \"#{specimen.expect_message}\", " <>
                   "got #{kind}: #{message}" <>
                   if(diagnostics == [],
                     do: "",
                     else:
                       "\n  captured diagnostics: " <>
                         inspect(Enum.map(diagnostics, &{&1.severity, &1.message}), limit: :infinity)
                   )

        :compiled_clean ->
          diagnostic =
            Enum.find(diagnostics, fn d ->
              d.severity in [:error, :warning] and String.contains?(d.message, specimen.expect_message)
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
