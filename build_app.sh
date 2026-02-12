#!/bin/bash

# Build the executable
# Use /tmp to avoid network drive locking issues
# V0.2.0: Build Universal Binary (Intel + Apple Silicon)
swift build -c release --arch arm64 --arch x86_64 --build-path /tmp/iSnapBuild

# Define variables
APP_NAME="iSnap"
BUILD_DIR="/tmp/iSnapBuild/apple/Products/Release"
APP_BUNDLE="dist/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

# Create App Bundle Structure
echo "Creating App Bundle..."
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

echo "Build Complete: ${APP_BUNDLE}"
echo "To run: open ${APP_BUNDLE}"

# --- Code Signing & Notarization (Optional) ---
# To enable signing, set the following environment variables before running:
# export DEVELOPER_ID="Developer ID Application: Your Name (TEAM_ID)"
# export TEAM_ID="YOUR_TEAM_ID"
# export APPLE_ID="your@email.com"
# export APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx"

if [ -n "$DEVELOPER_ID" ]; then
    echo "Signing app with: $DEVELOPER_ID"
    codesign --deep --force --verify --verbose \
      --sign "$DEVELOPER_ID" \
      --options runtime \
      "$MACOS_DIR/$APP_NAME"

    echo "Verifying signature..."
    codesign --verify --verbose "$APP_BUNDLE"
else
    # Ad-hoc sign so macOS TCC (screen recording permission) works.
    # Without any signature, macOS 15+ ignores permission grants entirely.
    echo "Ad-hoc signing app bundle..."
    codesign --force --deep --sign - "$APP_BUNDLE"
    echo "Ad-hoc signed. Note: you must re-grant Screen Recording permission after each rebuild."
fi

# Notarization (requires signing first)
if [ -n "$DEVELOPER_ID" ] && [ -n "$APP_SPECIFIC_PASSWORD" ]; then
    echo "Creating archive for notarization..."
    ditto -c -k --keepParent "$APP_BUNDLE" iSnap-notarize.zip
    
    echo "Submitting to Apple Notary Service..."
    xcrun notarytool submit iSnap-notarize.zip \
      --apple-id "$APPLE_ID" \
      --team-id "$TEAM_ID" \
      --password "$APP_SPECIFIC_PASSWORD" \
      --wait
      
    echo "Stapling ticket..."
    xcrun stapler staple "$APP_BUNDLE"
    
    rm iSnap-notarize.zip
    echo "Notarization Complete!"
fi
