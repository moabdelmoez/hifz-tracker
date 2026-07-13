# Hifz Tracker Production Readiness

Hifz Tracker is offline at runtime. The app must not make network requests after installation, and it must not persist user audio.

## Local Gate

Run:

```bash
./script/release_checks.sh
```

This verifies the Swift package tests, builds the macOS app, launches the staged bundle, and checks the bundled Quran data checksums.

## Release Gate

Before public distribution, install these assets:

- `HifzTracker/Resources/Models/model_fp32.onnx`
- `HifzTracker/Resources/Tokenizer/tokenizer.json`
- `HifzTracker/Resources/Tokenizer/tokenizer.model`
- `HifzTracker/Resources/Tokenizer/tokenizer_config.json`
- `HifzTracker/Resources/Tokenizer/tokens.txt`
- `HifzTracker/Resources/Tokenizer/model_config.yaml`
- `assets/runtime/onnxruntime-osx-arm64-1.26.0/lib/libonnxruntime.1.26.0.dylib`
- `HifzTracker/Resources/Fonts/p1.ttf` through `HifzTracker/Resources/Fonts/p604.ttf`
- `HifzTracker/Resources/Layout/kfgqpc-v4-layout.sqlite`

Download the KFGQPC V4 layout from [QUL resource 19](https://qul.tarteel.ai/resources/mushaf-layout/19), choose **Download sqlite**, and place it at `assets/layout/qpc-v4-tajweed-15-lines.db`. The setup script copies it into the app bundle as `Resources/Layout/kfgqpc-v4-layout.sqlite` and verifies SHA-256 `4b3fb1cbe8dff749ab0173c4b86cb40fe3c48dd072f41d3c7e715654a9f843cd`.

If the Hugging Face repo has already been cloned/downloaded locally at `quran-stt-onnx`, run:

```bash
./script/setup_assets.sh
```

The script copies `quran-stt-onnx/onnx/model_fp32.onnx` and tokenizer/config files into the app resources, verifies the pinned fp32 checksum, extracts the pinned ONNX Runtime archive, downloads the QUL QPC V4 Tajweed page fonts from `https://static-cdn.tarteel.ai/qul/fonts/quran_fonts/v4-tajweed/ttf/p{page}.ttf`, and installs the QUL layout DB.

Then sign and notarize the app with Developer ID credentials and run:

```bash
./script/release_checks.sh release
```

The release gate validates release assets and signs the staged app. It must pass before publishing a DMG.

## DMG Packaging

After the release gate passes, create a signed DMG:

```bash
DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)" ./script/package_dmg.sh
```

To notarize and staple automatically, also set `NOTARYTOOL_PROFILE` to a stored `xcrun notarytool` keychain profile.
