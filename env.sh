#!/bin/bash
# AstraAutoEx development environment
# Usage: source env.sh
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="$DIR/tools/elixir/bin:$DIR/tools/erlang/bin:$DIR/tools/erlang/erts-16.3.1/bin:/c/Program Files/PostgreSQL/17/bin:$PATH"
export MAKE=make
export CC=gcc
echo "AstraAutoEx env loaded. Run: mix phx.server"
