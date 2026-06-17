# Session Progress Log

## Current State

**Last Updated:** 2026-06-17 23:20 EEST
**Session ID:** hide-ayah-marker-state-order-2026-06-17
**Active Feature:** `hide-ayah-marker-state-order-001` - residual Hide Ayah marker-state and first-lock ordering fixes are implemented, verified, and relaunched locally.

## Status

### What's Done

- [x] Confirmed repo root with `pwd`.
- [x] Read `AGENTS.md`, `feature_list.json`, `progress.md`, and the active `session-handoff.md`.
- [x] Reviewed `git status --short` and recent commits before editing.
- [x] Used the diagnose workflow: built focused failing tests before changing production code.
- [x] Verified the real ayah-number cause in the QPC data:
  - QPC Surah 88:1 has rows `88:1:1` through `88:1:5`, while the normalized recitation reference has 4 real words after non-Fatihah basmallah removal.
  - QPC Surah 110:3 has rows `110:3:1` through `110:3:8`, while the normalized recitation reference has 7 real words.
  - The extra QPC row is the ayah marker; it was staying `.pending`, so Hide Ayah hid it.
- [x] Added `RecitationViewModel` marker-state inheritance so marker rows reveal when the final real word in the ayah is completed, provisional, uncertain, or correction-needed.
- [x] Reproduced the Surah 98 jump with a failing locator test: the first lock accepted a far repeated phrase at expected range `48..<56`.
- [x] Added an `initial_match_too_far` locator outcome and rejected first locks starting at expected offset 32 or later before progress has been established.
- [x] Added live outcome probe metrics coverage for `initial_match_too_far`.
- [x] Added Surah 110 locator regressions proving deterministic initial-lock and post-lock transcripts ending with `توابا` complete `110:3:7`.
- [x] Added renderer coverage that hiding only the Surah 110 marker does not clip the final visible words.
- [x] Updated `feature_list.json` with `hide-ayah-marker-state-order-001` and corrected the previous stale marker diagnosis.
- [x] Rebuilt, signed, and relaunched `dist/HifzTracker.app` with `./script/build_and_run.sh --verify`.

### What's In Progress

- [ ] User smoke test in the relaunched app window for Hide Ayah on Surah 88, Surah 98, and Surah 110.

### What's Next

1. User smoke-tests the relaunched app:
   - Surah 88 / Al-Ghashiyah: completed ayahs should show their ayah number medallions.
   - Surah 98 / Al-Bayyinah from ayah 1: reciting the ayah 6 phrase should not move the locator to ayah 6 before earlier progress is established.
   - Surah 110 / An-Nasr: trailing transcript through `توابا` should reveal the final real word; if it still does not, capture live locator logs because the deterministic core tests now cover and pass that transcript.
2. Commit and push the current changes if the user asks.

## Blockers / Risks

- [ ] No automated UI-level microphone run was captured; the app bundle was relaunched, but final visual confirmation remains a manual app-window smoke test.
- [ ] If Surah 110 still hides the actual word `توابا` after this patch, the next likely area is live-window transcript timing/state application, not the deterministic core locator. The test suite proves both first-lock and post-lock trailing transcripts can complete `110:3:7`.
- [ ] Release checks are skipped because this change does not touch release assets, signing configuration, packaging, or distribution behavior.

## Decisions Made

- **Marker interpretation:** QPC rows beyond the normalized reference word count are treated as marker rows for visibility inheritance.
- **Marker reveal rule:** A marker row reveals only when the final real word of the same ayah is already visible by feedback state.
- **Initial lock guard:** Before any accepted progress, strong matches starting at expected offset 32 or later are rejected. The offset is relative to the selected start scope, so selecting a later ayah still allows that ayah to lock at offset 0.
- **Surah 110 conclusion:** The core locator does not reject `توابا` for the supplied trailing transcript. A remaining live-only failure would need live ASR locator logs.

## Files Modified This Session

- `Sources/HifzCore/TranscriptPositionLocator.swift` - Added `initialMatchTooFar` outcome and first-lock far-match rejection.
- `HifzTracker/Services/LiveASRLocatorOutcomeProbe.swift` - Added metrics mapping for `initial_match_too_far`.
- `HifzTracker/Services/RecitationViewModel.swift` - Added QPC ayah-marker state inheritance from the final real word.
- `Tests/HifzCoreTests/ProgressiveTranscriptLocatorTests.swift` - Added Surah 98 far-lock regression and Surah 110 final-word regressions.
- `Tests/HifzTrackerTests/LiveASRLocatorOutcomeProbeTests.swift` - Added `initial_match_too_far` metrics coverage.
- `Tests/HifzTrackerTests/RecitationViewModelTests.swift` - Added marker-row reveal regression.
- `Tests/HifzCoreTests/MushafPageRendererTests.swift` - Added guard that hiding a marker does not clip final visible words.
- `feature_list.json` - Added current feature and corrected the stale previous marker evidence.
- `progress.md` - Recorded current diagnosis and verification evidence.
- `session-handoff.md` - Updated restart notes for this fix.

## Evidence of Completion

- [x] Red locator repro: focused test initially failed because Surah 98 phrase `إن الذين كفروا من أهل الكتاب والمشركين في` was accepted at `98:6:8`, expected range `48..<56`, before any accepted progress.
- [x] Red marker repro: `RecitationViewModelTests/testHideRecitationTextRevealsCompletedAyahMarkerRows` initially failed because marker row `88:1:5` remained hidden after real word `88:1:4` completed.
- [x] Focused regression check passed 4 tests:
  - `ProgressiveTranscriptLocatorTests/testInitialLockCompletesSurahNasrFinalWordFromTrailingTranscript`
  - `ProgressiveTranscriptLocatorTests/testPostLockCompletesSurahNasrFinalWordFromTrailingTranscript`
  - `ProgressiveTranscriptLocatorTests/testRejectsFarRepeatedStrongMatchBeforeInitialLock`
  - `RecitationViewModelTests/testHideRecitationTextRevealsCompletedAyahMarkerRows`
- [x] Full `swift test` passed 128 tests with 1 expected local-audio skip and 0 failures.
- [x] Full `swift build` completed successfully.
- [x] App bundle verification: `./script/build_and_run.sh --verify` exited 0 after rebuilding, signing, and relaunching `dist/HifzTracker.app`.

## Notes for Next Session

Start in `/Users/mostafa/Downloads/Coding_Projects/hifz-tracker` on `main`. The current changes are verified but uncommitted. Do not claim a live microphone/UI behavior is visually confirmed until the user smoke-tests the relaunched app or a UI automation/log replay is added.
