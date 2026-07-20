# Session Progress Log

## Current State

**Last Updated:** 2026-07-20 13:47 EEST

**Session ID:** same-ayah-repeated-phrase-dmg-2026-07-20

**Active Feature:** None. `same-ayah-repeated-phrase-dmg-001` is complete.

## Status

### What's Done

- [x] Added a canonical Surah 60:1 regression for the stale first-occurrence transcript jumping from word 12 to word 36.
- [x] Added one private generic guard for ambiguous discontinuous post-lock matches inside the current search range.
- [x] Preserved adjacent repeated phrases, unique catch-up, sequential ayah ordering, and timed fresh-evidence behavior.
- [x] Replayed the supplied Surah 60:1–5 recording through 377 production-style rolling windows.
- [x] Removed the temporary WAV and restored the transcript-bearing generated audit to its previous contents.
- [x] Committed the locator fix as `1d87647` and pushed it to `origin/main`.
- [x] Passed the local release gate and replaced the ignored DMG with the updated ad-hoc app.
- [x] Verified, mounted, inspected, and launched the updated DMG, then detached it and removed temporary packaging directories.

### What's Blocked

- Nothing.

## Files Modified This Session

- `Sources/HifzCore/TranscriptPositionLocator.swift` - Reject ambiguous discontinuous repeated-phrase advancement before mutating accepted progress.
- `Tests/HifzCoreTests/ProgressiveTranscriptLocatorTests.swift` - Cover adjacent acceptance, stale-repeat rejection, and normal resumption with Surah 60:1.
- `feature_list.json`, `progress.md`, `session-handoff.md` - Record scope, verification, and continuity.
- `dist/HifzTracker-0.1.0-arm64.dmg` - Rebuilt ignored distribution artifact containing the pushed locator fix.
- Unrelated `.claude/` content and `docs/realtime-performance-audit-2026-07-20.md` were preserved untouched.

## Evidence

- [x] Red regression: current code returned `60:1:36`, matched 2 words, and selected expected range `34..<36` instead of `.notAdvancing(completedOffset: 11, acceptedOffset: 11)`.
- [x] Focused regression passed after the private ambiguity guard.
- [x] Locator suites: 23 progressive tests and 3 outcome tests passed.
- [x] Deterministic replay: 377 windows; no `60:1:36` outcome; progress moved from `60:1:12` at 11.773 s to `60:1:15` at 13.309 s; final location `60:5:13`.
- [x] Replay quality remained 139/140 expected-word LCS (99.29%); processing remained 0.242× realtime.
- [x] Full `swift test`: 144 tests, 1 expected skip, 0 failures.
- [x] `swift build`: passed.
- [x] Original M4A SHA-256 remained `aeb8145107c6a9b48fc9b8f8c07fcc466462b970c3604744695083f21028351a`.
- [x] Temporary `060001.wav` was removed; `artifacts/local-audio-audit.json` was restored to SHA-256 `39065d03ba913449291c8b9bd29e306e964f58c74b9277db04903cb7648dd896`.
- [x] Source commit `1d87647` was pushed directly to `origin/main`.
- [x] `./script/release_checks.sh`: 144 tests, 1 expected skip, 0 failures; build, staged launch, assets, rpaths, and ad-hoc signature checks passed.
- [x] Updated DMG: 520,849,620 bytes; SHA-256 `5d0de05df139b0c52438f7913ed19df017a7c81da1e36aec771ba2d2c2867ad0`; `hdiutil verify` CRC32 `$87E875E6`.
- [x] Mounted app passed deep strict codesign verification and its executable matched the staged SHA-256 `8f9693f1336da055c4b17d117fede96d2a62921cab7941dffe94cc42ee34df52`.
- [x] The app launched directly from the read-only DMG as PID 73847; the verification instance was stopped and the image detached.
- [x] No Developer ID identity is installed; the app remains ad-hoc signed and the DMG is unsigned and not notarized.

## Next Step

No active feature. The pushed locator fix and refreshed local DMG are ready for use; a Developer ID identity is still required for signed and notarized public distribution.
