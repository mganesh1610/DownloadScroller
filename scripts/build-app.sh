#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"
CONFIGURATION="${CONFIGURATION:-release}"
swift build -c "$CONFIGURATION" --product DownloadScroller
BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"
APP_PATH="$PROJECT_ROOT/dist/DownloadScroller.app"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"
cp "$BIN_DIR/DownloadScroller" "$APP_PATH/Contents/MacOS/DownloadScroller"
cp Config/Info.plist "$APP_PATH/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier io.github.mganesh1610.DownloadScroller" "$APP_PATH/Contents/Info.plist"
cp Sources/DownloadScroller/Resources/PrivacyInfo.xcprivacy "$APP_PATH/Contents/Resources/"
swift scripts/generate-icon.swift .build/AppIcon.iconset
iconutil -c icns .build/AppIcon.iconset -o "$APP_PATH/Contents/Resources/AppIcon.icns"
codesign --force --sign "${SIGN_IDENTITY:--}" --options runtime \
  --entitlements Config/DownloadScroller.entitlements "$APP_PATH"
codesign --verify --strict --verbose=2 "$APP_PATH"
printf '\nBuilt %s\n' "$APP_PATH"
printf 'This local build is sandboxed and ad-hoc signed by default; it is not an App Store distribution build.\n'
