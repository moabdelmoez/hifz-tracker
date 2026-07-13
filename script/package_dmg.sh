#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="HifzTracker"
APP_BUNDLE="dist/$APP_NAME.app"
DMG_PATH="dist/HifzTracker-0.1.0-arm64.dmg"
SIGN_IDENTITY="${DEVELOPER_ID_APPLICATION:-}"
NOTARY_PROFILE="${NOTARYTOOL_PROFILE:-}"

./script/release_checks.sh release

if [ -z "$SIGN_IDENTITY" ]; then
  SIGN_IDENTITY="$(security find-identity -p codesigning -v | awk -F '"' '/Developer ID Application/ {print $2; exit}')"
fi

if [ -z "$SIGN_IDENTITY" ]; then
  echo "No Developer ID Application signing identity found." >&2
  exit 1
fi

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
