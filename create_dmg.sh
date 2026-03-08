#!/bin/bash

set -euo pipefail

APP_NAME="iSnap"
INFO_PLIST="Resources/Info.plist"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${INFO_PLIST}")
DMG_NAME="${APP_NAME}-v${VERSION}-macos.dmg"
VOLUME_NAME="${APP_NAME} v${VERSION}"
DIST_DIR="dist"
STAGING_DIR="${DIST_DIR}/dmg-staging"

if [[ ! -d "${APP_NAME}.app" ]]; then
    echo "Error: ${APP_NAME}.app not found. Run ./build_app.sh first."
    exit 1
fi

mkdir -p "${DIST_DIR}"
rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"

cp -R "${APP_NAME}.app" "${STAGING_DIR}/"
ln -s /Applications "${STAGING_DIR}/Applications"

rm -f "${DIST_DIR}/${DMG_NAME}"
hdiutil create \
    -volname "${VOLUME_NAME}" \
    -srcfolder "${STAGING_DIR}" \
    -ov \
    -format UDZO \
    "${DIST_DIR}/${DMG_NAME}"

rm -rf "${STAGING_DIR}"

echo "DMG created: ${DIST_DIR}/${DMG_NAME}"
