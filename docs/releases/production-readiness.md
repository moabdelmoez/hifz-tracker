# Hifz Tracker Production Readiness

Hifz Tracker is offline at runtime. The app must not make network requests after installation, and it must not persist user audio.

## Local Gate

Run:

```bash
./script/release_checks.sh local
```

This verifies the Swift package tests, builds the macOS app, launches the staged bundle, and checks the bundled Quran data checksums.

## Free Tester Gate

The free tester path is complete but not Apple-trusted distribution. The app is ad-hoc
signed, and the DMG is deliberately unsigned and not notarized. Users must approve each
newly downloaded copy through System Settings → Privacy & Security → Open Anyway.

After installing every release asset listed below, run:

```bash
./script/release_checks.sh tester
./script/package_dmg.sh tester
```

The tester packaging command creates:

- `dist/HifzTracker-0.1.0-arm64.dmg`
- `dist/HifzTracker-0.1.0-arm64.dmg.sha256`

It validates all runtime assets, the app's ad-hoc signature, sandbox and microphone
entitlements, and the DMG image. Never describe this artifact as signed, notarized,
Apple-verified, or warning-free.

## Apple-Verified Release Gate

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

For warning-free distribution, install a Developer ID Application certificate and store
notarytool credentials in a keychain profile. Then run:

```bash
DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)" \
NOTARYTOOL_PROFILE="hifz-tracker-notary" \
./script/package_dmg.sh release
```

Release packaging refuses to continue unless both the Developer ID identity and notary
profile are available. It validates release assets, signs with hardened runtime and a
secure timestamp, submits to Apple's notary service, staples the ticket, and verifies
Gatekeeper acceptance before producing the checksum.
