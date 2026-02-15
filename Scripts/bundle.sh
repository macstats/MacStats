#!/bin/bash
set -euo pipefail

APP_NAME="MacStats"
BUILD_DIR=".build/release"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS="${CONTENTS}/MacOS"

echo "Building release..."
bash Scripts/build.sh release

echo "Generating icon..."
swift Scripts/generate_icon.swift 2>/dev/null
iconutil -c icns .build/MacStats.iconset -o .build/MacStats.icns

echo "Creating app bundle..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS}" "${CONTENTS}/Resources"

cp "${BUILD_DIR}/${APP_NAME}" "${MACOS}/${APP_NAME}"
cp .build/MacStats.icns "${CONTENTS}/Resources/AppIcon.icns"

cat > "${CONTENTS}/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MacStats</string>
    <key>CFBundleIdentifier</key>
    <string>com.macstats.app</string>
    <key>CFBundleName</key>
    <string>MacStats</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>MacStats needs location access to read the current Wi-Fi network name (SSID) via CoreWLAN.</string>
</dict>
</plist>
PLIST

echo "Signing..."
codesign --force --sign - "${APP_BUNDLE}"

echo "Done! App bundle: ${APP_BUNDLE}"
echo "Run with: open ${APP_BUNDLE}"
