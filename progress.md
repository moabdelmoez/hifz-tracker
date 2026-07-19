# Session Progress Log

## Current State

**Last Updated:** 2026-07-19 19:22 EEST

**Session ID:** live-recitation-performance-dmg-2026-07-19

**Active Feature:** `live-recitation-performance-dmg-001` - publish the completed work and refresh the local ad-hoc DMG.

## Status

### What's Done

- [x] Extended the opt-in local audio audit from one ayah to a bounded ayah range without changing its default behavior.
- [x] Replayed the supplied Surah 60:1–5 recording through 377 production-style rolling windows.
- [x] Measured recognition, locator outcomes, progress milestones, latency, cadence, and processing cost.
- [x] Isolated a repeated-phrase locator continuity defect in ayah 1.
- [x] Saved a privacy-safe report at `docs/surah-60-1-5-offline-replay.md`.
- [x] Removed the temporary WAV, symlink, and transcript-bearing generated audit; preserved the original M4A unchanged.

### What's Blocked

- Developer ID signing and notarization are unavailable; the requested refresh will preserve the existing ad-hoc distribution path.
- The locator defect is documented but intentionally not fixed in this release scope.

## Files Modified This Session

- `Tests/HifzCoreTests/LocalAudioAuditTests.swift` - Add a validated end-ayah selector and range-aware audit summaries.
- `docs/surah-60-1-5-offline-replay.md` - Record the privacy-safe evidence, diagnosis, and next step.
- `feature_list.json`, `progress.md`, `session-handoff.md` - Record scope, evidence, and continuity.
- Existing uncommitted performance changes and unrelated `.claude/` content were preserved.

## Evidence

- [x] Source: 97.408 s AAC, 48 kHz mono; SHA-256 `aeb8145107c6a9b48fc9b8f8c07fcc466462b970c3604744695083f21028351a` before and after replay.
- [x] Focused replay: passed in 24.375 s; 377 windows; completed through `60:5:13`.
- [x] Coverage: expected-word LCS 139/140 (99.29%). Rolling-window aggregate WER/precision are not decision metrics because prior words repeat in each window.
- [x] Latency: first transcript 1,046.378 ms; first authoritative highlight 5,952.165 ms; no provisional highlight before authoritative progress.
- [x] Processing: 23,469.454 ms total, 0.241× realtime; per-window p50/p95/max 62.947/65.131/72.509 ms at a 255.938 ms cadence.
- [x] Root cause: progress reached `60:1:12` at 11.835 s, falsely jumped to the repeated phrase at `60:1:36` at 12.348 s on a two-word match, then stalled 15.356 s before `60:1:38`.
- [x] Outcome counts: 79 progress applied, 189 not advancing, 78 no match, 31 fresh evidence required.
- [x] Full `swift test`: 143 tests, 1 expected skip, 0 failures.
- [x] `swift build`: passed.
- [ ] Release checks skipped: no bundled assets, signing, packaging, dependencies, schema, model, or distribution inputs changed.

## Next Step

Commit and push the intended changes to `main`, run the local release gate, then build and verify the replacement ad-hoc DMG.
