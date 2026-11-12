defmodule AshSurface.DivergenceClose.FormatterScopeErrorsTasksTest do
  @moduledoc """
  Wave 3 lane RU (SK-fw2 defects 2, 3, 4), real Spark compile, real `Errors.to_errors/2`,
  real `Rpc.parse`, real `Task.async` and `Task.Supervisor` children. No mocks.

  (2) `Errors.to_errors(resource: R)` reads the SAME scoped/config formatter kernel as the schema
  keys, resource-bound at every path depth.
  (3) the `with_formatter/2` scope reaches spawned Tasks through `$callers` and ends with the block.
  (4) KD-10: nested requested-field, filter and sort spellings are strict inside a scope.
  """
  use ExUnit.Case, async: false

  alias AshSurface.{Errors, FieldName}
  alias AshSurface.Ported.Rpc

  defmodule Upcase do
    def fmt(f), do: f |> to_string() |> String.replace("?", "") |> String.upcase()
  end

  defp compile!(tag) do
    name = "Elixir.AshSurface.RU.#{tag}#{System.unique_integer([:positive])}"

    Code.compile_string("""
    defmodule #{name} do
      use Ash.Resource, domain: nil, data_layer: Ash.DataLayer.Simple,
        extensions: [AshSurface.Resource]
      attributes do
        uuid_primary_key :id, public?: true
        attribute :url_id, :string, public?: true
        attribute :is_active?, :boolean, public?: true
        attribute :__x, :string, public?: true
        attribute :a_1, :string, public?: true
        attribute :éa_b, :string, public?: true
      end
      actions do
        defaults [:read]
      end
      surface do
      end
    end
    """)

    String.to_existing_atom(name)
  end

  defp invalid(field, path),
    do: %{
      Ash.Error.Changes.InvalidAttribute.exception(field: field, message: "bad", vars: [])
      | path: path
    }

  defp errs(r, field, path \\ []) do
    [e] = Errors.to_errors(invalid(field, path), resource: r)
    e
  end

  # error maps are string-keyed; structural keys follow the scope (pascal: "Fields")
  defp get(e, key) do
    Map.get(e, key) || Map.get(e, Macro.camelize(key)) || Map.get(e, String.upcase(key)) || flunk("no #{key} in #{inspect(e)}")
  end

  setup_all do
    {:ok, r: compile!("Scoped")}
  end

  describe "defect 2: Errors follow the scope kernel" do
    test "pascal scope: fields, vars.field and path equal the schema keys", %{r: r} do
      FieldName.with_formatter(:pascal_case, fn ->
        for f <- [:url_id, :is_active?, :__x, :a_1, :éa_b] do
          want = FieldName.wire(r, f)
          e = errs(r, f, [f])
          assert get(e, "fields") == [want], inspect({f, e})
          assert get(e, "path") == [want]
          assert get(e, "vars") |> then(&(&1["field"] || &1["Field"] || &1["FIELD"])) == want
        end

        assert get(errs(r, :url_id), "fields") == ["UrlId"]
      end)
    end

    test "snake and custom scope", %{r: r} do
      FieldName.with_formatter(:snake_case, fn ->
        assert get(errs(r, :url_id), "fields") == ["url_id"]
        assert get(errs(r, :url_id, [:is_active?, :a_1]), "path") == ["is_active?", "a_1"]
      end)

      FieldName.with_formatter({Upcase, :fmt}, fn ->
        e = errs(r, :url_id, [:a_1, :url_id])
        assert get(e, "fields") == ["URL_ID"]
        assert get(e, "path") == ["A_1", "URL_ID"]
        assert get(e, "vars") |> then(&(&1["field"] || &1["Field"] || &1["FIELD"])) == "URL_ID"
      end)
    end

    test "path is resource-bound at every depth; default camel unchanged outside scope", %{r: r} do
      FieldName.with_formatter(:pascal_case, fn ->
        e = errs(r, :url_id, [:a_1, :a_1, :is_active?, 3])
        assert get(e, "path") == [FieldName.wire(r, :a_1), FieldName.wire(r, :a_1), "IsActive?", 3]
      end)

      assert get(errs(r, :url_id), "fields") == ["urlId"]
      assert get(errs(r, :is_active?), "fields") == ["isActive?"]
    end

    test "explicit function formatter is resource-bound at every depth" do
      r = compile!("FnFmt")

      [e] =
        Errors.to_errors(invalid(:url_id, [:a_1, :url_id]),
          resource: r,
          formatter: &Upcase.fmt/1
        )

      assert get(e, "fields") == ["URL_ID"]
      assert get(e, "path") == ["A_1", "URL_ID"]
    end

    test "explicit formatter option still wins over the scope", %{r: r} do
      FieldName.with_formatter(:pascal_case, fn ->
        [e] = Errors.to_errors(invalid(:url_id, []), resource: r, formatter: :snake_case)
        assert get(e, "fields") == ["url_id"]
      end)
    end
  end

  describe "defect 3: scope reaches Tasks" do
    test "Task.async sees the scope and Rpc.parse refuses camel inside it" do
      FieldName.with_formatter(:snake_case, fn ->
        assert Task.async(&FieldName.scoped_formatter/0) |> Task.await() == :snake_case

        parsed =
          Task.async(fn ->
            {Rpc.parse(%{"action" => "list_todos", "fields" => ["created_at"]}),
             Rpc.parse(%{"action" => "list_todos", "fields" => ["createdAt"]})}
          end)
          |> Task.await()

        assert {{:ok, _}, {:error, {:unknown_field, :created_at, _, _}}} = parsed
      end)
    end

    test "Task.Supervisor child resolves the scope; nested Task too" do
      sup = start_supervised!({Task.Supervisor, name: :ru_task_sup})

      FieldName.with_formatter(:pascal_case, fn ->
        assert Task.Supervisor.async(sup, fn ->
                 {FieldName.scoped_formatter(), Task.async(&FieldName.output_formatter/0) |> Task.await()}
               end)
               |> Task.await() == {:pascal_case, :pascal_case}
      end)
    end

    test "no leak after exit, raise or crash; non-descendants never see it" do
      sup = start_supervised!({Task.Supervisor, name: :ru_task_sup2})
      outsider = Task.Supervisor.async_nolink(sup, fn -> FieldName.scoped_formatter() end)
      assert Task.await(outsider) == nil

      FieldName.with_formatter(:snake_case, fn -> :ok end)
      assert Task.async(&FieldName.scoped_formatter/0) |> Task.await() == nil

      assert_raise RuntimeError, fn ->
        FieldName.with_formatter(:snake_case, fn -> raise "boom" end)
      end

      assert Task.async(&FieldName.scoped_formatter/0) |> Task.await() == nil

      # scope owner crashes while a child is alive: the child resolves nothing afterwards
      parent = self()

      {owner, ref} =
        spawn_monitor(fn ->
          FieldName.with_formatter(:snake_case, fn ->
            t = Task.async(fn -> receive do :go -> FieldName.scoped_formatter() end end)
            send(parent, {:child, t.pid})
            exit(:crash)
          end)
        end)

      assert_receive {:child, child}
      assert_receive {:DOWN, ^ref, :process, ^owner, :crash}
      mref = Process.monitor(child)
      send(child, :go)
      assert_receive {:DOWN, ^mref, :process, ^child, _}
      assert FieldName.scoped_formatter() == nil
    end

    test "scope resolves through a bare $callers-only or $ancestors-only chain" do
      parent = self()

      FieldName.with_formatter(:snake_case, fn ->
        for key <- [:"$callers", :"$ancestors"] do
          spawn(fn ->
            Process.put(key, [parent])
            send(parent, {key, FieldName.scoped_formatter()})
          end)

          assert_receive {^key, :snake_case}
        end
      end)
    end

    test "a long-lived child does not retain the scope after the owner block ends" do
      parent = self()

      child =
        spawn(fn ->
          Process.put(:"$callers", [parent])

          loop = fn loop ->
            receive do
              {:ask, from} ->
                send(from, {:scope, FieldName.scoped_formatter()})
                loop.(loop)
            end
          end

          loop.(loop)
        end)

      FieldName.with_formatter(:snake_case, fn ->
        send(child, {:ask, parent})
        assert_receive {:scope, :snake_case}
      end)

      send(child, {:ask, parent})
      assert_receive {:scope, nil}
    end

    test "explicit handle for processes without a $callers chain" do
      handle = FieldName.with_formatter(:snake_case, &FieldName.capture_scope/0)
      assert handle == :snake_case
      parent = self()
      spawn(fn -> send(parent, {:bare, FieldName.scoped_formatter()}) end)
      assert_receive {:bare, nil}

      spawn(fn ->
        send(parent, {:handled, FieldName.with_scope(handle, &FieldName.scoped_formatter/0)})
      end)

      assert_receive {:handled, :snake_case}
    end
  end

  describe "defect 4 (KD-10): nested spellings are strict inside a scope" do
    defp parse(fields), do: Rpc.parse(%{"action" => "list_todos", "fields" => fields})
    defp unknown?(r), do: match?({:error, {:unknown_field, _, _, _}}, r)

    test "snake scope: nested snake accepted, nested camel refused" do
      FieldName.with_formatter(:snake_case, fn ->
        assert {:ok, _} = parse(["id", %{"user" => ["is_super_admin"]}])
        assert unknown?(parse(["id", %{"user" => ["isSuperAdmin"]}]))
      end)
    end

    test "pascal scope: nested Pascal accepted, nested camel refused" do
      FieldName.with_formatter(:pascal_case, fn ->
        assert {:ok, _} = parse(["Id", %{"User" => ["IsSuperAdmin"]}])
        assert unknown?(parse(["Id", %{"User" => ["isSuperAdmin"]}]))
        assert unknown?(parse(["Id", %{"user" => ["IsSuperAdmin"]}]))
      end)
    end

    test "snake scope: embedded destination fields are strict (snake accepted, camel refused)" do
      FieldName.with_formatter(:snake_case, fn ->
        assert {:ok, _} = parse(["id", %{"metadata" => ["estimated_hours"]}])
        assert unknown?(parse(["id", %{"metadata" => ["estimatedHours"]}]))
      end)
    end

    test "default camel: nested camel accepted (no scope, reference behavior)" do
      assert {:ok, _} = parse(["id", %{"user" => ["isSuperAdmin"]}])
    end

    test "snake scope refuses camel sort and filter keys, accepts snake" do
      FieldName.with_formatter(:snake_case, fn ->
        base = %{"action" => "list_todos", "fields" => ["id"]}
        assert {:ok, _} = Rpc.parse(Map.put(base, "sort", "-created_at"))
        assert unknown?(Rpc.parse(Map.put(base, "sort", "-createdAt")))
        assert {:ok, _} = Rpc.parse(Map.put(base, "filter", %{"created_at" => %{"isNil" => false}}))
        assert unknown?(Rpc.parse(Map.put(base, "filter", %{"createdAt" => %{"isNil" => false}})))

        assert unknown?(
                 Rpc.parse(Map.put(base, "filter", %{"and" => [%{"createdAt" => %{"isNil" => false}}]}))
               )
      end)
    end
  end
end
