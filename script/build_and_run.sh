#!/usr/bin/env bash
set -euo pipefail

# Single kill → build → launch entrypoint for MacStats.
#
# MacStats is a menu-bar-only AppKit/SwiftUI app, so it is always launched as
# a real .app bundle (a bare executable would miss foreground activation and
# bundle metadata). The build itself goes through Scripts/build.sh because it
# is the path that works with a Command Line Tools–only install.
#
# Modes: run (default) | --debug | --logs | --verify

MODE="${1:-run}"
APP_NAME="MacStats"
BUNDLE_ID="com.macstats.app"
MIN_SYSTEM_VERSION="13.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

bash "$ROOT_DIR/Scripts/build.sh" debug
BUILD_BINARY="$ROOT_DIR/.build/debug/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

if [ -f "$ROOT_DIR/.build/MacStats.icns" ]; then
  cp "$ROOT_DIR/.build/MacStats.icns" "$APP_CONTENTS/AppIcon.icns"
fi

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>2.0.0</string>
  <key>CFBundleVersion</key>
  <string>2.0.0</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>NSLocationWhenInUseUsageDescription</key>
  <string>MacStats needs location access to read the current Wi-Fi network name (SSID) via CoreWLAN.</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP_BUNDLE" >/dev/null 2>&1 || true

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --verify|verify)
    open_app
    sleep 2
    pgrep -x "$APP_NAME" >/dev/null
    echo "$APP_NAME is running from $APP_BUNDLE"
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--verify]" >&2
    exit 2
    ;;
esac
