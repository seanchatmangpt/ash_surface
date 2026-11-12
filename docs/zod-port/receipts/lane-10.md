# Lane 10 Receipt

Standing: PARTIAL

Files: lib/ash_surface/compiler/route_schema.ex, test/ash_surface/route_schema_test.exs

Command: `MIX_BUILD_ROOT=_build-lane10 mix test test/ash_surface/route_schema_test.exs`
Result: 4 tests, 0 failures (exit 0; the `rc=` was the pipe's `tail`, test summary is the evidence).
Compile warning seen from another lane's file (inference.ex:14 heredoc indentation), not mine.

Behavior: build/1 -> per-route params/query/body/response; path params excluded from body;
GET/HEAD args -> query; errors {:duplicate_route,v,p}, {:path_param_missing_arg,r,p},
{:path_param_nullable,r,p}; introspect_router/1 (path/verb/path_params, Phoenix optional,
else {:error, :phoenix_unavailable}).

PARTIAL reasons: ZodType (lane 01) absent at run time, so fragments fell back to `z.unknown()`;
tests assert structure only, ZodGuard.admit/1 not exercised; introspector Phoenix path untested.

Requests: lane 17 to wire RouteSchema.build/1 into IR if routes are surfaced.
Falsifiers: once lane 01 lands, route strings must pass ZodGuard.admit/1 and show real types.
