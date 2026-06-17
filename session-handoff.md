# Session Handoff

## Current Objective

- Goal: Add guarded provisional initial highlighting so repeated 2-word near-start evidence can show a visual first highlight before the existing authoritative locator lock.
- Current status: Implementation complete and automated verification passed.
- Branch: `provisional-initial-highlight`.
- Commit status: Not committed.
- Remaining step: On-device recitation/log verification for real-world latency and safety evidence.

## Completed This Session

- [x] Added `.provisional` to `WordProgressState`.
- [x] Rendered provisional state in `MushafPageView` and `MushafPageRenderer`.
- [x] Added `ProvisionalInitialHighlightTracker`.
- [x] Confirmed only exact 2-word candidates after two consecutive matching windows.
- [x] Required candidate start before expected offset 16.
- [x] Required the normalized 2-word phrase to be unique across the selected reference scope.
- [x] Rejected 3+ word candidates so the normal 3-word/4-word locator path stays authoritative.
- [x] Wired `RecitationViewModel` to evaluate provisional evidence only when no committed progress exists and the real locator rejects the transcript.
- [x] Applied provisional highlights as visual-only state without advancing `snapshot.completedWordCount`.
- [x] Cleared provisional visuals on disagreement, lifecycle reset, ASR error, empty transcript/reference, reference invalidation, and authoritative progress.
- [x] Added `live_asr_locator event=provisional_initial_highlight` logs for candidate, confirmed, and cleared states without transcript text or audio.
- [x] Added focused tracker tests and view-model safety tests.

## Verification Evidence

| Check | Command | Result | Notes |
|---|---|---|---|
| Provisional tracker | `env CLANG_MODULE_CACHE_PATH=/private/tmp/hifz-clang-module-cache SWIFT_MODULE_CACHE_PATH=/private/tmp/hifz-swift-module-cache swift test --filter ProvisionalInitialHighlightTrackerTests` | Passed | 8 tests, 0 failures. |
| Locator regression | `env CLANG_MODULE_CACHE_PATH=/private/tmp/hifz-clang-module-cache SWIFT_MODULE_CACHE_PATH=/private/tmp/hifz-swift-module-cache swift test --filter ProgressiveTranscriptLocatorTests` | Passed | 10 tests, 0 failures. |
| View-model safety | `env CLANG_MODULE_CACHE_PATH=/private/tmp/hifz-clang-module-cache SWIFT_MODULE_CACHE_PATH=/private/tmp/hifz-swift-module-cache swift test --filter RecitationViewModelTests` | Passed | 12 tests, 0 failures. |
| Full test suite | `env CLANG_MODULE_CACHE_PATH=/private/tmp/hifz-clang-module-cache SWIFT_MODULE_CACHE_PATH=/private/tmp/hifz-swift-module-cache swift test` | Passed | 103 tests, 1 expected local-audio audit skipped, 0 failures. |
| Build | `env CLANG_MODULE_CACHE_PATH=/private/tmp/hifz-clang-module-cache SWIFT_MODULE_CACHE_PATH=/private/tmp/hifz-swift-module-cache swift build` | Passed | Debug build completed successfully. |

## Files Changed

- `Sources/HifzCore/Models.swift`
- `Sources/HifzCore/MushafPageRenderer.swift`
- `Sources/HifzCore/TranscriptPositionLocator.swift`
- `HifzTracker/Views/MushafPageView.swift`
- `HifzTracker/Services/RecitationViewModel.swift`
- `Tests/HifzCoreTests/ProvisionalInitialHighlightTrackerTests.swift`
- `Tests/HifzCoreTests/ProgressiveTranscriptLocatorTests.swift`
- `Tests/HifzTrackerTests/RecitationViewModelTests.swift`
- `feature_list.json`
- `progress.md`
- `session-handoff.md`
- `docs/superpowers/plans/2026-06-17-guarded-provisional-initial-highlight.md`

## Existing Worktree Context

- This branch was created during the live ASR optimization thread, and earlier uncommitted locator/outcome instrumentation changes are still present in the same worktree.
- Do not revert those changes unless explicitly instructed.
- Before committing, inspect `git diff` and stage intentionally.

## Blockers / Risks

- No code blocker.
- On-device verification has not been run yet. The automated tests prove safety and semantics, but the real user-visible win still needs logs from a live recitation.
- Release checks were skipped because this was not a release, signing, asset, packaging, or distribution change.

## Next Session Startup

1. Read `AGENTS.md`.
2. Read `feature_list.json`, `progress.md`, and this file.
3. Run `git status --short`.
4. Run one on-device recitation and inspect:

```bash
log show --info --last 10m --style compact --predicate 'subsystem == "dev.mostafa.HifzTracker" && category == "ASR" && eventMessage CONTAINS "provisional_initial_highlight"'
```

5. Confirm candidate/confirmed provisional events appear only before committed progress and only for repeated unique 2-word near-start evidence.
