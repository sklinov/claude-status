#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
VERSION="${1:-}"

if [ -z "$VERSION" ]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 1.0.0"
    exit 1
fi

echo "🚀 Building ClaudeStatus v${VERSION}..."
echo ""

# Update version in Info.plist
sed -i '' "s|<string>[0-9]*\.[0-9]*\.[0-9]*</string>\(<!--version-->\)|<string>${VERSION}</string>\1|g" "$PROJECT_DIR/Info.plist"
# Update CFBundleVersion and CFBundleShortVersionString
# Replace the version string that follows CFBundleVersion key
python3 -c "
import plistlib, sys
with open('$PROJECT_DIR/Info.plist', 'rb') as f:
    plist = plistlib.load(f)
plist['CFBundleVersion'] = '$VERSION'
plist['CFBundleShortVersionString'] = '$VERSION'
with open('$PROJECT_DIR/Info.plist', 'wb') as f:
    plistlib.dump(plist, f)
"

echo "   Updated Info.plist to v${VERSION}"

# Build
"$PROJECT_DIR/build.sh"

APP_BUNDLE="$PROJECT_DIR/build/Claude Status.app"

# Notarize (skips gracefully if credentials not set)
"$SCRIPT_DIR/notarize.sh" "$APP_BUNDLE"

# Package
DIST_DIR="$PROJECT_DIR/dist"
mkdir -p "$DIST_DIR"
ZIP_NAME="ClaudeStatus-${VERSION}.zip"
ZIP_PATH="$DIST_DIR/$ZIP_NAME"

rm -f "$ZIP_PATH"
cd "$PROJECT_DIR/build"
ditto -c -k --keepParent "Claude Status.app" "$ZIP_PATH"
cd "$PROJECT_DIR"

SHA256=$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Release artifact ready!"
echo ""
echo "   File:    $ZIP_PATH"
echo "   Size:    $(du -h "$ZIP_PATH" | awk '{print $1}')"
echo "   SHA-256: $SHA256"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Next steps:"
echo ""
echo "  1. Create a GitHub release:"
echo "     gh release create v${VERSION} '$ZIP_PATH' \\"
echo "       --title 'v${VERSION}' \\"
echo "       --notes 'Claude Status v${VERSION}'"
echo ""
echo "  2. Update the Homebrew formula SHA-256:"
echo "     In Formula/claude-status.rb, set:"
echo "       sha256 \"$SHA256\""
echo "       version \"$VERSION\""
echo ""
