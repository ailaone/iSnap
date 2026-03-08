#!/bin/bash

set -euo pipefail

APP_NAME="iSnap"
INFO_PLIST="Resources/Info.plist"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${INFO_PLIST}")
DMG_PATH="dist/${APP_NAME}-v${VERSION}-macos.dmg"
KEYCHAIN_PROFILE="${ISNAP_NOTARY_PROFILE:-iSnapNotary}"

if [[ ! -f "${DMG_PATH}" ]]; then
    echo "Error: ${DMG_PATH} not found. Run ./create_dmg.sh first."
    exit 1
fi

echo "Submitting ${DMG_PATH} for notarization..."
SUBMISSION_OUTPUT=$(xcrun notarytool submit "${DMG_PATH}" \
    --keychain-profile "${KEYCHAIN_PROFILE}" \
    --wait \
    --output-format json)

echo "${SUBMISSION_OUTPUT}"

SUBMISSION_ID=$(printf '%s' "${SUBMISSION_OUTPUT}" | plutil -extract id raw -)

echo "Fetching notarization log..."
xcrun notarytool log "${SUBMISSION_ID}" \
    --keychain-profile "${KEYCHAIN_PROFILE}" \
    "dist/notarization-log-${VERSION}.json"

echo "Stapling ${DMG_PATH}..."
xcrun stapler staple "${DMG_PATH}"

echo "Verifying stapled DMG..."
spctl -a -vvv -t install "${DMG_PATH}"

echo "Notarization complete."
