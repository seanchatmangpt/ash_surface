defmodule AshSurface.Ported.TypedChannel.ChannelRuntimeGapTest do
  @moduledoc """
  Loud gaps for ash_typescript typed_channel runtime: Phoenix channel interception
  (`use AshTypescript.TypedChannel` injecting `intercept` + `handle_out`) and
  `PayloadFormatter` (server-side field-name formatting of broadcast payloads) have no
  ash_surface counterpart; ash_surface channel support is descriptor-only (see
  `Compiler.Section.Channel` moduledoc).
  """
  use ExUnit.Case, async: true

  @moduletag skip: "T13-GAP typed_channel runtime interception"

  test "interception: declared events are intercepted, user intercepts merged" do
    flunk("gap")
  end

  test "interception: handle_out formats payload per publication returns type" do
    flunk("gap")
  end

  test "interception: developer handle_out clause wins over injected one" do
    flunk("gap")
  end

  test "interception: warns when module is not a Phoenix channel" do
    flunk("gap")
  end

  test "PayloadFormatter.format_payload/3 and push_formatted/4 through Phoenix JSON serializer" do
    flunk("gap")
  end

  test "PayloadFormatter: embedded resources, unions, :term, forbidden fields, unloaded calcs" do
    flunk("gap")
  end

  test "calculation-transform publications infer payload type from the calculation return type" do
    flunk("gap")
  end

  test "warn_on_missing_channel_returns / warn_on_non_public_publications config flags" do
    flunk("gap")
  end
end
