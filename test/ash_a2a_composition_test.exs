


defmodule AshA2A.DslCompositionTest do
  use ExUnit.Case, async: true

  @fixture_source """
  defmodule AshA2A.Dsl.CompositionFixture do
    use Ash.Resource,
      domain: nil,
      extensions: [AshA2A.Dsl]

    attributes do
      uuid_primary_key :id
    end
  end
  """


  # setup_all: the fixture module is compiled once per test module, not redefined per
  # test. Code.compile_string/1 returns every module the source defines -- an Ash
  # resource also defines protocol impls (Inspect.<Fixture>, ...) -- so the fixture is
  # looked up by its declared name, not by destructuring a one-element list.
  setup_all do
    fixture_module = AshA2A.Dsl.CompositionFixture
    true = Enum.any?(Code.compile_string(@fixture_source), &match?({^fixture_module, _}, &1))

    %{fixture: fixture_module}

  end

  test "the compiled fixture actually carries the AshA2A.Dsl extension", %{fixture: fixture} do
    assert AshA2A.Dsl in Spark.extensions(fixture)
  end

  test "AshA2A.Dsl.Info returns real, non-nil compiled state for the fixture", %{fixture: fixture} do
    refute is_nil(AshA2A.Dsl.Info.compiled(fixture))
  end



end
