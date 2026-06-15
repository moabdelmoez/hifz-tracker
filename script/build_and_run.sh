#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="HifzTracker"
BUNDLE_ID="dev.mostafa.HifzTracker"
MIN_SYSTEM_VERSION="14.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_FRAMEWORKS="$APP_CONTENTS/Frameworks"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ENTITLEMENTS="$DIST_DIR/$APP_NAME.entitlements"
ORT_LIB_SOURCE="$ROOT_DIR/assets/runtime/onnxruntime-osx-arm64-1.26.0/lib/libonnxruntime.1.26.0.dylib"

export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-/private/tmp/hifz-clang-module-cache}"
export SWIFT_MODULE_CACHE_PATH="${SWIFT_MODULE_CACHE_PATH:-/private/tmp/hifz-swift-module-cache}"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

cd "$ROOT_DIR"
swift build
BUILD_DIR="$(swift build --show-bin-path)"
BUILD_BINARY="$BUILD_DIR/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_FRAMEWORKS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"
install_name_tool -delete_rpath "$ROOT_DIR/assets/runtime/onnxruntime-osx-arm64-1.26.0/lib" "$APP_BINARY" >/dev/null 2>&1 || true

cp -R "$ROOT_DIR/HifzTracker/Resources/." "$APP_RESOURCES/"

if [ -f "$ORT_LIB_SOURCE" ]; then
  cp "$ORT_LIB_SOURCE" "$APP_FRAMEWORKS/libonnxruntime.1.dylib"
  cp "$ORT_LIB_SOURCE" "$APP_FRAMEWORKS/libonnxruntime.1.26.0.dylib"
  cp "$ORT_LIB_SOURCE" "$APP_FRAMEWORKS/libonnxruntime.dylib"
fi

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>Hifz Tracker</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSMicrophoneUsageDescription</key>
  <string>Hifz Tracker listens locally to highlight Quran recitation progress. Audio is not saved.</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

cat >"$ENTITLEMENTS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.app-sandbox</key>
  <true/>
  <key>com.apple.security.device.audio-input</key>
  <true/>
</dict>
</plist>
PLIST

if command -v codesign >/dev/null 2>&1; then
  find "$APP_FRAMEWORKS" -type f -name "*.dylib" -exec codesign --force --sign - {} \;
  codesign --force --sign - --entitlements "$ENTITLEMENTS" "$APP_BUNDLE"
fi

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
