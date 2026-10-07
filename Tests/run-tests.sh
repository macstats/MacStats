#!/usr/bin/env bash
#
# Unit-test runner for the pure-logic targets: RingBuffer, Format and the
# model status/percentage math.
#
# Plain `swift test` cannot run here on a Command Line Tools–only install:
# SwiftPM always builds every target in the package, and the app target needs
# Xcode's SwiftUIMacros plugin (see AGENTS.md). XCTest is Xcode-only too, so the
# suite is written against Swift Testing (`import Testing`), which the CLT
# toolchain ships with the compiler.
#
# This builds the test target alone — skipping the app target — and then runs
# the bundle it produced. On a machine with full Xcode, `swift test` alone does
# the same job.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Swift Testing's macro plugin ships inside the toolchain. SwiftPM wires it up
# for the `swift test` path but not for a `swift build --target` of a test
# target, so point the compiler at it explicitly when it is present.
TESTING_PLUGINS="/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing"
PLUGIN_FLAGS=()
if [[ -d "$TESTING_PLUGINS" ]]; then
    PLUGIN_FLAGS=(-Xswiftc -plugin-path -Xswiftc "$TESTING_PLUGINS")
fi

swift build --target MacStatsTests --disable-xctest ${PLUGIN_FLAGS[@]+"${PLUGIN_FLAGS[@]}"}
swift test --skip-build --disable-xctest
