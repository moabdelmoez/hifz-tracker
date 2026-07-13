<p align="center">
  <img src="docs/assets/hifz-tracker-icon.png" alt="Hifz Tracker logo" width="128">
</p>

# Hifz Tracker

Hifz Tracker is a private, offline-first macOS app for Quran memorization practice. Choose a surah and start ayah, recite into your Mac, and follow live Mushaf highlights while session progress is saved locally.

**Page URL:** [https://moabdelmoez.github.io/hifz-tracker/](https://moabdelmoez.github.io/hifz-tracker/)

**Download:** [Latest GitHub Release](https://github.com/moabdelmoez/hifz-tracker/releases/latest)

## Features

<p align="center">
  <img src="docs/assets/hifztracker-demo.gif" alt="Hifz Tracker recitation session demo" width="860">
</p>

- Live recitation sessions with surah selection, start-ayah control, recording controls, and session status.
- QPC V4 Tajweed Mushaf page rendering with automatic page movement as recitation advances.
- Local ASR-backed progress highlighting through `HifzCore`, Quran reference words, and ONNX Runtime.
- Cross-surah live highlighting so progress can continue into the immediate next surah.
- Hide Ayah mode that hides unrecited text from the selected start ayah while revealing completed or flagged words.
- Dashboard window with word-based progress summaries across all 114 surahs.
- Voice activity indicator for active recording sessions.
- Local session persistence with SwiftData.
- Privacy-oriented runtime: no user audio persistence and no runtime network requirement after installation.

## Tech Stack

- Swift 6 and Swift Package Manager.
- macOS 14+ SwiftUI app target.
- SwiftData for local session records.
- `HifzCore` library for Quran references, Mushaf rendering, transcript locating, recitation state, and ASR helpers.
- ONNX Runtime 1.26.0 for local Quran STT inference through `COnnxRuntimeShim`.
- SQLite-backed Quran resources, QPC V4 word glyphs, Tanzil reference text, and QUL/QPC font assets.
- XCTest coverage for core recitation logic, renderer behavior, live ASR scheduling, dashboard progress, and app view-model flows.
- Static GitHub Pages site under `docs/`.

## Logo And Project Page

- Repository logo: [`docs/assets/hifz-tracker-icon.png`](docs/assets/hifz-tracker-icon.png)
- Project page: [moabdelmoez.github.io/hifz-tracker](https://moabdelmoez.github.io/hifz-tracker/)

## Repository Layout

```text
HifzTracker/              macOS SwiftUI app, views, services, models, resources
Sources/HifzCore/         Core recitation, Quran, ASR, renderer, and storage logic
Sources/COnnxRuntimeShim/ C bridge target for ONNX Runtime headers
Tests/                    HifzCore and HifzTracker test suites
docs/                     Static GitHub Pages site
script/                   Build, asset setup, release check, and packaging scripts
```

## Local Development

Requirements:

- macOS 14 or later.
- Apple Silicon Mac for the packaged runtime path.
- Swift 6 toolchain or a recent Xcode toolchain that supports the package.

Run the standard verification checks:

```bash
swift test
swift build
```

Build and launch the local app bundle:

```bash
./script/build_and_run.sh
```

For release-sensitive checks, use:

```bash
./script/release_checks.sh
```

Run `./script/setup_assets.sh` only when preparing model, font, layout, or release assets.

## Privacy Notes

Hifz Tracker is designed to run offline after installation. The app listens locally for recitation progress and does not persist user audio.
