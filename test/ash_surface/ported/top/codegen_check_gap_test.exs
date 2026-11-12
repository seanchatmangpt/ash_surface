defmodule AshSurface.Ported.Top.CodegenCheckGapTest do
  @moduledoc "Loud skips for the codegen_check reference tests with no ash_surface counterpart (lane T1)."
  use ExUnit.Case, async: true

  @manifest_gap "T1 gap: ash_surface codegen emits no JSON/Markdown RPC manifest files (config keys manifest_file/json_manifest_file are accessor-only); --check cannot diff a manifest (capabilities config.key.manifest_file, config.key.json_manifest_file)"
  @namespace_gap "T1 gap: ash_surface codegen writes one artifact file; enable_namespace_files / namespace_output_dir multi-file output is accessor-only (capabilities config.key.enable_namespace_files, config.key.namespace_output_dir)"

  # describe "manifests"
  @tag skip: @manifest_gap
  test "--check flags a stale JSON manifest", do: :ok

  @tag skip: @manifest_gap
  test "--check flags a stale Markdown manifest", do: :ok

  @tag skip: @manifest_gap
  test "--check passes when only generatedAt differs", do: :ok

  @tag skip: @manifest_gap
  test "--dry-run previews a stale manifest without writing it", do: :ok

  # describe "multi-file output"
  @tag skip: @namespace_gap
  test "multi-file --check raises PendingCodegen when files are stale", do: :ok

  @tag skip: @namespace_gap
  test "multi-file --check raises PendingCodegen even with always_regenerate enabled", do: :ok

  @tag skip: @namespace_gap
  test "multi-file --dev --check raises PendingCodegen when always_regenerate is false", do: :ok

  @tag skip: @namespace_gap
  test "multi-file --dev --check silently regenerates when always_regenerate is true", do: :ok
end
