# ash_surface task runner
#
# Recipes follow Elixir-community just conventions: one concern per recipe,
# comments above each recipe double as descriptions in `just --list`.

# List available recipes
default:
    @just --list

# Install Elixir and Node.js dependencies
deps:
    mix deps.get
    npm install

# Run the Elixir test suite
test:
    mix test

# Run the JavaScript test suite
test-js:
    npm test

# Run every test suite: mix test.all when present (t36), else clear error + both suites directly
test-all:
    #!/usr/bin/env bash
    set -euo pipefail
    if grep -q 'test\.all' mix.exs; then
        mix test.all
    else
        echo "ERROR: mix test.all is not defined in mix.exs (alias landed with t36/v50; seeing this means mix.exs regressed)." >&2
        echo "FALLBACK: running both suites directly." >&2
        mix test
        npm test
    fi

# Run the zero-config conformance check
zero-config:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -f scripts/zero_config_check.sh ]; then
        bash scripts/zero_config_check.sh
    else
        echo "ERROR: scripts/zero_config_check.sh not found (landed on the integrated tree; seeing this means the tree regressed)." >&2
        echo "Refusing to fabricate a pass; no fallback exists for this gate." >&2
        exit 1
    fi

# Check Elixir formatting and JavaScript syntax
format-check:
    mix format --check-formatted
    npm run check
