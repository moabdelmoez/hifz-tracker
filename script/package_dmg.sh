#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 tester|release" >&2
}

if [ "$#" -ne 1 ]; then
  usage
  exit 64
fi

MODE="$1"
case "$MODE" in
  tester|release) ;;
  *)
    usage
    exit 64
    ;;
esac

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="HifzTracker"
APP_BUNDLE="dist/$APP_NAME.app"
DMG_PATH="dist/HifzTracker-0.1.0-arm64.dmg"
CHECKSUM_PATH="$DMG_PATH.sha256"
SIGN_IDENTITY="${DEVELOPER_ID_APPLICATION:-}"
NOTARY_PROFILE="${NOTARYTOOL_PROFILE:-}"

create_dmg() {
  rm -f "$DMG_PATH" "$CHECKSUM_PATH"
  hdiutil create -volname "Hifz Tracker" -srcfolder "$APP_BUNDLE" -ov -format UDZO "$DMG_PATH"
}

write_checksum() {
  local dmg_name
  dmg_name="$(basename "$DMG_PATH")"
  (
    cd "$(dirname "$DMG_PATH")"
    shasum -a 256 "$dmg_name" >"$(basename "$CHECKSUM_PATH")"
  )
}

if [ "$MODE" = "tester" ]; then
  ./script/release_checks.sh tester
  create_dmg
  hdiutil verify "$DMG_PATH"

  if codesign -d "$DMG_PATH" >/dev/null 2>&1; then
    echo "Tester DMG must remain unsigned so it cannot be mistaken for an Apple-verified release." >&2
    exit 1
  fi

  write_checksum
  echo "Tester DMG created at $DMG_PATH"
  echo "Checksum created at $CHECKSUM_PATH"
  echo "This tester build is not Apple-notarized and requires the per-app Open Anyway flow."
  exit 0
fi

if [ -z "$NOTARY_PROFILE" ]; then
  echo "NOTARYTOOL_PROFILE is required for release packaging." >&2
  exit 1
fi

if [ -z "$SIGN_IDENTITY" ]; then
  SIGN_IDENTITY="$(security find-identity -p codesigning -v | awk -F '"' '/Developer ID Application/ {print $2; exit}')"
fi

if [ -z "$SIGN_IDENTITY" ]; then
  echo "No Developer ID Application signing identity found." >&2
  exit 1
fi

DEVELOPER_ID_APPLICATION="$SIGN_IDENTITY" ./script/release_checks.sh release
create_dmg
codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG_PATH"
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
spctl -a -vv -t open --context context:primary-signature "$DMG_PATH"
hdiutil verify "$DMG_PATH"
write_checksum
echo "Notarized release DMG created at $DMG_PATH"
echo "Checksum created at $CHECKSUM_PATH"
