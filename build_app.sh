#!/bin/bash

set -euo pipefail

APP_NAME="iSnap"
INFO_PLIST="Resources/Info.plist"
BUILD_PATH="/tmp/iSnapBuild"
BUILD_DIR="${BUILD_PATH}/apple/Products/Release"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
SIGN_APP="${ISNAP_SIGN_APP:-0}"
SIGNING_IDENTITY="${ISNAP_SIGNING_IDENTITY:-}"

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${INFO_PLIST}")
BUILD_NUMBER=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "${INFO_PLIST}")

echo "Building ${APP_NAME} ${VERSION} (${BUILD_NUMBER})..."

# Build a universal binary for Apple Silicon and Intel Macs.
swift build -c release \
  --arch arm64 \
  --arch x86_64 \
  --build-path "${BUILD_PATH}"

# Create App Bundle Structure
echo "Creating App Bundle..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Copy Executable
cp "${BUILD_DIR}/${APP_NAME}" "${MACOS_DIR}/"

# Strip debug symbols to reduce size
echo "Stripping binary..."
strip -rSTx "${MACOS_DIR}/${APP_NAME}"

# Copy Info.plist
cp -f "Resources/Info.plist" "${CONTENTS_DIR}/"

# Ensure Icon Exists
./create_icns.sh

# Compile Icon Composer file
if [ -d "Resources/icon.icon" ]; then
    echo "Compiling Icon Composer file..."
    xcrun actool --compile "${RESOURCES_DIR}" \
        --platform macosx \
        --minimum-deployment-target 13.0 \
        --app-icon icon \
        --output-partial-info-plist "${CONTENTS_DIR}/partial-info.plist" \
        --output-format human-readable-text \
        "Resources/icon.icon"
    
    if [ $? -eq 0 ]; then
        echo "Icon compiled successfully!"
    else
        echo "Warning: Icon compilation failed"
    fi
else
    echo "Warning: icon.icon not found!"
fi

# Copy Icons Folder
if [ -d "Resources/icons" ]; then
    cp -r "Resources/icons" "${RESOURCES_DIR}/"
    # Remove the large source PNG from the bundle to save space (8MB -> <1MB)
    rm -f "${RESOURCES_DIR}/icons/Logo-new.png"
fi

# Remove .DS_Store files
find "${RESOURCES_DIR}" -name ".DS_Store" -delete

# Metadata
echo "APPL????" > "${CONTENTS_DIR}/PkgInfo"

if [[ "${SIGN_APP}" == "1" ]]; then
    if [[ -z "${SIGNING_IDENTITY}" ]]; then
        echo "Error: ISNAP_SIGN_APP=1 but ISNAP_SIGNING_IDENTITY is not set."
        exit 1
    fi

    echo "Signing ${APP_BUNDLE}..."
    codesign --deep --force --verify --verbose \
        --options runtime \
        --sign "${SIGNING_IDENTITY}" \
        "${APP_BUNDLE}"
fi

echo "Build Complete: ${APP_BUNDLE}"
echo "To run: open ${APP_BUNDLE}"
