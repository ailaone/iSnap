#!/bin/bash

# Source SVG
SOURCE_SVG="Resources/icons/iSnap-menubar-logo.svg"
TEMP_PNG="/tmp/snapmark_icon_source.png"

# Check if SVG exists
if [ ! -f "$SOURCE_SVG" ]; then
    echo "Error: Source SVG not found at $SOURCE_SVG"
    exit 1
fi

echo "Converting SVG to PNG..."
# Use custom swift script to preserve transparency
swift render_svg.swift "$SOURCE_SVG" "$TEMP_PNG" 1024

if [ ! -f "$TEMP_PNG" ]; then
    echo "Error: Failed to convert SVG to PNG"
    exit 1
fi

SOURCE="$TEMP_PNG"
ICONSET="Resources/iSnap.iconset"
mkdir -p "$ICONSET"

# Resizing
sips -z 16 16     "$SOURCE" --out "${ICONSET}/icon_16x16.png"
sips -z 32 32     "$SOURCE" --out "${ICONSET}/icon_16x16@2x.png"
sips -z 32 32     "$SOURCE" --out "${ICONSET}/icon_32x32.png"
sips -z 64 64     "$SOURCE" --out "${ICONSET}/icon_32x32@2x.png"
sips -z 128 128   "$SOURCE" --out "${ICONSET}/icon_128x128.png"
sips -z 256 256   "$SOURCE" --out "${ICONSET}/icon_128x128@2x.png"
sips -z 256 256   "$SOURCE" --out "${ICONSET}/icon_256x256.png"
sips -z 512 512   "$SOURCE" --out "${ICONSET}/icon_256x256@2x.png"
sips -z 512 512   "$SOURCE" --out "${ICONSET}/icon_512x512.png"
sips -z 1024 1024 "$SOURCE" --out "${ICONSET}/icon_512x512@2x.png"

# Convert to icns
iconutil -c icns "$ICONSET" -o "Resources/AppIcon.icns"

# Clean up
rm -rf "$ICONSET"
rm -f "$TEMP_PNG"
echo "Resources/AppIcon.icns created successfully."
