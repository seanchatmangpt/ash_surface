defmodule AshSurface.Ported.Rpc.Rbn.PostResource do
  @moduledoc "Lane RBN inline resource: multi-word attributes, mapped argument, calculation."
  use Ash.Resource,
    domain: AshSurface.Ported.Rpc.Rbn.Domain,
    data_layer: Ash.DataLayer.Ets,
    primary_read_warning?: false,
    extensions: [AshSurface.Resource]

  ets do
    private?(true)
  end

  surface do
    type_name("RbnPost")
    argument_names(search: [is_open?: "q"])
  end

  attributes do
    uuid_primary_key(:id, public?: true)
    attribute(:short_title, :string, public?: true)
    attribute(:due_date, :string, public?: true)
    attribute(:author_id, :uuid, public?: true)
  end

  actions do
    read :read do
      primary?(true)
    end

    read :search do
      argument(:is_open?, :boolean)
      argument(:other_arg, :string)
    end
  end
end

defmodule AshSurface.Ported.Rpc.Rbn.AuthorResource do
  @moduledoc false
  use Ash.Resource,
    domain: AshSurface.Ported.Rpc.Rbn.Domain,
    data_layer: Ash.DataLayer.Ets,
    primary_read_warning?: false,
    extensions: [AshSurface.Resource]

  ets do
    private?(true)
  end

  surface do
    type_name("RbnAuthor")
  end

  attributes do
    uuid_primary_key(:id, public?: true)
    attribute(:full_name, :string, public?: true)
  end

  relationships do
    has_many(:posts, AshSurface.Ported.Rpc.Rbn.PostResource,
      destination_attribute: :author_id,
      public?: true
    )
  end

  actions do
    read :read do
      primary?(true)
    end
  end
end

defmodule AshSurface.Ported.Rpc.Rbn.Domain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(AshSurface.Ported.Rpc.Rbn.PostResource)
    resource(AshSurface.Ported.Rpc.Rbn.AuthorResource)
  end
end

defmodule AshSurface.Ported.Rpc.Rbn.ScopedSpellingSurvivorsTest do
  @moduledoc """
  Lane RBN. Direct courts for skeptic survivors E1/E2/E4/E5 (pipeline scoped-spelling guard) and
  E6 (equivalence trace in the receipt). Real inline resources through the real parse pipeline.
  """
  use ExUnit.Case, async: false

  alias AshSurface.FieldName
  alias AshSurface.Ported.Rpc.Rbn.{AuthorResource, PostResource}
  alias AshSurface.RuntimeParity.RequestedFields.Compat
  alias AshSurface.RuntimeParity.Rpc.{Pipeline, Support}

  @otp_app :ash_surface_ported_rbn
  @formatters [:camel_case, :snake_case, :pascal_case]

  defp install do
    Application.put_env(@otp_app, :ash_domains, [AshSurface.Ported.Rpc.Rbn.Domain])
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

  # The spelling of :short_title under a formatter that is NOT `f` (the Config default is camel).
  defp wrong(:snake_case), do: "shortTitle"
  defp wrong(:pascal_case), do: "shortTitle"
  defp wrong(:camel_case), do: nil

  for f <- @formatters do
    test "E1/E2: scoped spelling accepted, config spelling refused under #{f}" do
      ok = FieldName.compute(:short_title, unquote(f))

      assert {:ok, _} =
               parse(unquote(f), %{"action" => "list_posts", "fields" => [ok]})

      if bad = wrong(unquote(f)) do
        assert {:error, {:unknown_field, :short_title, PostResource, []}} =
                 parse(unquote(f), %{"action" => "list_posts", "fields" => [bad]})

        assert {:error, {:unknown_field, :short_title, PostResource, []}} =
                 parse(unquote(f), %{
                   "action" => "list_posts",
                   "fields" => [ok],
                   "filter" => %{bad => %{"eq" => "x"}}
                 })
      end
    end

    test "E4: comma-separated sort list checks every element under #{f}" do
      ok = FieldName.compute(:due_date, unquote(f))

      assert {:ok, _} =
               parse(unquote(f), %{
                 "action" => "list_posts",
                 "fields" => [FieldName.compute(:id, unquote(f))],
                 "sort" => "#{ok},-#{FieldName.compute(:short_title, unquote(f))}"
               })

      if bad = wrong(unquote(f)) do
        for sort <- ["#{ok},#{bad}", "#{ok},-#{bad}", "#{bad},#{ok}", ["#{ok},#{bad}"]] do
          assert {:error, {:unknown_field, :short_title, PostResource, []}} =
                   parse(unquote(f), %{
                     "action" => "list_posts",
                     "fields" => [FieldName.compute(:id, unquote(f))],
                     "sort" => sort
                   })
        end
      end
    end

    test "E5: unknown spelling nested under a relationship scope is refused under #{f}" do
      posts = FieldName.compute(:posts, unquote(f))
      ok = FieldName.compute(:short_title, unquote(f))

      assert {:ok, _} =
               parse(unquote(f), %{
                 "action" => "list_authors",
                 "fields" => [%{posts => [ok]}]
               })

      if bad = wrong(unquote(f)) do
        assert {:error, {:unknown_field, :short_title, PostResource, []}} =
                 parse(unquote(f), %{
                   "action" => "list_authors",
                   "fields" => [%{posts => [bad]}]
                 })
      end
    end
  end
end
