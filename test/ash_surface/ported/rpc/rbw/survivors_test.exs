defmodule AshSurface.Ported.Rpc.Rbw.PostResource do
  @moduledoc false
  use Ash.Resource,
    domain: AshSurface.Ported.Rpc.Rbw.Domain,
    data_layer: Ash.DataLayer.Ets,
    primary_read_warning?: false,
    extensions: [AshSurface.Resource]

  ets do
    private?(true)
  end

  surface do
    type_name("RbwPost")
  end

  attributes do
    uuid_primary_key(:id, public?: true)
    attribute(:short_title, :string, public?: true)
    attribute(:due_date, :string, public?: true)
  end

  actions do
    read :read do
      primary?(true)
    end
  end
end

defmodule AshSurface.Ported.Rpc.Rbw.AuthorResource do
  @moduledoc false
  use Ash.Resource,
    domain: AshSurface.Ported.Rpc.Rbw.Domain,
    data_layer: Ash.DataLayer.Ets,
    primary_read_warning?: false,
    extensions: [AshSurface.Resource]

  ets do
    private?(true)
  end

  surface do
    type_name("RbwAuthor")
  end

  attributes do
    uuid_primary_key(:id, public?: true)
    attribute(:full_name, :string, public?: true)
  end

  actions do
    read :read do
      primary?(true)
    end
  end
end

defmodule AshSurface.Ported.Rpc.Rbw.Domain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(AshSurface.Ported.Rpc.Rbw.PostResource)
    resource(AshSurface.Ported.Rpc.Rbw.AuthorResource)
  end
end

defmodule AshSurface.Ported.Rpc.Rbw.Fmt do
  @moduledoc false
  def two(field, a, b), do: "#{field}|#{a}|#{b}"
  def empty(_field), do: ""
end

defmodule AshSurface.Ported.Rpc.Rbw.SurvivorsTest do
  @moduledoc """
  Lane RBW. Own proof for skeptic survivors N2/N3 (scoped filter value recursion) and
  O1/O3/O4/O5 (errors + custom formatter). Real inline resources (lane RBN's) through the real
  parse pipeline; real Errors.to_errors; real FieldName.
  """
  use ExUnit.Case, async: false

  alias AshSurface.{Errors, FieldName}
  alias AshSurface.Ported.Rpc.Rbw.{AuthorResource, PostResource}
  alias AshSurface.Ported.Rpc.Rbw.Fmt
  alias AshSurface.RuntimeParity.RequestedFields.Compat
  alias AshSurface.RuntimeParity.Rpc.{Pipeline, Support}

  @otp_app :ash_surface_ported_rbw

  defp install do
    Application.put_env(@otp_app, :ash_domains, [AshSurface.Ported.Rpc.Rbw.Domain])
    {:ok, manifest} = Ash.Info.Manifest.generate(otp_app: @otp_app)

    Support.install(Compat.prepare(manifest), [
      Pipeline.entry(:list_posts, PostResource, :read),
      Pipeline.entry(:list_authors, AuthorResource, :read)
    ])
  end

  defp parse(f, params) do
    FieldName.with_formatter(f, fn ->
      install()
      Pipeline.parse_request(params, [])
    end)
  end

  @unknown {:error, {:unknown_field, :short_title, PostResource, []}}
  @id "id"

  test "N2: unknown spelling inside nested logical filter MAP value is refused" do
    for filter <- [
          %{"not" => %{"shortTitle" => %{"eq" => "x"}}},
          %{"not" => %{"not" => %{"shortTitle" => %{"eq" => "x"}}}},
          %{"or" => %{"and" => %{"shortTitle" => %{"eq" => "x"}}}}
        ] do
      assert @unknown =
               parse(:snake_case, %{
                 "action" => "list_posts",
                 "fields" => [@id],
                 "filter" => filter
               })
    end
  end

  test "N2: the scoped spelling inside the same nested map is accepted" do
    assert {:ok, _} =
             parse(:snake_case, %{
               "action" => "list_posts",
               "fields" => [@id],
               "filter" => %{"not" => %{"short_title" => %{"eq" => "x"}}}
             })
  end

  test "N3: unknown spelling inside a LIST filter value is refused" do
    for filter <- [
          %{"and" => [%{"shortTitle" => %{"eq" => "x"}}]},
          %{"or" => [%{"short_title" => %{"eq" => "x"}}, %{"shortTitle" => %{"eq" => "y"}}]},
          %{"not" => [%{"shortTitle" => %{"eq" => "x"}}]}
        ] do
      assert @unknown =
               parse(:snake_case, %{
                 "action" => "list_posts",
                 "fields" => [@id],
                 "filter" => filter
               })
    end

    assert {:ok, _} =
             parse(:snake_case, %{
               "action" => "list_posts",
               "fields" => [@id],
               "filter" => %{"and" => [%{"short_title" => %{"eq" => "x"}}]}
             })
  end

  test "O1: exposed unknown error carries short_message \"Unknown error\"" do
    err = Ash.Error.Unknown.UnknownError.exception(error: "kaboom")
    [out] = Errors.to_errors(err, show_raised_errors: true, formatter: :snake_case)
    assert out["short_message"] == "Unknown error"
    assert out["message"] == "kaboom"

    [raised] = Errors.to_errors(%RuntimeError{message: "boom"}, show_raised_errors: true, formatter: :snake_case)
    assert raised["short_message"] == "Unknown error"
    assert raised["message"] == "** (RuntimeError) boom"
  end

  test "O3: UnknownError with show_raised_errors false is hidden behind a generic id message" do
    err = Ash.Error.Unknown.UnknownError.exception(error: "secret-detail")
    [out] = Errors.to_errors(err, show_raised_errors: false, formatter: :snake_case)
    assert out["type"] == "unknown_error"
    assert out["short_message"] == "Unknown error"
    refute out["message"] =~ "secret-detail"
    assert out["message"] =~ ~r/^Something went wrong\. Unique error id: /
    assert is_binary(out["details"]["error_id"])
  end

  test "O4: arity-3 {m,f,[a,b]} receives (field, a, b) in that order" do
    assert FieldName.format(:x, {Fmt, :two, ["A", "B"]}) == "x|A|B"
    assert FieldName.format(:x, {Fmt, :two, ["B", "A"]}) == "x|B|A"
  end

  test "O5: empty-string custom formatter result is refused with the typed message" do
    e = assert_raise ArgumentError, fn -> FieldName.format(:x, {Fmt, :empty}) end
    assert e.message =~ "invalid_custom_formatter_result"
    assert e.message =~ "non-empty binary"
  end
end
