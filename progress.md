# Session Progress Log

## Current State

**Last Updated:** 2026-07-16 21:34 EEST

**Session ID:** strict-fresh-ayah-order-2026-07-16

**Completed Feature:** `strict-fresh-ayah-order-001` - Strict fresh evidence at every ayah boundary.

## Status

### What's Done

- [x] Confirmed repo root and preserved the untracked `.claude/` directory.
- [x] Reviewed the live Surah 72 locator session and reproduced the unfinished-ayah jump in a deterministic core replay.
- [x] Confirmed the normal contiguous matcher and current-or-successor search boundary are the cause; gap recovery and UI mapping are not.
- [x] Baseline `swift test` passed 132 tests with 1 expected skip; baseline `swift build` passed.
- [x] Registered the active feature before source edits.
- [x] Restricted initial/provisional matching to the selected start ayah and every later update to one ayah.
- [x] Preserved CTC frame ranges through SentencePiece word decoding and mapped them to absolute rolling-window sample ranges.
- [x] Required next-ayah evidence to start after the accepted final word while retaining same-window post-boundary words for later updates.
- [x] Added privacy-safe `fresh_evidence_required` and `invalid_word_timing` diagnostics; invalid timing holds progress without an error UI.
- [x] Updated the local-audio audit to exercise the production timed-evidence path.
- [x] Passed focused tests, opt-in local-audio/model replay, full tests, and build verification.

### What's Blocked

- No current blocker.

## Files Modified This Session

- `Sources/HifzCore/TranscriptPositionLocator.swift` - Enforced one-ayah search and fresh sample-boundary evidence.
- `Sources/HifzCore/RecitationCore.swift`, `QuranSTTTokenizer.swift`, `QuranSTTTranscriber.swift` - Preserved CTC token/word timing and validated absolute word evidence.
- `Sources/HifzCore/LiveASRSampleWindow.swift` - Added absolute sample ranges to emitted rolling windows.
- `HifzTracker/Services/LiveASRRequestScheduler.swift`, `RecitationViewModel.swift`, `LiveASRLocatorOutcomeProbe.swift` - Carried timing through live inference and logged fail-closed outcomes.
- Locator, transcriber, sample-window, scheduler, view-model, audit, and outcome tests - Added strict-order, stale-overlap, timing, and integration regressions.
- `feature_list.json`, `progress.md`, `session-handoff.md` - Recorded scope, implementation, and evidence.

## Evidence

- [x] Live logs: `72:4:6 -> 72:5:9`, `72:5:9 -> 72:6:2`, and `72:6:2 -> 72:7:6` crossed unfinished ayah boundaries.
- [x] Deterministic replay: `FAIL premature ayah advance: first=72:1:5 second=72:2:4`.
- [x] Cause probe: wide search returned `72:2:4`; current-ayah-only search returned `nil`.
- [x] Baseline full tests and build passed.
- [x] Regression: unfinished `72:1:5` no longer advances into the repeated phrase at `72:2:4`.
- [x] Timed locator regressions prove stale pre-boundary words are rejected and same-window post-boundary words are reusable on the next update.
- [x] CTC/tokenizer/model fixture tests prove token frames become validated absolute word sample ranges.
- [x] Focused locator/provisional suites passed 30 tests; focused ASR/view-model suites passed.
- [x] Opt-in `LocalAudioAuditTests/testLocalAudioASRAudit` passed in 32.703 s using local WAV/model fixtures.
- [x] Final `swift test` passed 140 tests with 1 expected opt-in skip and 0 failures in 45.244 s.
- [x] Final `swift build` passed.
- [x] No audio or transcript persistence was introduced; runtime remains offline.
- [x] Release checks skipped because no release assets, signing, packaging, dependencies, or distribution inputs changed.

## Next Step

No implementation work remains. A manual live Surah 72 recitation is optional confirmation of microphone-session behavior.
