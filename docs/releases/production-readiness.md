# Hifz Tracker Production Readiness

Hifz Tracker is offline at runtime. The app must not make network requests after installation, and it must not persist user audio.

## Local Gate

Run:

```bash
./script/release_checks.sh local
```

This runs the Swift package tests, builds and launches the staged app, and verifies the bundled Quran data, INT8 model, and tokenizer checksums.

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

- `HifzTracker/Resources/Models/model_int8.onnx`
- `HifzTracker/Resources/Tokenizer/tokenizer.json`
- `HifzTracker/Resources/Tokenizer/tokenizer.model`
- `HifzTracker/Resources/Tokenizer/tokenizer_config.json`
- `HifzTracker/Resources/Tokenizer/tokens.txt`
- `HifzTracker/Resources/Tokenizer/model_config.yaml`
- `assets/runtime/onnxruntime-osx-arm64-1.26.0/lib/libonnxruntime.1.26.0.dylib`
- `HifzTracker/Resources/Fonts/p1.ttf` through `HifzTracker/Resources/Fonts/p604.ttf`
- `HifzTracker/Resources/Layout/kfgqpc-v4-layout.sqlite`

Download the KFGQPC V4 layout from [QUL resource 19](https://qul.tarteel.ai/resources/mushaf-layout/19), choose **Download sqlite**, and place it at `assets/layout/qpc-v4-tajweed-15-lines.db`. The setup script copies it into the app bundle as `Resources/Layout/kfgqpc-v4-layout.sqlite` and verifies SHA-256 `4b3fb1cbe8dff749ab0173c4b86cb40fe3c48dd072f41d3c7e715654a9f843cd`.

Prepare the build assets with:

```bash
./script/setup_assets.sh
```

The script downloads the INT8 FastConformer export and matching tokenizer files from a pinned Hugging Face revision, or uses a local copy in `quran-stt-onnx`. It verifies the model checksum and adds the FastConformer CTC blank to the bundled token table when needed. It also prepares ONNX Runtime, the public audio test fixtures, the QPC V4 Tajweed fonts, and the QUL layout database. The build stages only the INT8 model, including when the source workspace contains older model files. [FastConformer export notes](https://huggingface.co/Saboorhsn/quran-stt-onnx/blob/3d3c2336d591990c88e135e2d0292e74897bc56d/README.md)

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
