#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
ARCH="${1:-native}"
BUILD_ARGS=(-c release)
case "$ARCH" in
    native) ;;
    universal) BUILD_ARGS+=(--arch arm64 --arch x86_64) ;;
    *) echo "Usage: bash scripts/build.sh [native|universal]" >&2; exit 1 ;;
esac
swift build "${BUILD_ARGS[@]}"
BIN_DIR="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"
APP="dist/Cursor Drift.app"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN_DIR/CursorDrift" "$APP/Contents/MacOS/CursorDrift"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>CFBundleExecutable</key><string>CursorDrift</string>
    <key>CFBundleIdentifier</key><string>lv.renatsk.cursordrift</string>
    <key>CFBundleName</key><string>Cursor Drift</string>
    <key>CFBundleDisplayName</key><string>Cursor Drift</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
if [[ -n "${SIGN_IDENTITY:-}" ]]; then
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
else
    codesign --force --sign - "$APP"
fi
ZIP="dist/Cursor-Drift-macOS-$ARCH.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
echo "Built: $PWD/$APP"
echo "Archive: $PWD/$ZIP"
