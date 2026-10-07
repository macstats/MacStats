#!/bin/bash
set -euo pipefail

# Builds the debug binary and runs the sampling micro-benchmark.
ITERATIONS="${1:-200}"

bash Scripts/build.sh debug >/dev/null
echo "Running sampling benchmark (${ITERATIONS} iterations)..."
.build/debug/MacStats --benchmark "$ITERATIONS"
