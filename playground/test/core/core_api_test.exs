defmodule CoreTest.Address do
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :street, :string, public?: true
    attribute :zip, :string, public?: true
  end
end

defmodule CoreTest.Child do
  use Ash.Resource, domain: CoreTest.Domain, data_layer: Ash.DataLayer.Ets

  ets do
    private? false
  end

  attributes do
    uuid_primary_key :id
    attribute :label, :string, allow_nil?: false, public?: true
  end

  relationships do
    belongs_to :parent, CoreTest.Parent, public?: true, attribute_writable?: true
  end

  actions do
    defaults [:read, :destroy, create: [:label, :parent_id], update: [:label]]
  end
end

defmodule CoreTest.Parent do
  use Ash.Resource, domain: CoreTest.Domain, data_layer: Ash.DataLayer.Ets

  ets do
    private? false
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
    attribute :rank, :integer, default: 0, public?: true
    attribute :secret, :string, sensitive?: true, public?: true
    attribute :address, CoreTest.Address, public?: true
    attribute :tags, {:array, :string}, default: [], public?: true

    attribute :payload, :union,
      public?: true,
      constraints: [types: [int: [type: :integer], text: [type: :string]]]
  end

  relationships do
    has_many :children, CoreTest.Child, destination_attribute: :parent_id, public?: true
  end

  calculations do
    calculate :greet, :string, expr("hi " <> ^arg(:who) <> " " <> name) do
      public? true
      argument :who, :string, allow_nil?: false
    end
  end

  actions do
    read :read do
      primary? true
      pagination offset?: true, keyset?: true, countable: true, default_limit: 25, required?: false
    end

    defaults [:destroy]

    create :create do
      primary? true
      accept [:name, :rank, :secret, :address, :tags, :payload]
      argument :children, {:array, :map}
      change manage_relationship(:children, type: :create)
    end

    update :update do
      primary? true
      require_atomic? false
      accept [:name, :rank, :address]
      argument :children, {:array, :map}
      change manage_relationship(:children, type: :direct_control)
    end
  end
end

defmodule CoreTest.Domain do
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource CoreTest.Parent
    resource CoreTest.Child
  end
end

defmodule CoreApiTest do
  use ExUnit.Case, async: false
  import Phoenix.ConnTest
  import Plug.Conn, only: [get_resp_header: 2]
  @endpoint PlaygroundWeb.Endpoint

  alias Playground.Blog.{Author, Post}
  alias CoreTest.Parent

  setup do
    prev = Application.get_env(:playground, :ash_shadcn)
    Application.put_env(:playground, :ash_shadcn, Keyword.update!(prev, :domains, &(&1 ++ [CoreTest.Domain])))
    on_exit(fn -> Application.put_env(:playground, :ash_shadcn, prev) end)

    n = System.unique_integer([:positive])
    admin = Ash.create!(Author, %{name: "A", email: "a#{n}@x.io", role: :admin}, authorize?: false)
    editor = Ash.create!(Author, %{name: "E", email: "e#{n}@x.io", role: :editor}, authorize?: false)
    reader = Ash.create!(Author, %{name: "R", email: "r#{n}@x.io", role: :reader}, authorize?: false)
    %{admin: admin, editor: editor, reader: reader, tag: "t#{n}"}
  end

  defp get_api(path, params \\ %{}), do: build_conn() |> get("/admin/api" <> path, params)
  defp post_api(path, body), do: build_conn() |> post("/admin/api" <> path, body)

  defp parent!(attrs), do: Ash.create!(Parent, attrs, authorize?: false)

  test "introspection exposes embedded fields, union members, calc arguments and managed relationships" do
    meta = get_api("/resources/CoreTest.Parent") |> json_response(200)
    addr = Enum.find(meta["attributes"], &(&1["name"] == "address"))
    assert addr["kind"] == "embedded"
    assert Enum.map(addr["fields"], & &1["name"]) == ["street", "zip"]

    payload = Enum.find(meta["attributes"], &(&1["name"] == "payload"))
    assert payload["kind"] == "union"
    assert Enum.map(payload["types"], &{&1["name"], &1["kind"]}) == [{"int", "integer"}, {"text", "string"}]

    tags = Enum.find(meta["attributes"], &(&1["name"] == "tags"))
    assert tags["items"]["kind"] == "string"

    greet = Enum.find(meta["calculations"], &(&1["name"] == "greet"))
    assert [%{"name" => "who"}] = greet["arguments"]

    create = Enum.find(meta["actions"], &(&1["name"] == "create"))
    assert [%{"argument" => "children", "relationship" => "children", "cardinality" => "many", "destination_module" => "CoreTest.Child"}] =
             create["managed_relationships"]

    assert create["pagination"] == nil
    read = Enum.find(meta["actions"], &(&1["name"] == "read"))
    assert %{"keyset" => true, "offset" => true} = read["pagination"]
  end

  test "show loads belongs_to and has_many relationships; sensitive attributes are omitted unless revealed" do
    p = parent!(%{name: "Pat", secret: "s3cret"})
    c = Ash.create!(CoreTest.Child, %{label: "kid", parent_id: p.id}, authorize?: false)

    rec = get_api("/resources/CoreTest.Parent/records/#{p.id}", %{"load" => "children"}) |> json_response(200)
    assert [%{"label" => "kid"}] = rec["children"]
    refute Map.has_key?(rec, "secret")

    shown = get_api("/resources/CoreTest.Parent/records/#{p.id}", %{"reveal" => "true"}) |> json_response(200)
    assert shown["secret"] == "s3cret"

    kid = get_api("/resources/CoreTest.Child/records/#{c.id}", %{"load" => "parent"}) |> json_response(200)
    assert kid["parent"]["name"] == "Pat" and kid["parent_id"] == p.id

    # lazy has_many: the destination resource filtered by its foreign key through the same API
    list = get_api("/resources/CoreTest.Child/records", %{"filter" => %{"parent_id" => %{"eq" => p.id}}}) |> json_response(200)
    assert list["count"] == 1

    assert get_api("/resources/CoreTest.Parent/records/#{Ash.UUID.generate()}") |> json_response(404)
  end

  test "calculations with arguments load through calc_args" do
    p = parent!(%{name: "Pat"})

    rec =
      get_api("/resources/CoreTest.Parent/records/#{p.id}", %{"load" => "greet", "calc_args" => %{"greet" => %{"who" => "bob"}}})
      |> json_response(200)

    assert rec["greet"] == "hi bob Pat"
  end

  test "multi-field filter with operators, multi-sort, and server-side validation errors", %{tag: tag} do
    for {n, r} <- [{"b", 2}, {"a", 2}, {"c", 1}], do: parent!(%{name: "#{tag}-#{n}", rank: r})

    filter = Jason.encode!(%{"and" => [%{"name" => %{"contains" => tag}}, %{"rank" => %{"gte" => 2}}]})
    r = get_api("/resources/CoreTest.Parent/records", %{"filter" => filter, "sort" => "-rank,name"}) |> json_response(200)
    assert Enum.map(r["records"], & &1["name"]) == ["#{tag}-a", "#{tag}-b"]

    r2 = get_api("/resources/CoreTest.Parent/records", %{"filter" => %{"name" => %{"contains" => tag}, "rank" => %{"lt" => "2"}}}) |> json_response(200)
    assert Enum.map(r2["records"], & &1["name"]) == ["#{tag}-c"]

    bad = get_api("/resources/CoreTest.Parent/records", %{"filter" => %{"nope" => %{"eq" => "x"}}}) |> json_response(422)
    assert bad["error"] == "invalid_filter"
    assert [%{"message" => msg} | _] = bad["errors"]
    assert msg =~ "nope"

    bad_value = get_api("/resources/CoreTest.Parent/records", %{"filter" => %{"rank" => %{"eq" => "abc"}}}) |> json_response(422)
    assert bad_value["error"] == "invalid_filter"

    bad_json = get_api("/resources/CoreTest.Parent/records", %{"filter" => "{nope"}) |> json_response(422)
    assert bad_json["error"] == "invalid_filter"
  end

  test "keyset pagination walks all records with cursors", %{tag: tag} do
    for n <- 1..5, do: parent!(%{name: "#{tag}-#{n}"})
    q = %{"mode" => "keyset", "limit" => "2", "sort" => "name", "filter" => %{"name" => %{"contains" => tag}}}
    p1 = get_api("/resources/CoreTest.Parent/records", q) |> json_response(200)
    assert p1["pagination"] == "keyset" and length(p1["records"]) == 2 and p1["more"] == true
    p2 = get_api("/resources/CoreTest.Parent/records", Map.put(q, "after", p1["next_cursor"])) |> json_response(200)
    p3 = get_api("/resources/CoreTest.Parent/records", Map.put(q, "after", p2["next_cursor"])) |> json_response(200)
    names = Enum.flat_map([p1, p2, p3], fn p -> Enum.map(p["records"], & &1["name"]) end)
    assert names == Enum.map(1..5, &"#{tag}-#{&1}")
    assert p3["more"] == false
  end

  test "offset pagination reports count and honours page size", %{tag: tag} do
    for n <- 1..3, do: parent!(%{name: "#{tag}-#{n}"})
    r = get_api("/resources/CoreTest.Parent/records", %{"limit" => "2", "offset" => "2", "sort" => "name", "filter" => %{"name" => %{"contains" => tag}}}) |> json_response(200)
    assert r["count"] == 3 and length(r["records"]) == 1 and r["pagination"] == "offset"
  end

  test "nested forms via manage_relationship: create with children, then direct_control update" do
    body = %{
      "action" => "create",
      "params" => %{"name" => "Nested", "children" => [%{"label" => "one"}, %{"label" => "two"}]}
    }

    assert %{"errors" => [], "record" => %{"id" => id}} = post_api("/resources/CoreTest.Parent/submit", body) |> json_response(200)
    kids = Ash.read!(CoreTest.Child, authorize?: false) |> Enum.filter(&(&1.parent_id == id)) |> Enum.map(& &1.label) |> Enum.sort()
    assert kids == ["one", "two"]

    shown = get_api("/resources/CoreTest.Parent/records/#{id}", %{"load" => "children"}) |> json_response(200)
    [first, second] = Enum.sort_by(shown["children"], & &1["label"])

    upd = %{
      "action" => "update",
      "id" => id,
      "params" => %{"children" => [%{"id" => first["id"], "label" => "uno"}, %{"id" => second["id"], "label" => "two"}]}
    }

    assert %{"errors" => []} = post_api("/resources/CoreTest.Parent/submit", upd) |> json_response(200)
    labels = Ash.read!(CoreTest.Child, authorize?: false) |> Enum.filter(&(&1.parent_id == id)) |> Enum.map(& &1.label) |> Enum.sort()
    assert labels == ["two", "uno"]

    invalid = %{"action" => "create", "params" => %{"name" => "N2", "children" => [%{"label" => ""}]}}
    assert %{"errors" => [_ | _]} = post_api("/resources/CoreTest.Parent/validate", invalid) |> json_response(200)
  end

  test "embedded and union values round-trip through the form" do
    body = %{
      "action" => "create",
      "params" => %{"name" => "Emb", "address" => %{"street" => "1 Main", "zip" => "999"}, "tags" => ["a", "b"], "payload" => %{"_union_type" => "int", "value" => "7"}}
    }

    resp = post_api("/resources/CoreTest.Parent/submit", body) |> json_response(200)
    assert resp["errors"] == []
    assert resp["record"]["address"]["street"] == "1 Main"
    assert resp["record"]["tags"] == ["a", "b"]
    assert resp["record"]["payload"] == %{"type" => "int", "value" => 7}
  end

  test "bulk destroy and update are policy-gated per record", %{editor: editor, reader: reader, tag: tag} do
    posts = for n <- 1..3, do: Ash.create!(Post, %{title: "#{tag} post #{n}"}, actor: editor)
    ids = Enum.map(posts, & &1.id)

    denied = post_api("/resources/Playground.Blog.Post/bulk", %{"op" => "destroy", "ids" => ids, "actor_id" => reader.id}) |> json_response(200)
    assert denied["affected"] == 0
    assert Ash.read!(Post, authorize?: false) |> Enum.count(&(&1.id in ids)) == 3

    pub = post_api("/resources/Playground.Blog.Post/bulk", %{"op" => "update", "action" => "publish", "ids" => ids, "actor_id" => editor.id}) |> json_response(200)
    assert pub["affected"] == 3 and pub["errors"] == []
    assert Ash.read!(Post, authorize?: false) |> Enum.filter(&(&1.id in ids)) |> Enum.all?(&(&1.status == :published))

    ok = post_api("/resources/Playground.Blog.Post/bulk", %{"op" => "destroy", "ids" => ids, "actor_id" => editor.id}) |> json_response(200)
    assert ok["affected"] == 3
    assert Ash.read!(Post, authorize?: false) |> Enum.count(&(&1.id in ids)) == 0

    assert post_api("/resources/Playground.Blog.Post/bulk", %{"op" => "explode", "ids" => ids}) |> json_response(422)
    assert post_api("/resources/Playground.Blog.Post/bulk", %{"op" => "destroy", "ids" => []}) |> json_response(422)
  end

  test "export streams the current query as csv or json, omits sensitive, and neutralizes formulas", %{tag: tag} do
    parent!(%{name: "=#{tag},evil", rank: 5, secret: "hidden"})
    parent!(%{name: "#{tag} plain", rank: 6})
    f = %{"name" => %{"contains" => tag}}

    csv = get_api("/resources/CoreTest.Parent/export", %{"format" => "csv", "filter" => f, "sort" => "rank", "columns" => "name,rank,secret"})
    assert csv.status == 200
    assert hd(get_resp_header(csv, "content-type")) =~ "text/csv"
    assert hd(get_resp_header(csv, "content-disposition")) =~ "Parent.csv"
    [header | rows] = csv.resp_body |> String.split("\r\n", trim: true)
    assert header == "name,rank"
    assert rows == [~s("'=#{tag},evil",5), "#{tag} plain,6"]

    json = get_api("/resources/CoreTest.Parent/export", %{"format" => "json", "filter" => f, "sort" => "-rank"}) |> json_response(200)
    assert [%{"rank" => 6}, %{"rank" => 5}] = Enum.map(json, &Map.take(&1, ["rank"]))
    refute Enum.any?(json, &Map.has_key?(&1, "secret"))

    assert get_api("/resources/CoreTest.Parent/export", %{"format" => "xml"}) |> json_response(422)
    assert get_api("/resources/CoreTest.Parent/export", %{"filter" => %{"zzz" => %{"eq" => 1}}}) |> json_response(422)
  end
end
