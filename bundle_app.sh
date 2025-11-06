#!/bin/bash

# Build the executable
swift build

# Create app bundle structure
APP_NAME="MultilingualRecognizer"
BUILD_DIR=".build/debug"
APP_DIR="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

# Clean and create directories
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Copy executable
cp "${BUILD_DIR}/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"

# Copy Info.plist
cp Info.plist "${CONTENTS_DIR}/Info.plist"

# Sign the app with entitlements
codesign --force --sign - --entitlements MultilingualRecognizer.entitlements --deep "${APP_DIR}"

echo "App bundle created and signed at ${APP_DIR}"
echo "Run with: open ${APP_DIR}"
