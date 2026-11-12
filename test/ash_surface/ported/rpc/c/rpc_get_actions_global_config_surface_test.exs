defmodule AshSurface.Ported.Rpc.C.RpcGetActionsGlobalConfigSurfaceTest do
  @moduledoc """
  Adaptation of the reference `not_found_error? global config` describe (3 tests).

  The reference decides at execution whether a missing record becomes `null` or a not_found
  error. ash_surface never actuates, so the decision is the compile-time IR fact
  `not_found_error?` (`AshSurface.Compiler.ResourceFacts`), which the Zod inference reads. The
  precedence under test is identical: an explicit projection option wins over the global
  `:not_found_error?` config; with no projection declared the global config is the default.
  Real inline Spark resources, real `Application` env (restored after each test), no mocks.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Compiler.ResourceFacts

  @body """
  attributes do
    uuid_primary_key :id, public?: true
    attribute :email, :string, public?: true, allow_nil?: false
  end
  actions do
    read :by_email do
      get_by :email
    end
    read :list_all
  end
  """

  defp compile_resource(surface) do
    name = "Elixir.AshSurface.Ported.GU10.R#{System.unique_integer([:positive])}"

    ExUnit.CaptureIO.capture_io(:stderr, fn ->
      Code.compile_string("""
      defmodule #{name} do
        use Ash.Resource, domain: nil, data_layer: Ash.DataLayer.Simple,
          validate_domain_inclusion?: false, extensions: [AshSurface.Resource]
        #{@body}
        surface do
          #{surface}
        end
      end
      """)
    end)

    String.to_existing_atom(name)
  end

  defp with_env(key, value, fun) do
    prev = Application.fetch_env(:ash_surface, key)
    Application.put_env(:ash_surface, key, value)

    try do
      fun.()
    after
      case prev do
        {:ok, v} -> Application.put_env(:ash_surface, key, v)
        :error -> Application.delete_env(:ash_surface, key)
      end
    end
  end

  setup_all do
    no_projection = compile_resource("")

    explicit_true =
      compile_resource("projection :by_email, get_by: [:email], not_found_error?: true")

    explicit_false =
      compile_resource("projection :by_email, get_by: [:email], not_found_error?: false")

    default_opts = compile_resource("projection :by_email, get_by: [:email]")
    list_only = compile_resource("projection :list_all")

    %{
      none: no_projection,
      yes: explicit_true,
      no: explicit_false,
      dflt: default_opts,
      list: list_only
    }
  end

  defp fact(resource),
    do:
      ResourceFacts.build(resource, Ash.Resource.Info.action(resource, :by_email)).not_found_error?

  test "global config false makes default behavior return null", %{none: none} do
    assert with_env(:not_found_error?, true, fn -> fact(none) end) == true
    assert with_env(:not_found_error?, false, fn -> fact(none) end) == false
  end

  test "explicit action config overrides global config false", %{yes: yes} do
    assert with_env(:not_found_error?, false, fn -> fact(yes) end) == true
  end

  test "explicit action config false overrides global config true", %{no: no} do
    assert with_env(:not_found_error?, true, fn -> fact(no) end) == false
  end

  describe "fact shape under the global config (mutation-killing)" do
    test "a declared projection without the option uses its DSL default, not the global", %{
      dflt: dflt
    } do
      assert with_env(:not_found_error?, false, fn -> fact(dflt) end) == true
      assert with_env(:not_found_error?, true, fn -> fact(dflt) end) == true
    end

    test "non-get actions carry no not_found_error? fact whatever the global says", %{
      list: list,
      none: none
    } do
      for flag <- [true, false] do
        with_env(:not_found_error?, flag, fn ->
          assert ResourceFacts.build(list, Ash.Resource.Info.action(list, :list_all)).not_found_error? ==
                   nil

          assert ResourceFacts.build(none, Ash.Resource.Info.action(none, :list_all)).not_found_error? ==
                   nil
        end)
      end
    end

    test "get facts: get? true with the email lookup key, both with and without projection", %{
      none: none,
      yes: yes
    } do
      for r <- [none, yes] do
        facts = ResourceFacts.build(r, Ash.Resource.Info.action(r, :by_email))
        assert facts.get? == true
        assert facts.get_by == ["email"]
        assert length(facts.get_by_keys) == 1
      end

      list = ResourceFacts.build(none, Ash.Resource.Info.action(none, :list_all))
      assert list.get? == false
      assert list.get_by == []
      assert list.get_by_keys == []
    end

    test "projection presence is recorded in unknown_reasons", %{none: none, yes: yes} do
      by = &ResourceFacts.build(&1, Ash.Resource.Info.action(&1, :by_email)).unknown_reasons
      assert by.(none)["projection"] == "no_surface_projection"
      refute Map.has_key?(by.(yes), "projection")
    end

    test "the Config accessor itself defaults true and follows the env" do
      assert with_env(:not_found_error?, true, &AshSurface.Config.not_found_error?/0) == true
      assert with_env(:not_found_error?, false, &AshSurface.Config.not_found_error?/0) == false
    end

    test "the Zod inference result gains | null only when not_found_error? is false" do
      spec = fn flag ->
        AshSurface.Projectors.JS.Inference.action_types(%{
          name: "GetUser",
          schema: "UserSchema",
          kind: :get,
          not_found_error?: flag
        })
      end

      refute inspect(spec.(true)) =~ "| null"
      assert inspect(spec.(false)) =~ "| null"
    end
  end
end
