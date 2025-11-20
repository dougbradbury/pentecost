#!/bin/bash

set -e

echo "🔨 Building Pentecost..."

# Build with Swift Package Manager
swift build --product PentecostGUI

# Create app bundle structure
APP_NAME="Pentecost"
BUNDLE_DIR="$APP_NAME.app"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "📦 Creating app bundle structure..."
rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy executable
echo "📋 Copying executable..."
cp ".build/debug/PentecostGUI" "$MACOS_DIR/$APP_NAME"

# Create Info.plist
echo "📝 Creating Info.plist..."
cat > "$CONTENTS_DIR/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Pentecost</string>
    <key>CFBundleIdentifier</key>
    <string>com.myagro.pentecost</string>
    <key>CFBundleName</key>
    <string>Pentecost</string>
    <key>CFBundleDisplayName</key>
    <string>Pentecost</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>Pentecost needs microphone access to perform real-time speech recognition and translation.</string>
    <key>NSSpeechRecognitionUsageDescription</key>
    <string>Pentecost needs speech recognition to provide multilingual translation services.</string>
</dict>
</plist>
EOF

# Create entitlements file if it doesn't exist
if [ ! -f "Pentecost.entitlements" ]; then
    echo "📝 Creating entitlements file..."
    cat > "Pentecost.entitlements" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.device.audio-input</key>
    <true/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
</dict>
</plist>
EOF
fi

# Sign the app with entitlements
echo "🔐 Signing app bundle..."
codesign --force --deep --sign - --entitlements Pentecost.entitlements "$BUNDLE_DIR"

echo ""
echo "✅ App bundle created: $BUNDLE_DIR"
echo "🚀 Run with: open $BUNDLE_DIR"
echo ""
echo "The GUI app will properly request permissions!"
