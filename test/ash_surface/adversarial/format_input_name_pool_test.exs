defmodule AshSurface.Adversarial.FormatInputNamePool.Dom do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(AshSurface.Adversarial.FormatInputNamePool.Res)
  end
end

defmodule AshSurface.Adversarial.FormatInputNamePool.Res do
  @moduledoc "Lane RBX inline resource: mapped `is_open?` -> `q`."
  use Ash.Resource,
    domain: AshSurface.Adversarial.FormatInputNamePool.Dom,
    data_layer: Ash.DataLayer.Ets,
    primary_read_warning?: false,
    extensions: [AshSurface.Resource]

  ets do
    private?(true)
  end

  surface do
    type_name("FinPoolRes")
    argument_names(search: [is_open?: "q"])
  end

  attributes do
    uuid_primary_key(:id, public?: true)
  end

  actions do
    read :read do
      primary?(true)
    end

    read :search do
      argument(:is_open?, :boolean)
      argument(:empty, :string)
      argument(:other_arg, :string)
    end
  end
end

defmodule AshSurface.Adversarial.FormatInputNamePool.Fmt do
  @moduledoc false
  def same(x), do: to_string(x)
  def diff(x), do: "X_" <> to_string(x)
  def atom(_), do: :nope
  def empty(_), do: ""
  def nilr(_), do: nil
end

defmodule AshSurface.Adversarial.FormatInputNamePoolTest do
  @moduledoc """
  Lane RBX (Q2-Q4). Real resource + real formatters through Support.format_input_name/5:
  mapped names are verbatim; unmapped names go through the formatter; non-binary custom
  results raise before reaching the mapped/unmapped branch (KD-12).
  """
  use ExUnit.Case, async: false

  alias AshSurface.Adversarial.FormatInputNamePool.{Fmt, Res}
  alias AshSurface.RuntimeParity.Rpc.Support

  defp fin(name, fm), do: Support.format_input_name(Res, :search, name, %{}, fm)

  test "Q2 custom formatter returning a binary equal to the input name" do
    assert fin(:other_arg, {Fmt, :same}) == "other_arg"
    assert fin(:_x, {Fmt, :same}) == "_x"
    assert fin(:x?, {Fmt, :same}) == "x?"
  end

  test "Q3 custom formatter returning a different binary applies to unmapped names only" do
    assert fin(:other_arg, {Fmt, :diff}) == "X_other_arg"
    assert fin(:is_open?, {Fmt, :diff}) == "q"
    assert fin(:empty, {Fmt, :diff}) == "X_empty"
  end

  test "Q4 atom names under built-in formatters: leading _, ?, empty mapped" do
    assert fin(:other_arg, :camel_case) == "otherArg"
    assert fin(:other_arg, :snake_case) == "other_arg"
    assert fin(:other_arg, :pascal_case) == "OtherArg"
    assert fin(:_x, :snake_case) == "_x"
    assert fin(:x?, :snake_case) == "x?"
    assert fin(:is_open?, :camel_case) == "q"
    # empty-string mapped names are refused at compile time by the verifier
    # (field_not_invalid), so unmapped here:
    assert fin(:empty, :camel_case) == "empty"
  end

  test "Q4 KD-12: non-binary / empty custom results raise for unmapped names" do
    for f <- [:atom, :empty, :nilr], n <- [:other_arg, :_x, :x?] do
      assert_raise ArgumentError, fn -> fin(n, {Fmt, f}) end
    end
  end

  test "Q4 KD-12: mapped names never reach the custom formatter" do
    for f <- [:atom, :empty, :nilr] do
      assert fin(:is_open?, {Fmt, f}) == "q"
    end
  end
end
