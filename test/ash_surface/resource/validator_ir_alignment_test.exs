defmodule AshSurface.Resource.ValidatorIRAlignmentTest.Document do
  @moduledoc """
  Real inline Ash resource for the alignment law. Exact public action set:
  `[:create, :publish, :read]`. `:archive` is declared but `public?: false`,
  so it is outside BOTH paths' sets.
  """

  use Ash.Resource,
    domain: nil,
    data_layer: Ash.DataLayer.Simple

  attributes do
    uuid_primary_key(:id)
    attribute(:title, :string, public?: true, allow_nil?: false)
  end

  actions do
    defaults([:read, create: [:title]])
    update(:publish)
    destroy(:archive, public?: false)
  end
end

defmodule AshSurface.Resource.ValidatorIRAlignmentTest.RenamedDocument do
  @moduledoc """
  Real inline Ash resource whose `:fetch` action was renamed from
  `:legacy_fetch` (no longer declared anywhere). `:legacy_fetch` is pure
  rename residue: it must be refused by the validator and can never be
  emitted by the IR ash section for this resource.
  """

  use Ash.Resource,
    domain: nil,
    data_layer: Ash.DataLayer.Simple

  attributes do
    uuid_primary_key(:id)
    attribute(:title, :string, public?: true, allow_nil?: false)
  end

  actions do
    defaults([:read])
    update(:fetch)
  end
end

defmodule AshSurface.Resource.ValidatorIRAlignmentTest.IRAshSection do
  @moduledoc """
  MINIMAL LOCAL CONTRACT for the absent IR ash-section sibling
  (`AshSurface.Compiler.Ash.build/2` + `AshSurface.IR.Ash`): not present on
  this tree, so the alignment law declares the contract here instead.

  One truth, two consumers: the ash section's action set for a resource is
  EXACTLY the resource's public action set — the same truth the validator
  admits surface projections against (`Ash.Resource.Info.public_actions/1`).
  This stand-in binds to that single truth and invents nothing: no private
  actions, no renamed-in residue, no second application model.

  Contract shape (mirrors the sibling's admitted law):

    * `build/1` -> `{:ok, [facet]}` with one facet (a map carrying at least
      `:resource` and `:action`) per public action, or a typed
      `{:error, [%{code: _, detail: _}]}` refusal for non-Ash sources.
      The real sibling's `%IR.Ash{}` facets satisfy this contract because
      structs are maps carrying those keys.
    * `action_set/1` -> the sorted action-name list the ash section emits
      for the resource.

  INTEGRATION: when the sibling lands, this stand-in is DELETED, not
  reconciled — the tagged tests re-point at `AshSurface.Compiler.Ash.build/1`
  and drop their `:integration_pending` tags.
  """

  @spec build(module()) :: {:ok, [map()]} | {:error, [map()]}
  def build(resource) when is_atom(resource) do
    if Ash.Resource.Info.resource?(resource) do
      {:ok,
       Enum.map(Ash.Resource.Info.public_actions(resource), fn action ->
         %{resource: resource, action: action.name}
       end)}
    else
      {:error,
       [
         %{
           code: "not_an_ash_resource",
           detail:
             "ash section builds only from a compiled Ash resource, got #{inspect(resource)}"
         }
       ]}
    end
  end

  def build(source) do
    {:error,
     [
       %{
         code: "not_an_ash_resource",
         detail: "ash section builds only from a compiled Ash resource, got #{inspect(source)}"
       }
     ]}
  end

  @doc """
  Sorted action-name set the ash section emits for the resource. Fails
  closed: a refused build is a test failure, never an empty set.
  """
  @spec action_set(module()) :: [atom()]
  def action_set(resource) do
    {:ok, facets} = build(resource)
    facets |> Enum.map(& &1.action) |> Enum.sort()
  end
end

defmodule AshSurface.Resource.ValidatorIRAlignmentTest do
  @moduledoc """
  Admission alignment law (validator-ir-alignment-005): ONE truth, TWO
  consumers.

  The validator's admitted-projection set (the exact public action set that
  `AshSurface.Resource.Validator.validate/1` admits surface metadata
  against) must EQUAL the IR ash-section action set (the actions the
  compiler's ash section emits facets for) for the SAME resource:

    * same inline resource through both paths -> identical sorted lists
    * private actions excluded from both
    * rename residue refused by the validator -> never emitted by the
      ash section

  The IR ash-section sibling is ABSENT on this tree. Tests whose truth
  spans both consumers are `@tag :integration_pending`: they run green
  against the locally declared minimal contract above, and the tag records
  honestly that real-sibling convergence (re-pointing at
  `AshSurface.Compiler.Ash.build/1`) is still pending. Validator-side-only
  pins run untagged: that half of the law is present and alive now.
  """

  use ExUnit.Case, async: true

  alias AshSurface.Resource.Validator

  @document AshSurface.Resource.ValidatorIRAlignmentTest.Document
  @renamed AshSurface.Resource.ValidatorIRAlignmentTest.RenamedDocument
  @ir_ash_section AshSurface.Resource.ValidatorIRAlignmentTest.IRAshSection

  # The validator's admitted set, probed black-box through validate/1: a
  # single-action surface is :ok exactly when the action is in the exact
  # public action set. The probe universe is every declared action (public
  # and private), so exclusion is observed, never assumed.
  defp validator_admitted(resource) do
    resource
    |> action_universe()
    |> Enum.filter(&admitted?(resource, &1))
    |> Enum.sort()
  end

  defp validator_refused(resource) do
    resource
    |> action_universe()
    |> Enum.reject(&admitted?(resource, &1))
    |> Enum.sort()
  end

  defp action_universe(resource) do
    resource |> Ash.Resource.Info.actions() |> Enum.map(& &1.name)
  end

  defp admitted?(resource, action) do
    Validator.validate(%{resource: resource, surface: [%{action: action}]}) == :ok
  end

  describe "validator-side truth (present now, no sibling required)" do
    test "the admitted set is exactly the public action set, probed over every declared action" do
      assert action_universe(@document) |> Enum.sort() == [:archive, :create, :publish, :read]
      assert validator_admitted(@document) == [:create, :publish, :read]
      assert validator_refused(@document) == [:archive]
    end

    test "the private action is refused typed, not silently admitted" do
      assert {:error, [%{code: "unknown_action_projection", detail: detail}]} =
               Validator.validate(%{resource: @document, surface: [%{action: :archive}]})

      assert detail =~ "archive"
    end

    test "rename residue is refused typed under the stale name" do
      assert {:error, [%{code: "unknown_action_projection", detail: detail}]} =
               Validator.validate(%{resource: @renamed, surface: [%{action: :legacy_fetch}]})

      assert detail =~ "legacy_fetch"
      assert validator_admitted(@renamed) == [:fetch, :read]
      assert validator_refused(@renamed) == []
    end
  end

  describe "alignment with the IR ash section (declared minimal contract)" do
    @tag :integration_pending
    test "the same inline resource through both paths yields the identical sorted action list" do
      ir_set = @ir_ash_section.action_set(@document)
      validator_set = validator_admitted(@document)

      assert ir_set == [:create, :publish, :read]
      assert validator_set == [:create, :publish, :read]
      assert ir_set == validator_set
    end

    @tag :integration_pending
    test "private actions are excluded from both paths" do
      assert :archive in action_universe(@document)
      refute :archive in @ir_ash_section.action_set(@document)
      refute :archive in validator_admitted(@document)
    end

    @tag :integration_pending
    test "rename residue refused by the validator is never emitted by the ash section" do
      # The validator refuses the stale name (pinned untagged above)...
      assert :legacy_fetch in action_universe(@renamed) == false

      # ...so the ash section for the SAME resource cannot emit it, and the
      # disjoint law holds wholesale: every validator-refused name is absent
      # from the ash-section set.
      ir_set = @ir_ash_section.action_set(@renamed)
      refute :legacy_fetch in ir_set
      assert ir_set == [:fetch, :read]

      assert MapSet.disjoint?(
               MapSet.new(validator_refused(@renamed)),
               MapSet.new(ir_set)
             )
    end

    @tag :integration_pending
    test "alignment binds the SAME resource, never a global set" do
      # Cross-resource falsifier: the two resources have different public
      # action sets, so each path's per-resource sets must not cross-equal.
      assert @ir_ash_section.action_set(@renamed) != validator_admitted(@document)
      assert @ir_ash_section.action_set(@document) != validator_admitted(@renamed)

      # Both resources still self-align.
      assert @ir_ash_section.action_set(@document) == validator_admitted(@document)
      assert @ir_ash_section.action_set(@renamed) == validator_admitted(@renamed)
    end

    @tag :integration_pending
    test "the ash-section contract refuses non-Ash sources fail-closed with typed errors" do
      assert {:error, [%{code: "not_an_ash_resource", detail: detail}]} =
               @ir_ash_section.build("AshSurface.Resource.ValidatorIRAlignmentTest.Document")

      assert detail =~ "ash section builds only from a compiled Ash resource"

      assert {:error, [%{code: "not_an_ash_resource"}]} =
               @ir_ash_section.build(AshSurface.Resource.Validator)
    end
  end
end
