defmodule AshSurface.AiroSurfacePinW675Test do
  @moduledoc """
  Lane W675 AIRo-surface pin (v26.10.6 campaign). Companion to the W637 structural
  court (test/airo_risk_description_test.exs): where W637 pins the TTL file's shape,
  this court pins the TTL's *claims about the real modules* by calling them —
  Chicago-style, real collaborators, no mocks.

  Pinned cross-references:
    1. The TTL's StandingAdmission component claims lib/ash_surface/standing.ex
       (validate!/1, valid?/1, refused?/1, the open-prefixed REFUSED_* class) and
       lib/ash_surface/vocabulary.ex (refusal_code?/refusal_atom?, closed base
       standings). Pin each claim against real module calls.
    2. The VocabularyViolation hazard's risk control is the typed refusal class:
       bare :REFUSED / "REFUSED" / malformed codes are not standings.
    3. Every VIA-cited path in the TTL exists on disk (re-derived from the file,
       not a copy of the W637 list).
  """

  use ExUnit.Case, async: true

  @ttl_path Path.join([__DIR__, "..", "priv", "airo_risk_description.ttl"])

  setup do
    {:ok, ttl: File.read!(@ttl_path)}
  end

  test "TTL StandingAdmission claim: standing.ex admits base standings and raises on non-members", %{ttl: ttl} do
    assert ttl =~ "lib/ash_surface/standing.ex"

    for s <- AshSurface.Standing.base_standings() do
      assert AshSurface.Standing.valid?(s) == true
      assert AshSurface.Standing.validate!(s) == s
      assert AshSurface.Vocabulary.refusal_atom?(s) == false
      assert AshSurface.Standing.refused?(s) == false
    end

    assert AshSurface.Standing.validate!(:REFUSED_UNKNOWN_SUBJECT) == :REFUSED_UNKNOWN_SUBJECT

    assert_raise ArgumentError, ~r/not_a_standing_w675/, fn ->
      AshSurface.Standing.validate!(:not_a_standing_w675)
    end

    # :UNKNOWN is explicitly refused by validate!/1 with its own typed message.
    assert_raise ArgumentError, ~r/UNKNOWN/, fn ->
      AshSurface.Standing.validate!(:UNKNOWN)
    end
  end

  test "TTL StandingAdmission claim: vocabulary.ex REFUSED_* class matches the typed-refusal contract in the TTL prose", %{ttl: ttl} do
    assert ttl =~ "lib/ash_surface/vocabulary.ex"

    # Bare :REFUSED is not a standing (TTL VocabularyViolation hazard description).
    assert AshSurface.Vocabulary.refusal_code?("REFUSED") == false
    assert AshSurface.Vocabulary.refusal_code?("REFUSED_") == false
    assert AshSurface.Vocabulary.refusal_atom?(:REFUSED) == false

    # Well-formed typed refusals admitted; malformed ones rejected.
    assert AshSurface.Vocabulary.refusal_code?("REFUSED_NO_AUTHORITY") == true
    assert AshSurface.Vocabulary.refusal_code?("REFUSED_BAD CODE!") == false
    assert AshSurface.Vocabulary.refusal_atom?(:REFUSED_W675_PROBE) == true

    # The refusal prefix is exactly the open class named in the TTL.
    assert AshSurface.Vocabulary.refusal_prefix() == "REFUSED_"

    # Refusal atoms are valid standings and classified as refusals;
    # non-atom and boolean inputs are not standings at all.
    assert AshSurface.Standing.valid?(:REFUSED_W675_PROBE) == true
    assert AshSurface.Standing.refused?(:REFUSED_W675_PROBE) == true
    assert AshSurface.Standing.valid?(:not_a_standing_w675) == false
    assert AshSurface.Standing.valid?("REFUSED_NO_AUTHORITY") == false
    assert AshSurface.Standing.valid?(true) == false
  end

  test "VIA-cited paths re-derived from the TTL all exist on disk" do
    repo_root = Path.expand("..", __DIR__)
    content = File.read!(@ttl_path)

    cited =
      content
      |> then(&Regex.scan(~r/VIA (\S+)/, &1))
      |> Enum.map(&Enum.at(&1, 1))
      # Keep only path-shaped tokens; strip TTL-embedded punctuation (@en, quotes,
      # trailing sentence punctuation) before the existence check.
      |> Enum.filter(&String.contains?(&1, "/"))
      |> Enum.map(&String.replace(&1, ~r/["'(),;:.]+(@en)?$/, ""))
      |> Enum.reject(&(&1 == "" or not String.contains?(&1, "/")))
      |> Enum.uniq()

    assert cited != [], "no VIA citations found in the TTL — the pin has nothing to hold"

    missing =
      Enum.reject(cited, fn path ->
        File.exists?(Path.expand(path, repo_root))
      end)

    assert missing == [], "TTL cites paths that do not exist: #{inspect(missing)}"
  end
end
