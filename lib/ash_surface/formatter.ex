defmodule AshSurface.Formatter do
  @moduledoc "Spark.Formatter plugin for the ggen-manufactured AshSurface DSL."

  def extensions, do: [AshSurface.Resource]

  def features(_opts), do: [extensions: [".ex", ".exs"]]

  def format(contents, opts) do
    if Code.ensure_loaded?(Spark.Formatter) do
      opts_with_spark =
        Keyword.update(opts, :spark, [extensions: extensions()], fn spark ->
          Keyword.update(spark, :extensions, extensions(), &(extensions() ++ &1))
        end)

      Spark.Formatter.format(contents, opts_with_spark)
    else
      contents
    end
  end
end
