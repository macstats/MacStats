#!/bin/bash
set -euo pipefail

APP_NAME="MacStats"
BUILD_DIR=".build/release"
DMG_DIR=".build/dmg"
DMG_STAGING="${DMG_DIR}/staging"
DMG_OUTPUT="${DMG_DIR}/${APP_NAME}.dmg"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
VOLUME_NAME="${APP_NAME}"

# Ensure app bundle exists
if [ ! -d "${APP_BUNDLE}" ]; then
    echo "Error: ${APP_BUNDLE} not found. Run 'bash Scripts/bundle.sh' first."
    exit 1
fi

echo "Creating DMG..."

# Clean previous artifacts
rm -rf "${DMG_DIR}"
mkdir -p "${DMG_STAGING}"

# Copy app into staging
cp -R "${APP_BUNDLE}" "${DMG_STAGING}/"

# Create Applications symlink for drag-to-install
ln -s /Applications "${DMG_STAGING}/Applications"

# Create temporary DMG
hdiutil create \
    -volname "${VOLUME_NAME}" \
    -srcfolder "${DMG_STAGING}" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "${DMG_OUTPUT}"

# Clean staging
rm -rf "${DMG_STAGING}"

DMG_SIZE=$(du -sh "${DMG_OUTPUT}" | cut -f1)
echo "Done! DMG: ${DMG_OUTPUT} (${DMG_SIZE})"
echo "Install: open ${DMG_OUTPUT}"
