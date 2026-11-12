# DSL options that exist in lib/ash_surface/resource.ex today. Exported so
# consumers' `import_deps: [:ash_surface]` formats them without parens.
spark_locals_without_parens = [
  projection: 1,
  projection: 2
]

[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: spark_locals_without_parens,
  export: [locals_without_parens: spark_locals_without_parens]
]
