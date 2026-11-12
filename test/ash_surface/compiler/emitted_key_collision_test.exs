defmodule AshSurface.Compiler.EmittedKeyCollisionTest do
  use ExUnit.Case, async: true

  alias AshSurface.Compiler.{EmbeddedSchema, EmittedKeys, UnionSchema}

  @s %{"kind" => "string"}

  test "helper: distinct names, one key -> typed refusal; exact duplicates are fine" do
    assert {:error, {:emitted_key_collision, :c, "fooBar", ["fooBar", "foo_bar"]}} =
             EmittedKeys.check([{"foo_bar", "fooBar"}, {"fooBar", "fooBar"}], :c)

    assert :ok = EmittedKeys.check([{"a", "a"}, {"a", "a"}, {"b", "b"}], :c)
  end

  for {a, b} <- [{"foo_bar", "fooBar"}, {"a_b", "aB"}] do
    test "embedded map refuses #{a}/#{b}" do
      def = %{
        "type" => %{
          "kind" => "map",
          "fields" => [
            %{"name" => unquote(a), "type" => @s},
            %{"name" => unquote(b), "type" => @s}
          ]
        }
      }

      assert {:error, {:emitted_key_collision, {:container, _}, _key, [_, _]}} =
               EmbeddedSchema.render(def)
    end

    test "union refuses #{a}/#{b}" do
      members = [
        %{"name" => unquote(a), "type" => "string"},
        %{"name" => unquote(b), "type" => "string"}
      ]

      assert {:error, {:emitted_key_collision, :union, _key, [_, _]}} =
               UnionSchema.render_members(members)
    end
  end

  test "non-colliding fields still render" do
    def = %{
      "type" => %{
        "kind" => "map",
        "fields" => [
          %{"name" => "foo_bar", "type" => @s},
          %{"name" => "baz", "type" => @s}
        ]
      }
    }

    assert {:ok, out} = EmbeddedSchema.render(def)
    assert out =~ "fooBar"
  end
end
