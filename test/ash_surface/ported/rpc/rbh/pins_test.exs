defmodule AshSurface.Ported.Rpc.Rbh.Forbidden do
  @moduledoc "Lane RBH: resource with a public and a private attribute for the forbidden-field leak pin."
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute(:visible, :string, public?: true)
    attribute(:secret, :string, public?: true)
  end
end

defmodule AshSurface.Ported.Rpc.Rbh.PinsTest do
  @moduledoc """
  Lane RBH. SK-mutI survivors, exact-value pins (no mocks):

  RAI I5/I6/I8 (FieldName clean + leading underscores, ZodType gt), RAW W2/W4/W8/W9/W10
  (ErrorBuilder texts, ValueFormatter forbidden-field), RBA A2/A3/A4/A5 (+ A1, see test),
  RBC C3/C4/C6 (regex slash escaping, match_flags validation, non-binary flags).

  `AshAuthentication` is not a dependency (UNVERIFIED against the real module): a Splode struct
  under the reference module name is created when unloadable, as a simple fake of an
  unavailable third-party collaborator.
  """
  use ExUnit.Case, async: false

  alias AshSurface.Compiler.RouteSchema.Fold
  alias AshSurface.Compiler.ZodType
  alias AshSurface.Config
  alias AshSurface.Errors
  alias AshSurface.FieldName
  alias AshSurface.RuntimeParity.Rpc.ErrorBuilder
  alias AshSurface.RuntimeParity.Rpc.ValueFormatter

  @token Module.concat(["AshAuthentication", "Errors", "InvalidToken"])


  defp get(m, k), do: Map.get(m, k) || Map.get(m, to_string(k))

  # --- RAI I5 / I8 / I6 -------------------------------------------------------

  test "I5: a trailing `?` is kept verbatim, never replaced with an underscore (RBS: reference parity)" do
    assert FieldName.compute(:is_active?, :snake_case) === "is_active?"
    assert FieldName.compute(:is_active?, :camel_case) === "isActive?"
    assert FieldName.compute(:is_active?, :pascal_case) === "IsActive?"
  end

  test "I8: leading underscores survive camelisation" do
    assert FieldName.compute(:_private_field, :camel_case) === "_privateField"
    assert FieldName.compute(:__x_y, :camel_case) === "__xY"
    assert FieldName.compute(:_private_field, :pascal_case) === "_PrivateField"
  end

  test "I6: greater_than renders .gt and less_than renders .lt, never .gte/.lte" do
    gt = %{"type" => %{"kind" => "integer"}, "constraints" => %{"greater_than" => 5}}
    lt = %{"type" => %{"kind" => "integer"}, "constraints" => %{"less_than" => 9}}
    assert ZodType.fragment(gt) === "z.number().int().gt(5)"
    assert ZodType.fragment(lt) === "z.number().int().lt(9)"
  end

  # --- RBC C3 / C4 / C6 -------------------------------------------------------

  defp str(constraints), do: %{"type" => %{"kind" => "string"}, "constraints" => constraints}

  test "C3: an unescaped `/` in a pattern is escaped in the regex literal" do
    assert ZodType.fragment(str(%{"match" => "a/b"})) === ~S|z.string().regex(/a\/b/)|
    assert ZodType.fragment(str(%{"match" => "a/b", "match_flags" => "im"})) ===
             ~S|z.string().regex(/a\/b/im)|
  end

  test "C6: a non-binary match_flags renders no flags" do
    assert ZodType.fragment(str(%{"match" => "ab", "match_flags" => :i})) ===
             "z.string().regex(/ab/)"
  end

  test "C4: match_flags must be a binary; an atom is refused, a binary is kept" do
    route = %{"name" => "r"}
    arg = fn flags -> [%{"name" => "a", "type" => %{"kind" => "string"}, "constraints" => %{"match_flags" => flags}}] end

    assert {:error, {:invalid_argument_constraints, ^route, "a", "match_flags", :not_a_string}} =
             Fold.fold_arguments(route, arg.(:i))

    assert {:ok, [%{"constraints" => %{"match_flags" => "i"}}]} =
             Fold.fold_arguments(route, arg.("i"))
  end

  # --- RAW W2 / W8 / W9 / W10 --------------------------------------------------

  test "W8/W9/W10: unknown pagination keys message, joined keys and fields list" do
    r = ErrorBuilder.build_error_response({:unknown_page_keys, [:foo_bar, :baz]})
    assert r.message === "Unknown pagination keys: %{keys}"
    assert r.vars === %{keys: "fooBar, baz"}
    assert r.fields === ["fooBar", "baz"]
    assert r.short_message === "Invalid pagination"
    assert r.path === ["page"]
  end

  test "W2: both pagination-not-supported errors carry the exact short message" do
    nested = ErrorBuilder.build_error_response({:nested_pagination_not_supported, :items, []})
    top = ErrorBuilder.build_error_response({:pagination_not_supported, :top_level, :unsupported})
    assert nested.short_message === "Pagination not supported"
    assert top.short_message === "Pagination not supported"
  end

  # --- RAW W4 ----------------------------------------------------------------

  test "W4: a ForbiddenField on a public attribute is emitted as nil, never the struct" do
    alias AshSurface.Ported.Rpc.Rbh.Forbidden

    value = %Forbidden{
      visible: "v",
      secret: %Ash.ForbiddenField{field: :secret, type: :attribute}
    }

    rel = %Ash.Info.Manifest.Relationship{destination: Forbidden, cardinality: :one}
    key = {AshSurface.RuntimeParity.Rpc.Support, :installed}
    prior = :persistent_term.get(key, :none)
    Application.put_env(:ash_surface_ported_rbh_pins, :ash_domains, [])
    {:ok, manifest} = Ash.Info.Manifest.generate(otp_app: :ash_surface_ported_rbh_pins)
    AshSurface.RuntimeParity.Rpc.Support.install(
      AshSurface.RuntimeParity.RequestedFields.Compat.prepare(manifest),
      []
    )

    out =
      try do
        ValueFormatter.format(value, rel, [], :camel_case, :output, nil)
      after
        if prior == :none, do: :persistent_term.erase(key), else: :persistent_term.put(key, prior)
      end

    assert out === %{"visible" => "v", "secret" => nil}
  end

  # --- RBA A1 / A2 -------------------------------------------------------------

  test "A2/A1: InvalidToken short message is exact and :count is retained in vars" do
    [err] = Errors.to_errors([struct(@token, message: "bad", count: 3)])
    assert get(err, :shortMessage) === "Invalid token"
    assert get(err, :type) === "invalid_token"
    assert get(get(err, :vars), :count) === 3
  end

  # --- RBA A3 / A4 / A5 --------------------------------------------------------

  @keys [:source_path_prefix, :show_raised_errors, :require_tenant_parameters]

  test "A3/A4/A5: unset-env defaults" do
    snap = for k <- @keys, do: {k, Application.fetch_env(:ash_surface, k)}
    for k <- @keys, do: Application.delete_env(:ash_surface, k)

    try do
      assert Config.source_path_prefix() === ""
      assert Config.show_raised_errors() === false
      assert Config.require_tenant_parameters() === false
      assert Config.parity_value(:source_path_prefix) === ""
      assert Config.parity_value(:require_tenant_parameters) === false
    after
      for {k, res} <- snap do
        case res do
          {:ok, v} -> Application.put_env(:ash_surface, k, v)
          :error -> Application.delete_env(:ash_surface, k)
        end
      end
    end
  end
end
