defmodule AshShadcnRealtimeTest.LockedDomain do
  use Ash.Domain, validate_config_inclusion?: false
  resources do
    resource AshShadcnRealtimeTest.Locked
  end
end

defmodule AshShadcnRealtimeTest.Locked do
  use Ash.Resource, domain: AshShadcnRealtimeTest.LockedDomain, data_layer: Ash.DataLayer.Ets,
    authorizers: [Ash.Policy.Authorizer], notifiers: [Ash.Notifier.PubSub]

  attributes do
    uuid_primary_key :id
  end

  actions do
    defaults [:read]
  end

  pub_sub do
    module PlaygroundWeb.Endpoint
    prefix "locked"
  end

  policies do
    policy action_type(:read) do
      forbid_if always()
    end
  end
end

defmodule AshShadcnRealtimeTest do
  use ExUnit.Case, async: false
  import Phoenix.ChannelTest
  @endpoint PlaygroundWeb.Endpoint

  alias Playground.Blog.{Author, Comment, Post}

  setup do
    n = System.unique_integer([:positive])
    admin = Ash.create!(Author, %{name: "A", email: "a#{n}@x.io", role: :admin}, authorize?: false)
    {:ok, socket} = connect(AshShadcnWeb.Realtime.Socket, %{})
    %{admin: admin, socket: socket}
  end

  defp join!(socket, mod, actor),
    do: subscribe_and_join(socket, "admin:#{inspect(mod)}", %{"actor_id" => actor.id})

  test "join allowed for readable resource, refused for unknown/non-realtime", %{socket: s, admin: a} do
    assert {:ok, _, _} = join!(s, Post, a)
    assert {:error, %{reason: "not_found"}} = subscribe_and_join(s, "admin:Nope.Thing", %{})
  end

  test "join is refused when the actor cannot read (read policy)", %{socket: s, admin: a} do
    old = Application.get_env(:playground, :ash_shadcn)
    Application.put_env(:playground, :ash_shadcn, Keyword.put(old, :domains, [Playground.Blog, AshShadcnRealtimeTest.LockedDomain]))
    on_exit(fn -> Application.put_env(:playground, :ash_shadcn, old) end)

    assert {:error, %{reason: "forbidden"}} = join!(s, AshShadcnRealtimeTest.Locked, a)
  end

  test "Post create/update/destroy push changed with payload shape", %{socket: s, admin: a} do
    {:ok, _, _} = join!(s, Post, a)
    post = Ash.create!(Post, %{title: "Hello rt"}, actor: a)
    id = post.id
    assert_push "changed", %{"resource" => "Playground.Blog.Post", "action" => "create", "type" => "create",
                             "id" => ^id, "record" => %{"title" => "Hello rt"}, "at" => _}
    Ash.update!(post, %{title: "Hello rt2"}, actor: a)
    assert_push "changed", %{"action" => "update", "id" => ^id, "record" => %{"title" => "Hello rt2"}}
    Ash.destroy!(post, actor: a)
    assert_push "changed", %{"action" => "destroy", "id" => ^id}
  end

  test "Comment and Author deliver pushes", %{socket: s, admin: a} do
    {:ok, _, _} = join!(s, Comment, a)
    {:ok, _, _} = join!(s, Author, a)
    post = Ash.create!(Post, %{title: "Parent"}, actor: a)
    c = Ash.create!(Comment, %{body: "hi", post_id: post.id})
    cid = c.id
    assert_push "changed", %{"resource" => "Playground.Blog.Comment", "action" => "create", "id" => ^cid}
    Ash.update!(c, %{body: "yo"})
    assert_push "changed", %{"resource" => "Playground.Blog.Comment", "action" => "update", "id" => ^cid}
    Ash.destroy!(c)
    assert_push "changed", %{"resource" => "Playground.Blog.Comment", "action" => "destroy", "id" => ^cid}

    au = Ash.create!(Author, %{name: "Z", email: "z#{System.unique_integer([:positive])}@x.io"}, actor: a)
    aid = au.id
    assert_push "changed", %{"resource" => "Playground.Blog.Author", "action" => "create", "id" => ^aid}
  end
end
