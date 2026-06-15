#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

LOCAL_MODEL_ROOT="${QURAN_STT_ONNX_DIR:-$ROOT_DIR/quran-stt-onnx}"
MODEL_URL="https://huggingface.co/Saboorhsn/quran-stt-onnx/resolve/main/onnx/model_fp32.onnx"
MODEL_PATH="assets/models/model_fp32.onnx"
MODEL_SHA_PATH="assets/models/model_fp32.onnx.sha256"
MODEL_SHA="ba513908fad8172e7edf9ed479adee6ac2723455fdd3289f967aec26cabea93e"
HF_BASE_URL="https://huggingface.co/Saboorhsn/quran-stt-onnx/resolve/main"

ORT_URL="https://github.com/microsoft/onnxruntime/releases/download/v1.26.0/onnxruntime-osx-arm64-1.26.0.tgz"
ORT_PATH="assets/runtime/onnxruntime-osx-arm64-1.26.0.tgz"
ORT_DIR="assets/runtime/onnxruntime-osx-arm64-1.26.0"
ORT_SHA="7a1280bbb1701ea514f71828765237e7896e0f2e1cd332f1f70dbd5c3e33aca3"
QPC_V4_TAJWEED_FONT_BASE_URL="https://static-cdn.tarteel.ai/qul/fonts/quran_fonts/v4-tajweed/ttf"
QPC_V4_TAJWEED_FONT_COUNT=604
QPC_V4_TAJWEED_FONT_DIR="assets/fonts/qpc-v4-tajweed"
QPC_V4_TAJWEED_BUNDLE_DIR="HifzTracker/Resources/Fonts"
QUL_SPECIAL_FONT_DIR="assets/fonts/qul"
QUL_QURAN_COMMON_FONT_URL="https://static-cdn.tarteel.ai/qul/fonts/common/quran-common.ttf?v=3.3"
QUL_SURAH_NAME_V4_FONT_URL="https://static-cdn.tarteel.ai/qul/fonts/surah-names/v4/surah-name-v4.ttf?v=3.3"
QUL_BISMILLAH_FONT_URL="https://static-cdn.tarteel.ai/qul/fonts/bismillah/bismillah.ttf?v=3.3"
QUL_QURAN_COMMON_FONT_SHA="63675d54764c3e0acd3875e191dc6f0af1339ddbd53a1df7fcebbaabebc918fa"
QUL_SURAH_NAME_V4_FONT_SHA="026cfe8ac461531a7b1c8e4edd05ce3343f09e9c73447ff14c6bc93f3193d661"
QUL_BISMILLAH_FONT_SHA="ce8e4b2cf44ab8709fbe90189a9cb54b6a4dc31eb8ab7f6ae68a6403d58b9b69"
LAYOUT_CANONICAL_PATH="assets/layout/kfgqpc-v4-layout.sqlite"
LAYOUT_QUL_DOWNLOAD_PATH="assets/layout/qpc-v4-tajweed-15-lines.db"
LAYOUT_BUNDLE_PATH="HifzTracker/Resources/Layout/kfgqpc-v4-layout.sqlite"
LAYOUT_SHA="4b3fb1cbe8dff749ab0173c4b86cb40fe3c48dd072f41d3c7e715654a9f843cd"

mkdir -p assets/models assets/runtime "$QPC_V4_TAJWEED_FONT_DIR" "$QUL_SPECIAL_FONT_DIR" assets/layout assets/tokenizer HifzTracker/Resources/Models "$QPC_V4_TAJWEED_BUNDLE_DIR" HifzTracker/Resources/Layout HifzTracker/Resources/Tokenizer

download_if_missing() {
  local url="$1"
  local path="$2"
  if [ -f "$path" ]; then
    echo "exists: $path"
    return
  fi
  echo "download: $url"
  curl -L "$url" -o "$path"
}

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

verify_local_quran_assets() {
  verify_sha "HifzTracker/Resources/qpc-v4.db" "4bf9549dfcfd367d4d4b151bd58b51af63b677d1c980cf5e52541c2f981d7e6d"
  verify_sha "HifzTracker/Resources/quran-simple-clean.txt" "054b3d9f79c0c2e44df7f9ddf42561797b3b5cb4fbdafbf2e99c805ccf1a6b49"
}

copy_local_model_assets_if_present() {
  if [ ! -f "$LOCAL_MODEL_ROOT/onnx/model_fp32.onnx" ]; then
    return 1
  fi

  echo "using local Quran STT assets: $LOCAL_MODEL_ROOT"
  cp "$LOCAL_MODEL_ROOT/onnx/model_fp32.onnx" "$MODEL_PATH"
  verify_sha "$MODEL_PATH" "$MODEL_SHA"
  echo "$MODEL_SHA" >"$MODEL_SHA_PATH"

  for tokenizer_asset in tokenizer.json tokenizer.model tokenizer_config.json tokens.txt model_config.yaml; do
    cp "$LOCAL_MODEL_ROOT/$tokenizer_asset" "assets/tokenizer/$tokenizer_asset"
  done
  return 0
}

verify_local_quran_assets

if ! copy_local_model_assets_if_present; then
  download_if_missing "$MODEL_URL" "$MODEL_PATH"
  if [ -f "$MODEL_SHA_PATH" ]; then
    verify_sha "$MODEL_PATH" "$(cat "$MODEL_SHA_PATH")"
  else
    verify_sha "$MODEL_PATH" "$MODEL_SHA"
    echo "$MODEL_SHA" >"$MODEL_SHA_PATH"
  fi

  for tokenizer_asset in tokenizer.json tokenizer.model tokenizer_config.json tokens.txt model_config.yaml; do
    download_if_missing "$HF_BASE_URL/$tokenizer_asset" "assets/tokenizer/$tokenizer_asset"
  done
fi

cp "$MODEL_PATH" "HifzTracker/Resources/Models/model_fp32.onnx"

for tokenizer_asset in tokenizer.json tokenizer.model tokenizer_config.json tokens.txt model_config.yaml; do
  cp "assets/tokenizer/$tokenizer_asset" "HifzTracker/Resources/Tokenizer/$tokenizer_asset"
done

download_if_missing "$QUL_QURAN_COMMON_FONT_URL" "$QUL_SPECIAL_FONT_DIR/quran-common.ttf"
download_if_missing "$QUL_SURAH_NAME_V4_FONT_URL" "$QUL_SPECIAL_FONT_DIR/surah-name-v4.ttf"
download_if_missing "$QUL_BISMILLAH_FONT_URL" "$QUL_SPECIAL_FONT_DIR/bismillah.ttf"
verify_sha "$QUL_SPECIAL_FONT_DIR/quran-common.ttf" "$QUL_QURAN_COMMON_FONT_SHA"
verify_sha "$QUL_SPECIAL_FONT_DIR/surah-name-v4.ttf" "$QUL_SURAH_NAME_V4_FONT_SHA"
verify_sha "$QUL_SPECIAL_FONT_DIR/bismillah.ttf" "$QUL_BISMILLAH_FONT_SHA"
cp "$QUL_SPECIAL_FONT_DIR/quran-common.ttf" "$QPC_V4_TAJWEED_BUNDLE_DIR/quran-common.ttf"
cp "$QUL_SPECIAL_FONT_DIR/surah-name-v4.ttf" "$QPC_V4_TAJWEED_BUNDLE_DIR/surah-name-v4.ttf"
cp "$QUL_SPECIAL_FONT_DIR/bismillah.ttf" "$QPC_V4_TAJWEED_BUNDLE_DIR/bismillah.ttf"

if [ -f "$ORT_PATH" ]; then
  verify_sha "$ORT_PATH" "$ORT_SHA"
  if [ ! -d "$ORT_DIR" ]; then
    tar -xzf "$ORT_PATH" -C "assets/runtime"
  fi
  if [ ! -f "$ORT_DIR/lib/libonnxruntime.1.26.0.dylib" ]; then
    echo "missing extracted ONNX Runtime dylib: $ORT_DIR/lib/libonnxruntime.1.26.0.dylib" >&2
    exit 1
  fi
else
  echo "ONNX Runtime archive not present at $ORT_PATH; native inference linking remains a later release step."
fi

for page in $(seq 1 "$QPC_V4_TAJWEED_FONT_COUNT"); do
  font_file="p${page}.ttf"
  download_if_missing "$QPC_V4_TAJWEED_FONT_BASE_URL/$font_file" "$QPC_V4_TAJWEED_FONT_DIR/$font_file"
  cp "$QPC_V4_TAJWEED_FONT_DIR/$font_file" "$QPC_V4_TAJWEED_BUNDLE_DIR/$font_file"
done

if [ -f "$LAYOUT_CANONICAL_PATH" ]; then
  verify_sha "$LAYOUT_CANONICAL_PATH" "$LAYOUT_SHA"
  cp "$LAYOUT_CANONICAL_PATH" "$LAYOUT_BUNDLE_PATH"
elif [ -f "$LAYOUT_QUL_DOWNLOAD_PATH" ]; then
  verify_sha "$LAYOUT_QUL_DOWNLOAD_PATH" "$LAYOUT_SHA"
  cp "$LAYOUT_QUL_DOWNLOAD_PATH" "$LAYOUT_BUNDLE_PATH"
else
  echo "Missing KFGQPC V4 layout DB"
  echo "Download sqlite from https://qul.tarteel.ai/resources/mushaf-layout/19 and place it at $LAYOUT_QUL_DOWNLOAD_PATH before release."
fi

echo "Asset setup complete."
