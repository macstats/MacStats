#!/bin/bash
set -euo pipefail

APP_NAME="MacStats"
BUILD_DIR=".build"
DEBUG_DIR="${BUILD_DIR}/debug"
RELEASE_DIR="${BUILD_DIR}/release"

SDK=$(xcrun --show-sdk-path 2>/dev/null)

SOURCES=(
    Sources/MacStats/Models/SystemStats.swift
    Sources/MacStats/Models/TopProcess.swift
    Sources/MacStats/Monitors/CPUMonitor.swift
    Sources/MacStats/Monitors/MemoryMonitor.swift
    Sources/MacStats/Monitors/NetworkMonitor.swift
    Sources/MacStats/Monitors/DiskMonitor.swift
    Sources/MacStats/Monitors/ProcessMonitor.swift
    Sources/MacStats/Monitors/BatteryMonitor.swift
    Sources/MacStats/Monitors/WiFiMonitor.swift
    Sources/MacStats/Monitors/SystemMonitor.swift
    Sources/MacStats/ViewModels/StatsViewModel.swift
    Sources/MacStats/Views/Components/UsageBarView.swift
    Sources/MacStats/Views/Components/StatRowView.swift
    Sources/MacStats/Views/Components/SparklineView.swift
    Sources/MacStats/Views/Components/SectionCardView.swift
    Sources/MacStats/Views/Components/SegmentedBarView.swift
    Sources/MacStats/Views/Components/RingView.swift
    Sources/MacStats/Views/CPUDetailView.swift
    Sources/MacStats/Views/MemoryDetailView.swift
    Sources/MacStats/Views/NetworkDetailView.swift
    Sources/MacStats/Views/DiskDetailView.swift
    Sources/MacStats/Views/BatteryDetailView.swift
    Sources/MacStats/Views/WiFiDetailView.swift
    Sources/MacStats/Views/ProcessListView.swift
    Sources/MacStats/Views/SystemInfoHeader.swift
    Sources/MacStats/Views/PopoverContentView.swift
    Sources/MacStats/App/AppDelegate.swift
    Sources/MacStats/App/LocationManager.swift
    Sources/MacStats/App/StatusBarController.swift
    Sources/MacStats/main.swift
)

FRAMEWORKS=(
    -framework AppKit
    -framework SwiftUI
    -framework IOKit
    -framework Combine
    -framework ServiceManagement
    -framework CoreWLAN
    -framework CoreLocation
)

build_debug() {
    echo "Building debug..."
    mkdir -p "$DEBUG_DIR"
    swiftc "${SOURCES[@]}" \
        -sdk "$SDK" \
        -target arm64-apple-macosx13.0 \
        -import-objc-header Sources/MacStats/BridgingHeader.h \
        "${FRAMEWORKS[@]}" \
        -g \
        -o "${DEBUG_DIR}/${APP_NAME}"
    echo "Debug build: ${DEBUG_DIR}/${APP_NAME}"
}

build_release() {
    echo "Building universal release (arm64 + x86_64)..."
    mkdir -p "$RELEASE_DIR"

    # Build arm64
    echo "  Compiling arm64..."
    swiftc "${SOURCES[@]}" \
        -sdk "$SDK" \
        -target arm64-apple-macosx13.0 \
        -import-objc-header Sources/MacStats/BridgingHeader.h \
        "${FRAMEWORKS[@]}" \
        -O -whole-module-optimization \
        -o "${RELEASE_DIR}/${APP_NAME}-arm64"

    # Build x86_64
    echo "  Compiling x86_64..."
    swiftc "${SOURCES[@]}" \
        -sdk "$SDK" \
        -target x86_64-apple-macosx13.0 \
        -import-objc-header Sources/MacStats/BridgingHeader.h \
        "${FRAMEWORKS[@]}" \
        -O -whole-module-optimization \
        -o "${RELEASE_DIR}/${APP_NAME}-x86_64"

    # Merge into universal binary
    echo "  Creating universal binary..."
    lipo -create \
        "${RELEASE_DIR}/${APP_NAME}-arm64" \
        "${RELEASE_DIR}/${APP_NAME}-x86_64" \
        -output "${RELEASE_DIR}/${APP_NAME}"

    # Clean up single-arch binaries
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
