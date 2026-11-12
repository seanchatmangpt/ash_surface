defmodule AshSurface.ZodFixtures.Domain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(AshSurface.ZodFixtures.Todo)
  end
end

defmodule AshSurface.ZodFixtures.Priority do
  @moduledoc false
  use Ash.Type.Enum, values: [:low, :medium, :high]
end

defmodule AshSurface.ZodFixtures.Slug do
  @moduledoc "Custom string type with a `match` constraint."
  use Ash.Type.NewType,
    subtype_of: :string,
    constraints: [match: ~r/^[a-z0-9-]+$/, min_length: 2, max_length: 40]
end

defmodule AshSurface.ZodFixtures.Address do
  @moduledoc false
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute(:street, :string, public?: true, allow_nil?: false)
    attribute(:zip, :string, public?: true, constraints: [min_length: 5, max_length: 5])
  end
end

defmodule AshSurface.ZodFixtures.Todo do
  @moduledoc """
  Small real domain on `Ash.DataLayer.Ets` for the Zod port: constraints,
  enum / atom `one_of`, embedded, union, arrays, maps, optionality,
  calculation and a custom type.
  """
  use Ash.Resource,
    domain: AshSurface.ZodFixtures.Domain,
    data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key(:id, public?: true)

    attribute(:title, :string,
      public?: true,
      allow_nil?: false,
      constraints: [min_length: 1, max_length: 80]
    )

    attribute(:notes, :string, public?: true)
    attribute(:points, :integer, public?: true, constraints: [min: 0, max: 100])
    attribute(:score, :float, public?: true)
    attribute(:amount, :decimal, public?: true)
    attribute(:done, :boolean, public?: true, default: false)
    attribute(:status, :atom, public?: true, constraints: [one_of: [:open, :closed]])
    attribute(:priority, AshSurface.ZodFixtures.Priority, public?: true)
    attribute(:slug, AshSurface.ZodFixtures.Slug, public?: true)
    attribute(:due_on, :date, public?: true)
    attribute(:created_at, :utc_datetime, public?: true)
    attribute(:tags, {:array, :string}, public?: true, default: [])
    attribute(:metadata, :map, public?: true)
    attribute(:address, AshSurface.ZodFixtures.Address, public?: true)

    attribute(:ref, :union,
      public?: true,
      constraints: [
        types: [
          text: [type: :string],
          number: [type: :integer]
        ]
      ]
    )
  end

  calculations do
    calculate(:shout, :string, expr(string_upcase(title)), public?: true)
  end

  actions do
    defaults([:read])

    create :create do
      primary?(true)

      accept([
        :title,
        :notes,
        :points,
        :score,
        :amount,
        :done,
        :status,
        :priority,
        :slug,
        :due_on,
        :created_at,
        :tags,
        :metadata,
        :address,
        :ref
      ])
    end
  end
end

defmodule AshSurface.ZodFixtures.Harness do
  @moduledoc """
  Real-toolchain harness for the TS/Zod tests: builds the fixture-domain
  artifact, stages it with the `test/ts` tree into a `System.tmp_dir!`
  workspace, and resolves `node`/`tsc` from `node_modules/.bin` (falling back
  to PATH). Missing tooling raises loudly, never a silent skip.
  """

  @repo_root Path.expand("../..", __DIR__)
  @otp_app :ash_surface_zod_fixtures

  def repo_root, do: @repo_root

  @doc "Compiles the fixture domain to the JS artifact text."
  def artifact! do
    Application.put_env(@otp_app, :ash_domains, [AshSurface.ZodFixtures.Domain])
    {:ok, manifest} = Ash.Info.Manifest.generate(otp_app: @otp_app)
    {:ok, irs} = AshSurface.Ported.AshNames.with_verbatim(fn -> AshSurface.Compiler.compile(manifest) end)
    {:ok, artifacts, _meta} = AshSurface.Projectors.JS.project_ir(irs)
    Map.fetch!(artifacts, "ash_surface_client.mjs")
  end

  @doc "Absolute path of a tool; raises when neither node_modules/.bin nor PATH has it."
  def tool!(name) do
    local = Path.join([@repo_root, "node_modules", ".bin", name])

    cond do
      File.exists?(local) ->
        local

      path = System.find_executable(name) ->
        path

      true ->
        raise "REQUIRED TOOL MISSING: #{name} (checked #{local} and PATH). Run `npm install`."
    end
  end

  @doc "Raises unless `zod` is installed under the repo node_modules."
  def zod! do
    dir = Path.join([@repo_root, "node_modules", "zod"])
    File.dir?(dir) || raise "REQUIRED PACKAGE MISSING: zod at #{dir}. Run `npm install`."
    dir
  end

  @doc "Creates a unique tmp workspace with test/ts + the artifact; returns the ts dir."
  def workspace!(artifact) do
    zod!()
    dir = Path.join(System.tmp_dir!(), "ash_surface_ts_#{AshSurface.TestTmp.suffix()}")
    File.mkdir_p!(dir)
    File.cp_r!(Path.join(@repo_root, "test/ts"), Path.join(dir, "ts"))
    gen = Path.join([dir, "ts", "generated"])
    File.mkdir_p!(gen)
    File.write!(Path.join(gen, "ash_surface_client.mjs"), artifact)
    File.ln_s!(Path.join(@repo_root, "node_modules"), Path.join(dir, "node_modules"))
    Path.join(dir, "ts")
  end

  def cleanup!(ts_dir), do: File.rm_rf!(Path.dirname(ts_dir))

  @doc "Runs a command in `dir`; returns {output, exit_status}."
  def run(cmd, args, dir), do: System.cmd(cmd, args, cd: dir, stderr_to_stdout: true)
end
