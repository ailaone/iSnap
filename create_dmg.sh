#!/bin/bash

VERSION="0.2.0"
APP_NAME="iSnap"
DMG_NAME="${APP_NAME}-v${VERSION}-macos"

# Create temporary DMG directory
mkdir -p dmg_temp
cp -r "dist/${APP_NAME}.app" dmg_temp/

# Create Applications symlink
ln -s /Applications dmg_temp/Applications

# Create DMG
hdiutil create -volname "${APP_NAME} v${VERSION}" \
  -srcfolder dmg_temp \
  -ov \
  -format UDZO \
  "dist/${DMG_NAME}.dmg"

# Cleanup
rm -rf dmg_temp

echo "DMG created: dist/${DMG_NAME}.dmg"
