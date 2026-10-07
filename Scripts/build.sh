#!/bin/bash
set -euo pipefail

APP_NAME="MacStats"
BUILD_DIR=".build"
DEBUG_DIR="${BUILD_DIR}/debug"
RELEASE_DIR="${BUILD_DIR}/release"

SDK=$(xcrun --show-sdk-path 2>/dev/null)

# Sources are discovered rather than listed, so new files are picked up
# automatically (a hand-maintained list drifts every time the app grows).
SOURCES=()
while IFS= read -r file; do
    SOURCES+=("$file")
done < <(find Sources/MacStats -name '*.swift' | sort)

FRAMEWORKS=(
    -framework AppKit
    -framework SwiftUI
    -framework IOKit
    -framework Combine
    -framework ServiceManagement
    -framework CoreWLAN
    -framework CoreLocation
)

COMMON_FLAGS=(
    -sdk "$SDK"
    -import-objc-header Sources/MacStats/BridgingHeader.h
    "${FRAMEWORKS[@]}"
)

build_debug() {
    echo "Building debug (${#SOURCES[@]} sources)..."
    mkdir -p "$DEBUG_DIR"
    swiftc "${SOURCES[@]}" \
        "${COMMON_FLAGS[@]}" \
        -target arm64-apple-macosx13.0 \
        -g \
        -o "${DEBUG_DIR}/${APP_NAME}"
    echo "Debug build: ${DEBUG_DIR}/${APP_NAME}"
}

build_release() {
    echo "Building universal release (arm64 + x86_64, ${#SOURCES[@]} sources)..."
    mkdir -p "$RELEASE_DIR"

    echo "  Compiling arm64..."
    swiftc "${SOURCES[@]}" \
        "${COMMON_FLAGS[@]}" \
        -target arm64-apple-macosx13.0 \
        -O -whole-module-optimization \
        -o "${RELEASE_DIR}/${APP_NAME}-arm64"

    echo "  Compiling x86_64..."
    swiftc "${SOURCES[@]}" \
        "${COMMON_FLAGS[@]}" \
        -target x86_64-apple-macosx13.0 \
        -O -whole-module-optimization \
        -o "${RELEASE_DIR}/${APP_NAME}-x86_64"

    echo "  Creating universal binary..."
    lipo -create \
        "${RELEASE_DIR}/${APP_NAME}-arm64" \
        "${RELEASE_DIR}/${APP_NAME}-x86_64" \
        -output "${RELEASE_DIR}/${APP_NAME}"

    rm -f "${RELEASE_DIR}/${APP_NAME}-arm64" "${RELEASE_DIR}/${APP_NAME}-x86_64"

    echo "Release build: ${RELEASE_DIR}/${APP_NAME}"
    file "${RELEASE_DIR}/${APP_NAME}"
}

case "${1:-debug}" in
    debug)
        build_debug
        ;;
    release)
        build_release
        ;;
    *)
        echo "Usage: $0 [debug|release]"
        exit 1
        ;;
esac
