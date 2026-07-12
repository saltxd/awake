#!/usr/bin/env bash
# Build a universal (arm64 + x86_64) Awake.app and zip it for distribution.
# Produces Awake.app and Awake.app.zip in the repo root.
#
# Usage: ./release.sh [version]   (version defaults to 1.1.0)
set -euo pipefail

APP_NAME="Awake"
DISPLAY_NAME="Awake"
BUNDLE_ID="com.saltxd.awake"
VERSION="${1:-1.1.0}"; VERSION="${VERSION#v}"   # accept v1.1.0 or 1.1.0

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP="$ROOT/$APP_NAME.app"
ZIP="$ROOT/$APP_NAME.app.zip"

echo "▶ Building universal (release, arm64 + x86_64)…"
swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/$APP_NAME"

echo "▶ Assembling $APP_NAME.app…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>$DISPLAY_NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

echo "▶ Ad-hoc signing…"
codesign --force --sign - "$APP"

echo "▶ Zipping (ditto, preserves the bundle)…"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo ""
echo "✅ $APP"
echo "✅ $ZIP  ($(du -h "$ZIP" | cut -f1))"
echo "   arches: $(lipo -archs "$APP/Contents/MacOS/$APP_NAME")"
echo ""
echo "  Attach to a GitHub release:"
echo "    gh release upload v$VERSION \"$ZIP\" --clobber"
