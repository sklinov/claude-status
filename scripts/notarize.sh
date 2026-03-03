#!/bin/bash
set -euo pipefail

# Notarize a macOS .app bundle.
#
# Required environment variables:
#   DEVELOPER_ID_APPLICATION  - e.g. "Developer ID Application: Your Name (TEAMID)"
#   APPLE_ID                  - Your Apple ID email
#   APPLE_TEAM_ID             - Your Apple Developer Team ID
#   APPLE_APP_PASSWORD        - App-specific password (generate at appleid.apple.com)

APP_BUNDLE="${1:-}"

if [ -z "$APP_BUNDLE" ]; then
    echo "Usage: $0 <path-to-app-bundle>"
    echo "Example: $0 build/Claude\\ Status.app"
    exit 1
fi

if [ ! -d "$APP_BUNDLE" ]; then
    echo "Error: $APP_BUNDLE not found"
    exit 1
fi

# Check for required credentials
MISSING=""
[ -z "${DEVELOPER_ID_APPLICATION:-}" ] && MISSING="$MISSING DEVELOPER_ID_APPLICATION"
[ -z "${APPLE_ID:-}" ] && MISSING="$MISSING APPLE_ID"
[ -z "${APPLE_TEAM_ID:-}" ] && MISSING="$MISSING APPLE_TEAM_ID"
[ -z "${APPLE_APP_PASSWORD:-}" ] && MISSING="$MISSING APPLE_APP_PASSWORD"

if [ -n "$MISSING" ]; then
    echo "⚠️  Notarization skipped — missing environment variables:$MISSING"
    echo ""
    echo "To set up notarization:"
    echo "  1. Join the Apple Developer Program (\$99/year) at https://developer.apple.com"
    echo "  2. Create a Developer ID Application certificate in Xcode"
    echo "  3. Generate an app-specific password at https://appleid.apple.com"
    echo "  4. Export the variables:"
    echo ""
    echo "     export DEVELOPER_ID_APPLICATION=\"Developer ID Application: Your Name (TEAMID)\""
    echo "     export APPLE_ID=\"your@email.com\""
    echo "     export APPLE_TEAM_ID=\"YOURTEAMID\""
    echo "     export APPLE_APP_PASSWORD=\"xxxx-xxxx-xxxx-xxxx\""
    echo ""
    exit 0
fi

echo "🔏 Signing $APP_BUNDLE..."

# Sign all contents with hardened runtime
codesign --force --deep --options runtime \
    --sign "$DEVELOPER_ID_APPLICATION" \
    "$APP_BUNDLE"

# Verify signature
codesign --verify --verbose "$APP_BUNDLE"
echo "   ✅ Signed"

# Create zip for notarization submission
ZIP_PATH="${APP_BUNDLE%.app}.zip"
ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"

echo "📤 Submitting to Apple for notarization..."

xcrun notarytool submit "$ZIP_PATH" \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "$APPLE_APP_PASSWORD" \
    --wait

echo "📎 Stapling notarization ticket..."
xcrun stapler staple "$APP_BUNDLE"

# Clean up the submission zip
rm -f "$ZIP_PATH"

echo "✅ Notarization complete!"
