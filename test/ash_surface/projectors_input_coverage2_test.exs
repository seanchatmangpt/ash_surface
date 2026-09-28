defmodule AshSurface.ProjectorsInputCoverage2Test do
  @moduledoc """
  Laws pinned: projectors fail closed at the input boundary - a non-IR element
  or an IR whose delegated facts are malformed is a typed refusal before any
  artifact is emitted; a list-form ARIA input without a usable name is refused
  loudly (never given an invented name); episodes that cannot be JSON encoded
  are a typed error and never a raise; non-serializable profile keys/values are typed refusals.
  """

  use ExUnit.Case, async: true

  alias AshSurface.{IR, MXEpisode}
  alias AshSurface.Projectors.{ARIA, JS}

  defp ir(opts \\ []) do
    IR.new(
      ash: %IR.Ash{
        resource: Keyword.get(opts, :resource, "Todo"),
        action: :create,
        action_type: :create
      },
      schema: %IR.Schema{aria: Keyword.get(opts, :aria)}
    )
  end

  describe "ARIA" do
    test "a non-IR element is refused as not_an_ir" do
      assert ARIA.project_ir([ir(), :nope]) == {:error, {:not_an_ir, :nope}}
    end

    test "an IR with an invalid fact is refused before emission" do
      assert ARIA.project_ir(ir(resource: 42)) == {:error, {:invalid_fact, :ash, :resource}}
    end

    test "a list-form input with a non-scalar name is refused" do
      assert_raise ArgumentError, ~r/unnamed list-form aria input/, fn ->
        ARIA.project_ir(ir(aria: %{"fields" => [%{"name" => [1]}]}))
      end
    end
  end

  describe "JS" do
    test "a non-IR element is refused as not_an_ir" do
      assert JS.project_ir([:nope]) == {:error, {:not_an_ir, :nope}}
    end

    test "an IR with an invalid fact is refused" do
      assert JS.project_ir(ir(resource: 42)) == {:error, {:invalid_fact, :ash, :resource}}
    end
  end

  describe "MXEpisode.verify/2" do
    test "an episode holding a non-encodable term is a typed error, not a raise" do
      assert {:error, {:episode_not_json_encodable, _}} = MXEpisode.verify(%{"pid" => self()})
    end
  end

  describe "from_manifest/2 profile normalisation" do
    test "a non-serializable profile key is a typed refusal" do
      assert AshSurface.from_manifest(%Ash.Info.Manifest{entrypoints: []}, profile: %{1 => :x}) ==
               {:error, {:profile_key_not_serializable, 1}}
    end

    test "a non-serializable profile value is a typed refusal" do
      assert AshSurface.from_manifest(%Ash.Info.Manifest{entrypoints: []},
               profile: %{"opaque" => {:a, 1}}
             ) == {:error, {:profile_value_not_serializable, {:a, 1}}}
    end
  end
end
