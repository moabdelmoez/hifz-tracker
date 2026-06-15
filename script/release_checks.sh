#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-local}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
LAYOUT_BUNDLE_PATH="HifzTracker/Resources/Layout/kfgqpc-v4-layout.sqlite"
LAYOUT_SHA="4b3fb1cbe8dff749ab0173c4b86cb40fe3c48dd072f41d3c7e715654a9f843cd"
ORT_ARCHIVE_PATH="assets/runtime/onnxruntime-osx-arm64-1.26.0.tgz"
ORT_ARCHIVE_SHA="7a1280bbb1701ea514f71828765237e7896e0f2e1cd332f1f70dbd5c3e33aca3"
ORT_DYLIB_PATH="assets/runtime/onnxruntime-osx-arm64-1.26.0/lib/libonnxruntime.1.26.0.dylib"
ORT_DYLIB_SHA="30afadcfc3c704f7671f8430d6252956651c1972373901d2be629da2e6a4d8ee"
STAGED_ORT_DYLIB_PATH="dist/HifzTracker.app/Contents/Frameworks/libonnxruntime.1.dylib"
STAGED_APP_BINARY="dist/HifzTracker.app/Contents/MacOS/HifzTracker"

export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-/private/tmp/hifz-clang-module-cache}"
export SWIFT_MODULE_CACHE_PATH="${SWIFT_MODULE_CACHE_PATH:-/private/tmp/hifz-swift-module-cache}"

verify_sha() {
  local path="$1"
  local expected="$2"
  local actual
  actual="$(shasum -a 256 "$path" | awk '{print $1}')"
  if [ "$actual" != "$expected" ]; then
    echo "sha256 mismatch for $path" >&2
    echo "expected: $expected" >&2
    echo "actual:   $actual" >&2
    exit 1
  fi
}

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

require_qul_header_fonts() {
  require_file "HifzTracker/Resources/Fonts/quran-common.ttf"
  require_file "HifzTracker/Resources/Fonts/surah-name-v4.ttf"
  require_file "HifzTracker/Resources/Fonts/bismillah.ttf"
  verify_sha "HifzTracker/Resources/Fonts/quran-common.ttf" "63675d54764c3e0acd3875e191dc6f0af1339ddbd53a1df7fcebbaabebc918fa"
  verify_sha "HifzTracker/Resources/Fonts/surah-name-v4.ttf" "026cfe8ac461531a7b1c8e4edd05ce3343f09e9c73447ff14c6bc93f3193d661"
  verify_sha "HifzTracker/Resources/Fonts/bismillah.ttf" "ce8e4b2cf44ab8709fbe90189a9cb54b6a4dc31eb8ab7f6ae68a6403d58b9b69"
}

require_no_local_runtime_rpath() {
  if otool -l "$STAGED_APP_BINARY" | grep "$ROOT_DIR/assets/runtime" >/dev/null; then
    echo "staged app binary contains a local ONNX Runtime rpath" >&2
    exit 1
  fi
}

swift test
swift build
./script/build_and_run.sh --verify
codesign --verify --strict --verbose=2 "dist/HifzTracker.app"
require_file "$STAGED_ORT_DYLIB_PATH"
require_no_local_runtime_rpath

verify_sha "HifzTracker/Resources/qpc-v4.db" "4bf9549dfcfd367d4d4b151bd58b51af63b677d1c980cf5e52541c2f981d7e6d"
verify_sha "HifzTracker/Resources/quran-simple-clean.txt" "054b3d9f79c0c2e44df7f9ddf42561797b3b5cb4fbdafbf2e99c805ccf1a6b49"
require_qul_header_fonts

if [ "$MODE" = "release" ]; then
  require_file "HifzTracker/Resources/Models/model_fp32.onnx"
  verify_sha "HifzTracker/Resources/Models/model_fp32.onnx" "ba513908fad8172e7edf9ed479adee6ac2723455fdd3289f967aec26cabea93e"
  require_file "$ORT_ARCHIVE_PATH"
  verify_sha "$ORT_ARCHIVE_PATH" "$ORT_ARCHIVE_SHA"
  require_file "$ORT_DYLIB_PATH"
  verify_sha "$ORT_DYLIB_PATH" "$ORT_DYLIB_SHA"
  require_file "HifzTracker/Resources/Tokenizer/tokenizer.json"
  require_file "HifzTracker/Resources/Tokenizer/tokenizer.model"
  require_file "HifzTracker/Resources/Tokenizer/tokenizer_config.json"
  require_file "HifzTracker/Resources/Tokenizer/tokens.txt"
  require_file "HifzTracker/Resources/Tokenizer/model_config.yaml"
  require_qpc_v4_tajweed_fonts
  require_file "$LAYOUT_BUNDLE_PATH"
  verify_sha "$LAYOUT_BUNDLE_PATH" "$LAYOUT_SHA"
  security find-identity -p codesigning -v | grep "Developer ID Application" >/dev/null
  codesign -dvvv --entitlements :- "dist/HifzTracker.app"
  spctl -a -vv "dist/HifzTracker.app"
else
  echo "Local checks passed. Run '$0 release' after installing model/font/layout and signing the app."
fi
