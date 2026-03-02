#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Claude Status"
BUNDLE_NAME="ClaudeStatus"
BUILD_DIR="$SCRIPT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "🔨 Building $APP_NAME..."

# Clean
rm -rf "$BUILD_DIR"

# Create .app bundle structure
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Compile Swift
swiftc \
    -o "$APP_BUNDLE/Contents/MacOS/$BUNDLE_NAME" \
    -framework Cocoa \
    -target arm64-apple-macos12.0 \
    "$SCRIPT_DIR/main.swift"

# Also build x86_64 and create universal binary (if on Apple Silicon)
if swiftc \
    -o "$BUILD_DIR/${BUNDLE_NAME}_x86" \
    -framework Cocoa \
    -target x86_64-apple-macos12.0 \
    "$SCRIPT_DIR/main.swift" 2>/dev/null; then

    swiftc \
        -o "$BUILD_DIR/${BUNDLE_NAME}_arm" \
        -framework Cocoa \
        -target arm64-apple-macos12.0 \
        "$SCRIPT_DIR/main.swift"

    lipo -create \
        "$BUILD_DIR/${BUNDLE_NAME}_arm" \
        "$BUILD_DIR/${BUNDLE_NAME}_x86" \
        -output "$APP_BUNDLE/Contents/MacOS/$BUNDLE_NAME"

    rm -f "$BUILD_DIR/${BUNDLE_NAME}_arm" "$BUILD_DIR/${BUNDLE_NAME}_x86"
    echo "   ✅ Universal binary (arm64 + x86_64)"
else
    echo "   ✅ Single architecture binary"
fi

# Copy Info.plist
cp "$SCRIPT_DIR/Info.plist" "$APP_BUNDLE/Contents/"

echo ""
echo "✅ Built successfully!"
echo "   $APP_BUNDLE"
echo ""
echo "To install, run:"
echo "   cp -r \"$APP_BUNDLE\" /Applications/"
echo ""
echo "To launch:"
echo "   open \"$APP_BUNDLE\""
echo ""
echo "To auto-start at login:"
echo "   osascript -e 'tell application \"System Events\" to make login item at end with properties {path:\"/Applications/$APP_NAME.app\", hidden:true}'"
