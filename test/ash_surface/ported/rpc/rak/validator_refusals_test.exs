defmodule AshSurface.Ported.Rpc.Rak.ValidatorRefusalsTest do
  @moduledoc """
  Lane RAK. Exact-value court over `AshSurface.Resource.Validator.validate/1`: duplicate
  projection refusals, transport/offline kind refusals, admission (unknown / non-public action)
  and typed-query kind/name refusals. Real inline Ash resource; the validator is pure.
  """
  use ExUnit.Case, async: true

  alias AshSurface.Dsl.TypedQuery
  alias AshSurface.Resource.Validator

  setup_all do
    name = "Elixir.AshSurface.Ported.Rak.V#{System.unique_integer([:positive])}"

    ExUnit.CaptureIO.capture_io(:stderr, fn ->
      Code.compile_string("""
      defmodule #{name} do
        use Ash.Resource, domain: nil, data_layer: Ash.DataLayer.Simple,
          validate_domain_inclusion?: false
        attributes do
          uuid_primary_key :id, public?: true
          attribute :title, :string, public?: true
        end
        actions do
          read :read, primary?: true
          read :hidden, public?: false
          create :create do
            accept [:title]
          end
        end
      end
      """)
    end)

    %{resource: String.to_existing_atom(name)}
  end

  defp compiled(resource, entities), do: %{resource: resource, surface: entities}
  defp proj(action, extra \\ []), do: Map.merge(%{action: action}, Map.new(extra))

  defp codes({:error, refusals}), do: Enum.map(refusals, & &1.code)

  test "valid projections are admitted", %{resource: r} do
    assert Validator.validate(compiled(r, [proj(:read, transport: :http, offline: :cache_last)])) ==
             :ok
  end

  test "duplicate action projection is refused with the action named", %{resource: r} do
    assert {:error, [refusal]} = Validator.validate(compiled(r, [proj(:read), proj(:read)]))
    assert refusal.code == "duplicate_action_projection"
    assert refusal.detail =~ ":read"
    assert refusal.detail =~ "more than once"
  end

  test "each duplicated action yields exactly one refusal, sorted", %{resource: r} do
    result =
      Validator.validate(
        compiled(r, [proj(:create), proj(:read), proj(:create), proj(:read), proj(:read)])
      )

    assert {:error, refusals} = result
    assert Enum.map(refusals, & &1.code) == List.duplicate("duplicate_action_projection", 2)
    assert Enum.map(refusals, & &1.detail =~ ":create") == [true, false]
  end

  test "unknown action is refused as not in the public set", %{resource: r} do
    assert {:error, [refusal]} = Validator.validate(compiled(r, [proj(:nope)]))
    assert refusal.code == "unknown_action_projection"
    assert refusal.detail =~ ":nope"
    assert refusal.detail =~ "not in the exact public action set [:create, :read]"
  end

  test "multiple unknown actions are refused in action-sorted order, not input order",
       %{resource: r} do
    assert {:error, refusals} =
             Validator.validate(compiled(r, [proj(:zeta), proj(:alpha), proj(:mid)]))

    assert Enum.map(refusals, & &1.code) == List.duplicate("unknown_action_projection", 3)
    assert Enum.map(refusals, &(&1.detail =~ ":alpha")) == [true, false, false]
    assert Enum.map(refusals, &(&1.detail =~ ":mid")) == [false, true, false]
    assert Enum.map(refusals, &(&1.detail =~ ":zeta")) == [false, false, true]
  end

  test "non-public action is refused as not public?", %{resource: r} do
    assert {:error, [refusal]} = Validator.validate(compiled(r, [proj(:hidden)]))
    assert refusal.code == "unknown_action_projection"
    assert refusal.detail =~ "is not `public?`"
  end

  test "unknown transport is refused, admitted ones are not", %{resource: r} do
    assert {:error, [refusal]} = Validator.validate(compiled(r, [proj(:read, transport: :smtp)]))
    assert refusal.code == "unknown_transport_projection"
    assert refusal.detail =~ ":smtp"
    assert refusal.detail =~ "[:auto, :http, :phoenix_channel]"

    for t <- [:auto, :http, :phoenix_channel] do
      assert Validator.validate(compiled(r, [proj(:read, transport: t)])) == :ok
    end
  end

  test "unknown offline class is refused, admitted ones are not", %{resource: r} do
    assert {:error, [refusal]} = Validator.validate(compiled(r, [proj(:read, offline: :always)]))
    assert refusal.code == "unknown_offline_class_projection"
    assert refusal.detail =~ ":always"
    assert refusal.detail =~ "[:online_only, :cache_last, :queue_reconcile]"

    for o <- [:online_only, :cache_last, :queue_reconcile] do
      assert Validator.validate(compiled(r, [proj(:read, offline: o)])) == :ok
    end
  end

  test "transport and offline refusals accumulate", %{resource: r} do
    result = Validator.validate(compiled(r, [proj(:read, transport: :x, offline: :y)]))

    assert codes(result) == ["unknown_transport_projection", "unknown_offline_class_projection"]
  end

  test "typed query naming refusals", %{resource: r} do
    tq = fn name, action -> %TypedQuery{name: name, action: action, fields: []} end

    assert codes(Validator.validate(compiled(r, [tq.(:Bad_Name, :read)]))) ==
             ["typed_query_invalid_name"]

    assert codes(Validator.validate(compiled(r, [tq.(:q, :read), tq.(:q, :read)]))) ==
             ["typed_query_duplicate_name"]
  end

  test "typed query action kind refusals", %{resource: r} do
    tq = fn action -> %TypedQuery{name: :q, action: action, fields: []} end

    assert codes(Validator.validate(compiled(r, [tq.(:create)]))) ==
             ["typed_query_non_read_action"]

    assert codes(Validator.validate(compiled(r, [tq.(:hidden)]))) ==
             ["typed_query_unknown_action"]

    assert codes(Validator.validate(compiled(r, [tq.(:missing)]))) ==
             ["typed_query_unknown_action"]
  end

  test "malformed compilation is refused with invalid_surface_compilation" do
    assert {:error, [%{code: "invalid_surface_compilation"}]} = Validator.validate(%{})

    assert {:error, [%{code: "invalid_surface_compilation"}]} =
             Validator.validate(%{surface: [%{action: "read"}]})
  end
end
