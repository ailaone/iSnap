#!/bin/bash

# Build the executable
# Use /tmp to avoid network drive locking issues
swift build -c release --build-path /tmp/iSnapBuild

# Define variables
APP_NAME="iSnap"
BUILD_DIR="/tmp/iSnapBuild/release"
APP_BUNDLE="${APP_NAME}.app"
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
