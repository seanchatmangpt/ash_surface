# ---------------------------------------------------------------------------
# Canonical local declaration of lib/ash_surface/ir.ex (absent at this commit).
#
# The IR + five embedded section structs are declared here so the deep
# IR-struct law below is executable. When an admitted lib/ash_surface/ir.ex
# lands, this block must be deleted and these tests must bind to the admitted
# module; the law itself must not change.
#
# Canonical shape frozen here (field sets are pinned verbatim in the tests):
#
#   AshSurface.IRStructTest.IR.Ash          resource action action_type inputs outputs policies
#   AshSurface.IRStructTest.IR.Semantic     subject_iri capability_iri predicates shape_id ontology
#   AshSurface.IRStructTest.IR.Capability   capability_id consequence_class authority_required receipt_required
#   AshSurface.IRStructTest.IR.Presentation label group order widget format
#   AshSurface.IRStructTest.IR.Schema       input output zod aria
#   AshSurface.IR              version digest + the five sections above
#
# Law frozen by this shape:
#   * five sections -- :ash, :semantic, :capability, :presentation, :schema --
#     are each independently nil-able;
#   * the all-nil IR is legal: a pure-presentation dumb screen exists;
#   * :digest and :version are nil-or-string, enforced at the constructor;
#   * no section (nor the IR) carries an execute path: an IR is projected,
#     never actuated;
#   * section accessors are deterministic.
# ---------------------------------------------------------------------------

defmodule AshSurface.IRStructTest.IR.Ash do
  @moduledoc """
  Ash-semantics section: manifest-level facts about one Ash interaction.

  A pure data carrier. It must never carry an execute path.
  """

  defstruct [:resource, :action, :action_type, :inputs, :outputs, :policies]

  @type t :: %__MODULE__{
          resource: String.t() | nil,
          action: String.t() | nil,
          action_type: atom() | String.t() | nil,
          inputs: [map()] | nil,
          outputs: [map()] | nil,
          policies: [map()] | nil
        }
end

defmodule AshSurface.IRStructTest.IR.Semantic do
  @moduledoc """
  Semantic section: IRI-anchored meaning (subjects, predicates, ontology).

  A pure data carrier. It must never carry an execute path.
  """

  defstruct [:subject_iri, :capability_iri, :predicates, :shape_id, :ontology]

  @type t :: %__MODULE__{
          subject_iri: String.t() | nil,
          capability_iri: String.t() | nil,
          predicates: [map()] | nil,
          shape_id: String.t() | nil,
          ontology: String.t() | nil
        }
end

defmodule AshSurface.IRStructTest.IR.Capability do
  @moduledoc """
  Capability section: consequence class and authority posture of a capability.

  A pure data carrier. It must never carry an execute path.
  """

  defstruct [:capability_id, :consequence_class, :authority_required, :receipt_required]

  @type t :: %__MODULE__{
          capability_id: String.t() | nil,
          consequence_class: String.t() | nil,
          authority_required: boolean() | nil,
          receipt_required: boolean() | nil
        }
end

defmodule AshSurface.IRStructTest.IR.Presentation do
  @moduledoc """
  Presentation section: pure-presentation placement (label, group, widget).

  A pure data carrier. It must never carry an execute path.
  """

  defstruct [:label, :group, :order, :widget, :format]

  @type t :: %__MODULE__{
          label: String.t() | nil,
          group: String.t() | nil,
          order: integer() | nil,
          widget: String.t() | nil,
          format: String.t() | nil
        }
end

defmodule AshSurface.IRStructTest.IR.Schema do
  @moduledoc """
  Schema section: shape facts for the consumer boundary (input, output, zod, aria).

  A pure data carrier. It must never carry an execute path.
  """

  defstruct [:input, :output, :zod, :aria]

  @type t :: %__MODULE__{
          input: map() | nil,
          output: map() | nil,
          zod: map() | nil,
          aria: map() | nil
        }
end

defmodule AshSurface.IRStructTest.IR do
  @moduledoc """
  Intermediate representation between the Ash manifest and consumer projections.

  The IR is a pure data term. Sections are independently nil-able, the all-nil
  IR is legal (the pure-presentation dumb screen), :digest/:version are
  nil-or-string, and no module in this namespace carries an execute path.
  """

  @sections [:ash, :semantic, :capability, :presentation, :schema]

  defstruct [:version, :digest, :ash, :semantic, :capability, :presentation, :schema]

  @type section_key :: :ash | :semantic | :capability | :presentation | :schema
  @type t :: %__MODULE__{
          version: String.t() | nil,
          digest: String.t() | nil,
          ash: AshSurface.IRStructTest.IR.Ash.t() | nil,
          semantic: AshSurface.IRStructTest.IR.Semantic.t() | nil,
          capability: AshSurface.IRStructTest.IR.Capability.t() | nil,
          presentation: AshSurface.IRStructTest.IR.Presentation.t() | nil,
          schema: AshSurface.IRStructTest.IR.Schema.t() | nil
        }

  @doc "The canonical section keys in declaration order. Deterministic."
  @spec sections() :: [section_key()]
  def sections, do: @sections

  @doc """
  Deterministic accessor for one section.

  Returns the section struct, or `nil` when the section is absent. Non-section
  keys are refused deterministically with `FunctionClauseError`.
  """
  @spec section(t(), section_key()) :: struct() | nil
  def section(%__MODULE__{} = ir, key) when key in @sections,
    do: Map.fetch!(ir, key)

  @doc """
  Lawful constructor.

    * `:digest`/`:version` accept `nil` or a binary; anything else raises;
    * each section accepts `nil` or its matching struct; anything else raises;
    * the all-nil IR is legal: `IR.new()` == `%IR{}`.
  """
  @spec new(keyword()) :: t()
  def new(attrs \\ []) do
    %__MODULE__{
      version: nil_or_string!(Keyword.get(attrs, :version), :version),
      digest: nil_or_string!(Keyword.get(attrs, :digest), :digest),
      ash: section_struct!(AshSurface.IRStructTest.IR.Ash, Keyword.get(attrs, :ash)),
      semantic:
        section_struct!(AshSurface.IRStructTest.IR.Semantic, Keyword.get(attrs, :semantic)),
      capability:
        section_struct!(AshSurface.IRStructTest.IR.Capability, Keyword.get(attrs, :capability)),
      presentation:
        section_struct!(
          AshSurface.IRStructTest.IR.Presentation,
          Keyword.get(attrs, :presentation)
        ),
      schema: section_struct!(AshSurface.IRStructTest.IR.Schema, Keyword.get(attrs, :schema))
    }
  end

  defp nil_or_string!(nil, _key), do: nil
  defp nil_or_string!(value, _key) when is_binary(value), do: value

  defp nil_or_string!(value, key),
    do: raise(ArgumentError, "#{inspect(key)} must be nil or String.t(), got: #{inspect(value)}")

  defp section_struct!(_module, nil), do: nil
  defp section_struct!(module, %module{} = value), do: value

  defp section_struct!(module, value),
    do:
      raise(ArgumentError, "section must be nil or %#{inspect(module)}{}, got: #{inspect(value)}")
end

defmodule AshSurface.IRStructTest do
  @moduledoc """
  Deep IR-struct law of `AshSurface.IR` and its five embedded sections:

    * **independent nil-ability** -- every section is set or dropped on its
      own; presence of one never perturbs another;
    * **the all-nil IR is legal** -- a pure-presentation dumb screen exists
      with zero semantic facts;
    * **nil-or-string envelope** -- `:digest`/`:version` accept exactly `nil`
      or a binary, enforced at the constructor boundary;
    * **no execute path** -- a structural export check: each struct exports
      exactly its canonical field set and only its struct carrier functions,
      the IR exports only its pinned accessor set, and no exported name is in
      the execute family;
    * **deterministic accessors** -- `sections/0` is one fixed list on every
      call, `section/2` is a pure read, and non-section keys are refused
      deterministically.
  """

  use ExUnit.Case, async: true
  alias AshSurface.IRStructTest.IR

  @section_modules [
    AshSurface.IRStructTest.IR.Ash,
    AshSurface.IRStructTest.IR.Semantic,
    AshSurface.IRStructTest.IR.Capability,
    AshSurface.IRStructTest.IR.Presentation,
    AshSurface.IRStructTest.IR.Schema
  ]

  # The canonical field sets, pinned independently of the defstructs above so
  # a shape drift in either direction breaks this build.
  @canonical_fields %{
    AshSurface.IRStructTest.IR.Ash => [
      :resource,
      :action,
      :action_type,
      :inputs,
      :outputs,
      :policies
    ],
    AshSurface.IRStructTest.IR.Semantic => [
      :subject_iri,
      :capability_iri,
      :predicates,
      :shape_id,
      :ontology
    ],
    AshSurface.IRStructTest.IR.Capability => [
      :capability_id,
      :consequence_class,
      :authority_required,
      :receipt_required
    ],
    AshSurface.IRStructTest.IR.Presentation => [:label, :group, :order, :widget, :format],
    AshSurface.IRStructTest.IR.Schema => [:input, :output, :zod, :aria]
  }

  # The execute family: verbs that would make a data carrier actuable.
  @execute_family ~w(execute run dispatch invoke perform actuate call apply handle)a

  # Golden strings: verbatim carry is pinned, not just shape. The golden
  # version is the project version of this commit's mix.exs.
  @golden_digest String.duplicate("deadbeef", 16)
  @golden_version "26.9.13"

  defp section_fixture(:ash),
    do: %AshSurface.IRStructTest.IR.Ash{
      resource: "ZoeLedger.Entry",
      action: "record",
      action_type: :create,
      inputs: [%{"name" => "amount"}],
      outputs: [%{"name" => "id"}],
      policies: [%{"name" => "can_record"}]
    }

  defp section_fixture(:semantic),
    do: %AshSurface.IRStructTest.IR.Semantic{
      subject_iri: "https://zoela.example/needs",
      capability_iri: "https://zoela.example/capability#record_need",
      predicates: [%{"term" => "need"}],
      shape_id: "need_card_grid",
      ontology: "https://zoela.example/ontology"
    }

  defp section_fixture(:capability),
    do: %AshSurface.IRStructTest.IR.Capability{
      capability_id: "ZoeLedger.Entry#record",
      consequence_class: "COMPENSATABLE",
      authority_required: true,
      receipt_required: true
    }

  defp section_fixture(:presentation),
    do: %AshSurface.IRStructTest.IR.Presentation{
      label: "Record a need",
      group: "needs",
      order: 1,
      widget: "card",
      format: "grid"
    }

  defp section_fixture(:schema),
    do: %AshSurface.IRStructTest.IR.Schema{
      input: %{"fields" => 3},
      output: %{"fields" => 2},
      zod: %{"strict" => true},
      aria: %{"role" => "form"}
    }

  defp full_attrs, do: for(key <- IR.sections(), do: {key, section_fixture(key)})

  # Uniqued across arities: __struct__/0 and __struct__/1 are one name.
  defp exported_names(module),
    do: module.__info__(:functions) |> Enum.map(&elem(&1, 0)) |> Enum.uniq()

  defp field_keys(module),
    do: struct!(module) |> Map.from_struct() |> Map.keys()

  describe "canonical shape" do
    test "the section list is pinned in declaration order" do
      assert IR.sections() == [:ash, :semantic, :capability, :presentation, :schema]
    end

    test "each section struct carries exactly its canonical field set" do
      for module <- @section_modules do
        assert Enum.sort(field_keys(module)) == Enum.sort(@canonical_fields[module]),
               "#{inspect(module)} drifted from its canonical field set"
      end
    end

    test "every field of every bare section struct defaults to nil" do
      for module <- @section_modules do
        values = struct!(module) |> Map.from_struct() |> Map.values()

        assert Enum.uniq(values) == [nil],
               "#{inspect(module)} has a non-nil default: a section is born empty"
      end
    end

    test "the IR struct keyset is the pinned seven fields plus __struct__" do
      assert Enum.sort(Map.keys(%IR{})) ==
               [
                 :__struct__,
                 :ash,
                 :capability,
                 :digest,
                 :presentation,
                 :schema,
                 :semantic,
                 :version
               ]
    end

    test "every field of the bare IR defaults to nil" do
      assert %IR{}
             |> Map.from_struct()
             |> Map.values()
             |> Enum.uniq() == [nil]
    end
  end

  describe "every section is independently nil-able" do
    test "one section set, the other four stay nil -- for each of the five" do
      for key <- IR.sections() do
        ir = IR.new([{key, section_fixture(key)}])

        assert IR.section(ir, key) == section_fixture(key),
               "#{key}: expected its own fixture back"

        for other <- IR.sections() -- [key] do
          assert IR.section(ir, other) == nil, "#{other}: must stay nil when only #{key} is set"
        end

        assert ir.digest == nil
        assert ir.version == nil
      end
    end

    test "dropping any one section from a fully populated IR leaves the rest untouched" do
      attrs = full_attrs()

      for dropped <- IR.sections() do
        partial = IR.new(Keyword.drop(attrs, [dropped]))

        assert IR.section(partial, dropped) == nil

        for kept <- IR.sections() -- [dropped] do
          assert IR.section(partial, kept) == section_fixture(kept)
        end
      end
    end

    test "any single section may be explicitly nil in a fully-populated attrs list" do
      attrs = full_attrs()

      for key <- IR.sections() do
        ir = IR.new(Keyword.put(attrs, key, nil))
        assert IR.section(ir, key) == nil
      end
    end

    test "sections never coerce across keys: a foreign struct is refused, not re-homed" do
      assert_raise ArgumentError, ~r/AshSurface.IRStructTest.IR.Ash/, fn ->
        IR.new(semantic: section_fixture(:ash))
      end
    end

    test "section payloads survive verbatim: canonical fields round-trip unchanged" do
      for key <- IR.sections() do
        assert IR.section(IR.new([{key, section_fixture(key)}]), key) == section_fixture(key)
      end
    end
  end

  describe "the all-nil IR is legal (pure-presentation dumb screen)" do
    test "IR.new() constructs the all-nil IR and equals the bare struct" do
      assert IR.new() == %IR{}
    end

    test "reading every section of the all-nil IR yields nil, never raises" do
      empty = IR.new()

      for key <- IR.sections() do
        assert IR.section(empty, key) == nil
      end
    end

    test "a dumb screen exists: presentation-only IR carries no semantic or capability facts" do
      screen = IR.new(presentation: section_fixture(:presentation))

      assert IR.section(screen, :presentation) == %AshSurface.IRStructTest.IR.Presentation{
               label: "Record a need",
               group: "needs",
               order: 1,
               widget: "card",
               format: "grid"
             }

      for key <- IR.sections() -- [:presentation] do
        assert IR.section(screen, key) == nil
      end
    end

    test "the dumb screen is still digest/version-free until a projection stamps it" do
      screen = IR.new(presentation: section_fixture(:presentation))

      assert screen.digest == nil
      assert screen.version == nil
    end

    test "the bare struct itself (no constructor) is equally legal" do
      assert %IR{} == IR.new()
    end
  end

  describe "digest and version are nil-or-string" do
    test "nil round-trips as nil for both fields" do
      ir = IR.new(digest: nil, version: nil)

      assert ir.digest == nil
      assert ir.version == nil
    end

    test "strings round-trip verbatim (golden vectors)" do
      ir = IR.new(digest: @golden_digest, version: @golden_version)

      assert ir.digest == String.duplicate("deadbeef", 16)
      assert ir.version == "26.9.13"
    end

    test "the two envelope fields are independent: one string, one nil" do
      ir = IR.new(digest: @golden_digest)

      assert ir.digest == @golden_digest
      assert ir.version == nil

      ir2 = IR.new(version: @golden_version)

      assert ir2.digest == nil
      assert ir2.version == @golden_version
    end

    test "a non-string digest is refused with the field named" do
      assert_raise ArgumentError, ~r/:digest must be nil or String/, fn ->
        IR.new(digest: :sha256)
      end
    end

    test "a non-string version is refused with the field named" do
      assert_raise ArgumentError, ~r/:version must be nil or String/, fn ->
        IR.new(version: 27)
      end
    end

    test "refusal covers both sides of the envelope in one construction" do
      assert_raise ArgumentError, fn -> IR.new(digest: 64, version: :v1) end
    end

    test "empty binaries are legal strings, not coerced to nil" do
      ir = IR.new(digest: "", version: "")

      assert ir.digest == ""
      assert ir.version == ""
    end
  end

  describe "no section carries an execute path (structural export check)" do
    test "every section module exports only its data-carrier struct functions" do
      for module <- @section_modules do
        assert Enum.uniq(exported_names(module)) == [:__struct__],
               "#{inspect(module)} must export nothing beyond its struct carrier"
      end
    end

    test "the IR exports exactly the pinned carrier-and-accessor set" do
      assert Enum.sort(exported_names(IR)) == [:__struct__, :new, :section, :sections]
    end

    test "no exported name in the namespace is in the execute family" do
      for module <- [IR | @section_modules],
          name <- exported_names(module) do
        refute name in @execute_family,
               "#{inspect(module)}.#{name} is in the execute family"

        refute Atom.to_string(name) =~ "execute",
               "#{inspect(module)}.#{name} carries an execute path in its name"
      end
    end

    test "no struct field in the namespace is in the execute family" do
      for {module, _fields} <- @canonical_fields,
          field <- field_keys(module) do
        refute field in @execute_family,
               "#{inspect(module)}.#{field}: an execute-family field on a data carrier"
      end

      for field <- field_keys(IR) do
        refute field in @execute_family,
               "AshSurface.IR.#{field}: an execute-family field on the IR"
      end
    end

    test "the canonical field sets themselves contain no execute-family key" do
      for {module, fields} <- @canonical_fields do
        refute Enum.any?(fields, &(&1 in @execute_family)),
               "#{inspect(module)} canonical shape carries an execute path"
      end
    end
  end

  describe "section accessors are deterministic" do
    test "sections/0 returns one fixed list on every call" do
      lists = for _ <- 1..11, do: IR.sections()

      assert Enum.uniq(lists) == [IR.sections()]
    end

    test "section/2 repeated reads return identical terms for every key" do
      ir = IR.new(full_attrs())

      for key <- IR.sections() do
        reads = for _ <- 1..7, do: IR.section(ir, key)

        assert Enum.uniq(reads) == [section_fixture(key)]
      end
    end

    test "enumerating via sections/0 is order-stable across repeats (golden)" do
      ir = IR.new(full_attrs())
      golden = Enum.map(IR.sections(), &IR.section(ir, &1))

      assert golden == Enum.map(IR.sections(), &IR.section(ir, &1))

      assert match?(
               [
                 %AshSurface.IRStructTest.IR.Ash{},
                 %AshSurface.IRStructTest.IR.Semantic{},
                 %AshSurface.IRStructTest.IR.Capability{},
                 %AshSurface.IRStructTest.IR.Presentation{},
                 %AshSurface.IRStructTest.IR.Schema{}
               ],
               golden
             )
    end

    test "section/2 is a pure read: the IR is unchanged after full enumeration" do
      ir = IR.new(full_attrs())
      before = ir

      for key <- IR.sections(), do: IR.section(ir, key)

      assert ir == before
    end

    test "non-section keys are refused deterministically with FunctionClauseError" do
      for _ <- 1..3 do
        assert_raise FunctionClauseError, fn -> IR.section(%IR{}, :execute) end
        assert_raise FunctionClauseError, fn -> IR.section(%IR{}, "presentation") end
        assert_raise FunctionClauseError, fn -> IR.section(%IR{}, nil) end
      end
    end

    test "accessors stay deterministic on the all-nil IR too" do
      empty = IR.new()

      for key <- IR.sections() do
        reads = for _ <- 1..5, do: IR.section(empty, key)
        assert Enum.uniq(reads) == [nil]
      end
    end
  end
end
