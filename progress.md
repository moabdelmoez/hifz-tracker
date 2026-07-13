# Session Progress Log

## Current State

**Last Updated:** 2026-07-13 22:09 EEST
**Session ID:** ponytail-cleanup-2026-07-13
**Completed Feature:** `ponytail-cleanup-001` - Serial cleanup of all 21 ponytail audit findings.

## Status

### What's Done

- [x] Confirmed the repo root and reviewed the harness, audit, current changes, and recent commits.
- [x] Confirmed the TDD seams with the user before implementation.
- [x] Baseline `swift test`: 130 tests, 1 expected local-audio skip, 0 failures.
- [x] Baseline `swift build`: completed successfully.
- [x] 01 - Stage one ONNX Runtime dylib.
- [x] 02 - Delete completed provisional-highlight plan.
- [x] 03 - Reuse the Pages icon and delete `logo.png`.
- [x] 04 - Replace custom WAV/microphone conversion with AVFAudio.
- [x] 05 - Delete `QuranSTTAssetBundle` and YAML parsing.
- [x] 06 - Delete ONNX metadata reflection.
- [x] 07 - Shrink locator outcome metrics/tests.
- [x] 08 - Replace handwritten FFT/windowing with Accelerate.
- [x] 09 - Delete manual Advance/Correction prototype paths.
- [x] 10 - Delete unused `WordAligner`.
- [x] 11 - Use `ATSApplicationFontsPath` and delete app-wide font registration.
- [x] 12 - Delete unused `RecitationEngine` facade.
- [x] 13 - Delete unshipped `SessionHistoryExporter`.
- [x] 14 - Deduplicate locator helpers.
- [x] 15 - Unify pending-window timing metrics.
- [x] 16 - Centralize release validation/signing.
- [x] 17 - Make Mushaf font naming static.
- [x] 18 - Delete remaining no-effect APIs/settings/marker file.
- [x] 19 - Reuse `RecitationVisualState.tint` in the toolbar.
- [x] 20 - Delete test-only `centeredScrollOffset`.
- [x] 21 - Delete the untracked `.claude/skills` mirror.

### What's Blocked

- Release-only distribution remains externally blocked because no Developer ID Application identity is installed.
- The pre-existing GitHub authentication blocker for `github-pages-site-001` is unchanged and outside this cleanup.

### What's Next

1. Install/configure a Developer ID Application identity before running release packaging.

## Files Modified This Session

- Core/runtime: native AVFAudio and Accelerate paths; smaller ONNX C/Swift bridge; deleted unused facades and helpers.
- App/UI: removed prototype/no-effect paths; native font plist loading; shared visual-state tint.
- Packaging/docs: one staged ONNX dylib; centralized release validation/signing; duplicate logo/plan removed.
- Tests/harness: focused regressions updated or added; audit, feature state, progress, and handoff completed.

## Evidence

- [x] Baseline `swift test`: 130 tests, 1 expected local-audio skip, 0 failures.
- [x] Baseline `swift build`: completed successfully.
- [x] Baseline `git diff --check`: passed.
- [x] Item 01: packaged launch and local release checks passed; the app stages one 35 MB `libonnxruntime.1.dylib`, and `otool` resolves that exact alias.
- [x] Item 02: deleted the completed implementation plan; no non-audit references remain and `git diff --check` passed.
- [x] Item 03: README now reuses `docs/assets/hifz-tracker-icon.png`; the duplicate 1.5 MB root logo is gone and link checks passed.
- [x] Item 04: anti-alias test failed before the native converter existed, then the focused audio/transcriber tests passed; full `swift test` passed 131 tests with 1 expected skip, `swift build` passed, and no production custom WAV/resampling helpers remain.
- [x] Item 05: deleted the unused asset/YAML wrapper and its tests; direct tokenizer loading passed the Ikhlas transcription and local-audio focused checks, and no wrapper symbols remain.
- [x] Item 06: deleted metadata reflection from Swift and the C shim; pinned-version, real inference, and Ikhlas transcription tests passed, with no metadata APIs remaining.
- [x] Item 07: optional locator metrics now default to `nil`; compact whole-value tests cover located, rejected, and view-model failure outcomes and all focused tests passed.
- [x] Item 08: Accelerate replaced 81 lines of handwritten window/FFT machinery; focused normalization, realtime-budget, and real-transcription tests passed, followed by 127 full tests (1 expected skip) and `swift build`.
- [x] Item 09: deleted manual Advance/Correction UI and view-model mutation paths; live-ASR view-model coverage and core correction-state tests all passed.
- [x] Item 10: deleted the unused `WordAligner` and its sole test; decoder and correction reducer tests passed and no aligner references remain.
- [x] Item 11: packaged plist red/green changed from a missing font key to `ATSApplicationFontsPath=Fonts/`; the staged app includes 607 fonts, launches, and all 16 focused font/renderer tests passed.
- [x] Item 12: deleted the unused actor facade and its isolated test; `swift build` passed and no facade references remain.
- [x] Item 13: deleted the unshipped history exporter and its isolated test; stored-session persistence tests passed and no exporter references remain.
- [x] Item 14: consolidated duplicated run-length and phrase-occurrence helpers to one file-private implementation each; all 31 locator tests passed.
- [x] Item 15: one event-driven pending-window metric now handles stores and handoffs while preserving telemetry names; all 26 timing, scheduler, and view-model tests passed.
- [x] Item 16: `release_checks.sh release` now owns release assets and app signing; DMG packaging delegates to it. The gate passed 124 tests (1 expected skip), builds, launch, checksums, and ad-hoc verification, then stopped at the known external blocker: no Developer ID Application identity.
- [x] Item 17: replaced five configurable font-resolver fields with two static QPC V4 functions; bundled-name tests and a representative Tajweed renderer test passed.
- [x] Item 18: deleted the uncalled uncertain/discard APIs, one-choice microphone preference, and empty core marker; microphone conversion and all 19 view-model tests passed.
- [x] Item 19: toolbar status now reuses `RecitationVisualState.tint`; `swift build` passed.
- [x] Item 20: deleted the test-only centered-scroll helper and its test; all five remaining viewport tests passed.
- [x] Item 21: deleted the explicitly approved untracked 39-symlink `.claude/skills` mirror.
- [x] Final local release gate: 123 tests, 1 expected skip, 0 failures; build, staged launch, signature verification, dylib/rpath checks, and bundled-data checksums passed.
- [x] Final static checks: `jq empty feature_list.json`, `bash -n` for all changed scripts, cleanup symbol sweep, and `git diff --check` passed.

## Notes

- Existing uncommitted audit/harness changes are user-owned and will not be reverted.
- Pure deletions use caller/build checks; behavior changes use the confirmed TDD seams.
- No DMG was created; release mode stopped before packaging at the missing Developer ID identity as authorized.
