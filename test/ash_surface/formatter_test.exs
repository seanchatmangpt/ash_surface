defmodule AshSurface.FormatterTest do
  # async: false — the DSL delegation test mutates the global :spark formatter app env.
  use ExUnit.Case, async: false

  alias AshSurface.Formatter

  @messy_module """
  defmodule MyApp.Consumer do
    use    AshSurface.Resource
    def   greet( name ),do:  "hi " <> name
  end
  """

  @golden_module """
  defmodule MyApp.Consumer do
    use AshSurface.Resource
    def greet(name), do: "hi " <> name
  end
  """

  @messy_expression "def f( a,b ), do: a+b"
  @golden_expression "def f(a, b), do: a + b\n"

  @garbage_samples [
    "defmodule << broken",
    "( unclosed"
  ]

  @idempotence_corpus [
                        @messy_module,
                        @messy_expression,
                        @golden_module,
                        @golden_expression,
                        "\n",
                        "   \n\n  "
                      ] ++ @garbage_samples

  describe "extensions/0" do
    test "registers the manufactured AshSurface DSL extension" do
      assert Formatter.extensions() == [AshSurface.Resource]
    end
  end

  describe "features/1" do
    test "declares the plugin's file extensions regardless of opts" do
      assert Formatter.features([]) == [extensions: [".ex", ".exs"]]
      assert Formatter.features(nil) == [extensions: [".ex", ".exs"]]

      assert Formatter.features(file: "lib/foo.ex", line: 1) == [
               extensions: [".ex", ".exs"]
             ]
    end
  end

  describe "format/2" do
    test "formats a real consumer module to its canonical display form" do
      assert Formatter.format(@messy_module, []) == @golden_module
    end

    test "formats plain expression code to its canonical display form" do
      assert Formatter.format(@messy_expression, []) == @golden_expression
    end

    test "is deterministic: identical input yields byte-identical output" do
      outputs = for _ <- 1..25, do: Formatter.format(@messy_module, [])

      assert Enum.uniq(outputs) == [@golden_module]
    end

    test "is idempotent: format(format(input)) == format(input)" do
      for input <- @idempotence_corpus do
        once = Formatter.format(input, [])
        assert Formatter.format(once, []) == once
      end
    end

    test "returns a single newline for empty and whitespace-only input" do
      assert Formatter.format("", []) == "\n"
      assert Formatter.format("\n", []) == "\n"
      assert Formatter.format("   \n\n  ", []) == "\n"
    end

    test "passes unparseable input through byte-identical without raising" do
      for garbage <- @garbage_samples do
        assert Formatter.format(garbage, []) == garbage
      end
    end

    test "accepts opts with and without a :spark keyword and merges extensions" do
      assert Formatter.format(@messy_expression, spark: [extensions: [Some.Other.Dsl]]) ==
               @golden_expression

      assert Formatter.format(@messy_expression, spark: [remove_parens?: true]) ==
               @golden_expression

      assert Formatter.format(@messy_expression, file: "consumer.ex", line: 3) ==
               @golden_expression
    end
  end

  describe "format/2 DSL delegation" do
    setup do
      Application.put_env(:spark, :formatter,
        "ProbeSurface.Base": [
          extensions: [ProbeSurfaceExt],
          section_order: [:events, :manifest, :projections]
        ]
      )

      on_exit(fn -> Application.delete_env(:spark, :formatter) end)
    end

    @dsl_source """
    defmodule MyApp.Surface do
      use ProbeSurface.Base

      def identity(x), do: x

      projections do
      end

      manifest do
      end

      events do
      end
    end
    """

    @golden_dsl """
    defmodule MyApp.Surface do
      use ProbeSurface.Base

      def identity(x), do: x

      events do
      end

      manifest do
      end

      projections do
      end
    end
    """

    test "reorders manifest/projections/events sections to the configured display order" do
      assert Formatter.format(@dsl_source, []) == @golden_dsl
    end

    test "preserves non-section code while reordering" do
      output = Formatter.format(@dsl_source, [])
      assert output =~ "def identity(x), do: x"
      assert output =~ "use ProbeSurface.Base"
    end

    test "DSL reordering is deterministic and idempotent" do
      once = Formatter.format(@dsl_source, [])
      assert once == @golden_dsl
      assert Formatter.format(once, []) == once
      assert Formatter.format(@dsl_source, []) == once
    end
  end
end

# A "base" that could be `use`d instead of the DSL itself; it exists only so
# Spark.Formatter can resolve its default extensions without warnings.
defmodule ProbeSurface.Base do
  def default_extensions, do: []
end

# Minimal real section set for the formatter: the three AshSurface surface
# concerns, declared in their canonical order.
defmodule ProbeSurfaceExt do
  def sections do
    [
      %Spark.Dsl.Section{name: :manifest, entities: []},
      %Spark.Dsl.Section{name: :projections, entities: []},
      %Spark.Dsl.Section{name: :events, entities: []}
    ]
  end

  def add_extensions, do: []
end
