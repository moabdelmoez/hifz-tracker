#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="HifzTracker"
APP_BUNDLE="dist/$APP_NAME.app"
DMG_PATH="dist/HifzTracker-0.1.0-arm64.dmg"
ENTITLEMENTS="dist/$APP_NAME.entitlements"
APP_FRAMEWORKS="$APP_BUNDLE/Contents/Frameworks"
SIGN_IDENTITY="${DEVELOPER_ID_APPLICATION:-}"
NOTARY_PROFILE="${NOTARYTOOL_PROFILE:-}"

require_file() {
  local path="$1"
  if [ ! -f "$path" ]; then
    echo "missing required release asset: $path" >&2
    exit 1
  fi
}

require_qpc_v4_tajweed_fonts() {
  local font_count=604
  for page in $(seq 1 "$font_count"); do
    require_file "HifzTracker/Resources/Fonts/p${page}.ttf"
  done
}

./script/release_checks.sh
require_file "HifzTracker/Resources/Models/model_fp32.onnx"
require_file "HifzTracker/Resources/Tokenizer/tokenizer.json"
require_file "HifzTracker/Resources/Tokenizer/tokenizer.model"
require_file "HifzTracker/Resources/Tokenizer/tokenizer_config.json"
require_file "HifzTracker/Resources/Tokenizer/tokens.txt"
require_file "HifzTracker/Resources/Tokenizer/model_config.yaml"
require_qpc_v4_tajweed_fonts
require_file "HifzTracker/Resources/Layout/kfgqpc-v4-layout.sqlite"
require_file "$APP_FRAMEWORKS/libonnxruntime.1.dylib"

if [ -z "$SIGN_IDENTITY" ]; then
  SIGN_IDENTITY="$(security find-identity -p codesigning -v | awk -F '\"' '/Developer ID Application/ {print $2; exit}')"
fi

if [ -z "$SIGN_IDENTITY" ]; then
  echo "No Developer ID Application signing identity found." >&2
  exit 1
fi

find "$APP_FRAMEWORKS" -type f -name "*.dylib" -exec codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" {} \;
codesign --force --options runtime --timestamp --entitlements "$ENTITLEMENTS" --sign "$SIGN_IDENTITY" "$APP_BUNDLE"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

rm -f "$DMG_PATH"
hdiutil create -volname "Hifz Tracker" -srcfolder "$APP_BUNDLE" -ov -format UDZO "$DMG_PATH"
codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG_PATH"

if [ -n "$NOTARY_PROFILE" ]; then
  xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG_PATH"
  spctl -a -vv -t open --context context:primary-signature "$DMG_PATH"
else
  echo "DMG created at $DMG_PATH"
  echo "Set NOTARYTOOL_PROFILE to submit and staple automatically."
fi
