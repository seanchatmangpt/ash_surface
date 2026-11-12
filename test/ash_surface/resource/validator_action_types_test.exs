defmodule AshSurface.Resource.ValidatorActionTypesTest.Account do
  @moduledoc false
  use Ash.Resource, domain: nil, data_layer: Ash.DataLayer.Simple

  attributes do
    uuid_primary_key(:id)
    attribute(:email, :string, public?: true, allow_nil?: false)
    attribute(:hidden, :string, public?: false)
  end

  identities do
    identity(:by_email, [:email])
  end

  actions do
    defaults([:read, create: [:email]])
    read(:internal_read, public?: false)
    read(:by_email_read, get_by: [:email])

    action :ping, :string do
      run(fn _input, _ctx -> {:ok, "pong"} end)
    end

    action :secret_ping, :string do
      public?(false)
      run(fn _input, _ctx -> {:ok, "shh"} end)
    end
  end
end

defmodule AshSurface.Resource.ValidatorActionTypesTest do
  @moduledoc """
  Port of ash_typescript `verify_action_types/*`, `verify_rpc_public_actions_test`
  and `verify_metadata_field_names_test` against the REAL
  `AshSurface.Resource.Validator` and the real Spark verifier.

  Divergences from ash_typescript (pinned, not hidden):

    * ash_typescript's `verify_action_types/*` field-name verification is implemented by
      `AshSurface.Resource.Verifiers.ActionTypeFieldNames` (code
      `invalid_action_type_field_names`) and ported in
      test/ash_surface/ported/manifest/verify_action_types_*_surface_test.exs.
    * `show_metadata` / `metadata_field_names` are validated by the resource validator
      (explicit court: test/ash_surface/verifiers/g3_verifiers_test.exs).
  """
  use ExUnit.Case, async: true

  alias AshSurface.Resource.Validator

  @account AshSurface.Resource.ValidatorActionTypesTest.Account

  defp validate(projections),
    do: Validator.validate(%{resource: @account, surface: projections})

  defp codes(projections) do
    case validate(projections) do
      :ok -> []
      {:error, refusals} -> Enum.map(refusals, & &1.code)
    end
  end

  describe "public action set (verify_rpc_public_actions)" do
    test "public generic action is admitted, private generic action is refused" do
      assert [] == codes([%{action: :ping}])
      assert ["unknown_action_projection"] == codes([%{action: :secret_ping}])
    end

    test "private read action is refused as a projection target" do
      assert ["unknown_action_projection"] == codes([%{action: :internal_read}])
    end

    test "refusal detail names the exact sorted public action set" do
      {:error, [refusal]} = validate([%{action: :secret_ping}])

      assert refusal.detail =~ ":secret_ping"
      assert refusal.detail =~ "[:by_email_read, :create, :ping, :read]"
      refute refusal.detail =~ ":internal_read"
    end

    test "every admitted public action of each type projects cleanly" do
      for name <- [:read, :create, :ping, :by_email_read] do
        assert [] == codes([%{action: name}]), "expected #{name} admitted"
      end
    end
  end

  describe "read_action must be a public read action (action type verification)" do
    test "public read admitted" do
      assert [] == codes([%{action: :read, read_action: :by_email_read}])
    end

    test "private read, create, generic and unknown actions are refused" do
      for name <- [:internal_read, :create, :ping, :nope] do
        assert ["read_action_not_public_read"] ==
                 codes([%{action: :read, read_action: name}]),
               "expected #{name} refused as read_action"
      end
    end
  end

  describe "get_by / identities against attribute and identity facts" do
    test "private attribute and unknown attribute refused, public admitted" do
      assert ["get_by_not_public_attribute"] == codes([%{action: :read, get_by: [:hidden]}])
      assert ["get_by_not_public_attribute"] == codes([%{action: :read, get_by: [:ghost]}])
      assert [] == codes([%{action: :read, get_by: [:email]}])
    end

    test "each bad get_by field yields its own refusal" do
      assert ["get_by_not_public_attribute", "get_by_not_public_attribute"] ==
               codes([%{action: :read, get_by: [:hidden, :ghost]}])
    end

    test "known identity admitted, unknown refused" do
      assert [] == codes([%{action: :read, identities: [:by_email]}])
      assert ["unknown_identity_projection"] == codes([%{action: :read, identities: [:ghost]}])
    end

    test "independent violations on one projection are all reported" do
      result =
        codes([
          %{
            action: :read,
            get?: true,
            get_by: [:hidden],
            identities: [:ghost],
            read_action: :create,
            allowed_loads: [:a],
            denied_loads: [:b]
          }
        ])

      for code <- ~w(get_and_get_by_conflict allowed_and_denied_loads_conflict
                     unknown_identity_projection get_by_not_public_attribute
                     read_action_not_public_read) do
        assert code in result
      end
    end

    test "empty loads lists do not count as declared (no conflict)" do
      # Account has no loadable fields, so `:a` is also an invalid load path (T12 load-path
      # law); the property under test is that an empty list never raises the conflict.
      refute "allowed_and_denied_loads_conflict" in codes([
               %{action: :read, allowed_loads: [], denied_loads: [:a]}
             ])

      refute "allowed_and_denied_loads_conflict" in codes([
               %{action: :read, allowed_loads: [:a], denied_loads: []}
             ])
    end
  end

  describe "projection names (metadata/wire-name uniqueness)" do
    test "duplicate projection names across actions are refused once, sorted" do
      assert ["duplicate_projection_name"] ==
               codes([%{action: :read, name: :list}, %{action: :ping, name: :list}])
    end

    test "distinct and nil names pass" do
      assert [] ==
               codes([
                 %{action: :read, name: :a},
                 %{action: :ping, name: :b},
                 %{action: :create},
                 %{action: :by_email_read}
               ])
    end
  end

  describe "metadata options (verify_metadata_field_names)" do
    test "unknown show_metadata / metadata_field_names are refused by the resource validator" do
      assert ["unknown_show_metadata", "invalid_metadata_field_names"] ==
               codes([
                 %{
                   action: :read,
                   show_metadata: [:not_a_real_metadata_field],
                   metadata_field_names: [not_a_real_metadata_field: "ok"]
                 }
               ])

      assert [] == codes([%{action: :read, show_metadata: false}])
    end
  end

  describe "real Spark verifier path" do
    # Persist stores :resource, so Validator admission runs against the real public
    # action set. Spark 2.7.3 reports verifier errors as a compile warning (stderr).
    defp compile(body) do
      name =
        "AshSurface.Resource.ValidatorActionTypesTest.Dyn#{System.unique_integer([:positive])}"

      source = """
      defmodule #{name} do
        use Ash.Resource, domain: nil, data_layer: Ash.DataLayer.Simple,
          extensions: [AshSurface.Resource]

        attributes do
          uuid_primary_key :id
        end

        actions do
          defaults [:read]
        end

        #{body}
      end
      """

      stderr =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          send(self(), {:compiled, Code.compile_string(source)})
        end)

      assert_received {:compiled, modules}
      {module, _} = Enum.find(modules, fn {m, _} -> Atom.to_string(m) == "Elixir." <> name end)
      {module, stderr}
    end

    test "persisted compiled state carries projections and the :resource module (re-pinned: Persist now stores it)" do
      {module, _stderr} = compile("surface do\n projection :read\n end")
      compiled = AshSurface.Resource.Info.compiled!(module)
      assert [%{action: :read}] = compiled.surface
      assert compiled.resource == module
    end

    test "a VALID projection compiles with no verifier warning (re-pinned: Persist stores :resource)" do
      {_module, stderr} = compile("surface do\n projection :read\n end")
      refute stderr =~ "invalid_surface_compilation"
    end

    test "invalid projections are refused through the real Spark verifier (warning carries typed codes)" do
      {_m, stderr} = compile("surface do\n projection :nope\n end")
      assert stderr =~ "unknown_action_projection"
      refute stderr =~ "invalid_surface_compilation"

      {_m, stderr} =
        compile("surface do\n projection :read, get_by: [:ghost]\n end")

      assert stderr =~ "get_by_not_public_attribute"

      {_m, stderr} =
        compile("surface do\n projection :read, read_action: :nope\n end")

      assert stderr =~ "read_action_not_public_read"

      {_m, stderr} =
        compile("surface do\n projection :read, name: :a\n projection :read, name: :a\n end")

      assert stderr =~ "duplicate_action_projection"
    end

    test "a resource with no projections compiles with no verifier warning" do
      {module, stderr} = compile("")
      refute stderr =~ "invalid_surface_compilation"
      assert AshSurface.Resource.Info.compiled!(module).surface == []
    end
  end
end
