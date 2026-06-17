# Session Progress Log

## Current State

**Last Updated:** 2026-06-17 22:55 EEST
**Session ID:** guarded-short-ayah-initial-lock-2026-06-17
**Active Feature:** `guarded-short-ayah-initial-lock-001` - locator and hide-renderer fixes verified; rebuilt app bundle is open for user smoke testing.

## Status

### What's Done

- [x] Confirmed repo root with `pwd`.
- [x] Read `AGENTS.md`, `feature_list.json`, `progress.md`, and `session-handoff.md`.
- [x] Reviewed recent git status and log.
- [x] Added `/.worktrees/` to `.gitignore` on `main` and committed `7cce406 Ignore local worktrees`.
- [x] Created isolated worktree `.worktrees/hide-ayah-toggle`.
- [x] Used branch `codex-hide-ayah-toggle` because creating `codex/hide-ayah-toggle` was blocked by local Git ref permissions in this environment.
- [x] Linked ignored local asset directories/files into the worktree so SwiftPM tests match the main checkout environment.
- [x] Ran baseline `swift test` and `swift build`; both passed before feature edits after asset links were in place.
- [x] Added a session-only `Hide` toggle under `Start ayah`.
- [x] Added view-model text visibility rules that keep hide mode out of recitation progress state.
- [x] Extended Mushaf rendering with a defaulted `visibilityProvider` that suppresses hidden glyphs and highlights while preserving layout.
- [x] Applied the same hide/no-leak behavior to the fallback word grid.
- [x] Added focused tests for view-model hide rules, renderer suppression, and fallback text hiding.
- [x] Updated `feature_list.json` with `hide-ayah-toggle-001`.
- [x] Committed feature branch as `7e57eed Add hide ayah toggle`.
- [x] Fast-forward merged `codex-hide-ayah-toggle` into `main`.
- [x] Removed `.worktrees/hide-ayah-toggle` and deleted the merged local feature branch.
- [x] Renamed the setup row label from `Hide` to `Hide Ayah`.
- [x] Added `MushafPageNumberFormatter` to render Arabic-Indic page footer digits.
- [x] Applied the QPC page font path to the Mushaf page footer number.
- [x] Added focused formatter coverage in `MushafPageCanvasViewTests`.
- [x] Added `hide-ayah-polish-001` to `feature_list.json`.
- [x] Reproduced the locator jump with a failing Al-Ghashiyah regression: `وجوه يومئذ ناعمة` initial-locked ayah 88:8 before the locator had accepted the start neighborhood.
- [x] Limited the complete-short-ayah initial-lock exception to the near-start neighborhood.
- [x] Added focused tests for rejecting the later confused short ayah and accepting nearby complete short ayahs.
- [x] Added hide-renderer coverage for preserving revealed-ayah marker ink when following words are hidden.
- [x] Changed hide-mode QPC rendering to draw the full line once through visible-word clips instead of redrawing each visible word separately.
- [x] Tightened the hide-renderer marker regression to assert ornamental ayah-marker medallion pixels on a mixed visible/hidden Al-Ghashiyah line.
- [x] Rebuilt, signed, and relaunched `dist/HifzTracker.app` from the current checkout with `./script/build_and_run.sh --verify`.
- [x] Added `guarded-short-ayah-initial-lock-001` to `feature_list.json`.

### What's In Progress

- [ ] User app-window smoke test for Hide Ayah on Al-Ghashiyah.

### What's Next

1. Use the relaunched app window to visually smoke-test Hide Ayah on Al-Ghashiyah.
2. Commit the verified bugfix when ready.

## Blockers / Risks

- [ ] The app bundle was rebuilt and relaunched, but Codex could not capture the live display (`screencapture` failed with "could not create image from display"), so user visual confirmation is still needed.
- [ ] Release checks are skipped because this is not a release, signing, asset, packaging, or distribution change.
- [ ] The feature worktree required local symlinks for ignored assets during verification; the worktree has now been removed.

## Decisions Made

- **Session-only toggle:** `hideRecitationText` is an in-memory `RecitationViewModel` property, not `@AppStorage`.
- **Render policy:** Hide mode uses a visibility helper instead of adding a new `WordProgressState`.
- **No current-word hint:** `.current` target words are hidden in Hide mode.
- **Feedback visible:** `.completed`, `.provisional`, `.uncertain`, and `.correctionNeeded` words remain visible.
- **Practical markers:** Surah headers and basmallah remain visible; embedded ayah markers reveal with their carrying glyph.
- **Worktree branch:** The intended `codex/hide-ayah-toggle` branch name could not be created here, so the feature branch is `codex-hide-ayah-toggle`.
- **Local merge:** `codex-hide-ayah-toggle` was merged to `main` as a fast-forward and then deleted.
- **Page footer digits:** The footer remains a plain page number, now formatted with Arabic-Indic digits and the QPC page font instead of adding a decorative circle.
- **Locator jump cause:** Before the locator locked, the complete-short-ayah exception could accept a later short ayah from ASR confusion; Al-Ghashiyah ayah 8 was accepted when ayah 2 was likely intended.
- **Marker diagnosis:** The user-visible failure happens on mixed visible/hidden QPC lines. Redrawing visible words individually loses the page-font ayah marker medallions. Hidden-word rendering now draws the full line once and clips to visible word slots, preserving line-level glyph behavior while still suppressing hidden text and highlights.

## Files Modified This Session

- `HifzTracker/Views/RecitationSidebarView.swift` - Renamed the Hide row label to Hide Ayah.
- `HifzTracker/Views/MushafPageView.swift` - Added Arabic-Indic page-number formatting and QPC font styling for the footer.
- `Tests/HifzTrackerTests/MushafPageCanvasViewTests.swift` - Added page-number formatter coverage.
- `Sources/HifzCore/TranscriptPositionLocator.swift` - Guarded complete-short-ayah initial locks to the near-start neighborhood.
- `Sources/HifzCore/MushafPageRenderer.swift` - Draws hidden-word lines through visible-word clips to avoid per-word QPC redraws.
- `Tests/HifzCoreTests/ProgressiveTranscriptLocatorTests.swift` - Added Al-Ghashiyah locator jump regressions.
- `Tests/HifzCoreTests/MushafPageRendererTests.swift` - Added hide-mode ayah-marker renderer coverage.
- `feature_list.json` - Added `hide-ayah-polish-001`.
- `progress.md` - Recorded current state and evidence.
- `session-handoff.md` - Updated restart notes for this polish.

## Evidence of Completion

- [x] Baseline `swift test` passed 112 tests with 2 expected skips and 0 failures after local ignored assets were linked into the worktree.
- [x] Baseline `swift build` completed successfully.
- [x] Red check: `swift test --filter 'RecitationViewModelTests/testHideRecitationText|MushafPageRendererTests/testVisibilityProviderSuppressesHiddenWordsWithoutChangingPageSize|MushafWordGlyphPresentationTests'` failed because the planned APIs did not exist yet.
- [x] Focused green check: the same filter passed 7 tests with 0 failures.
- [x] Pre-artifact full check: `swift test` passed 119 tests with 2 expected skips and 0 failures.
- [x] Final post-artifact `swift test` passed 119 tests with 2 expected skips and 0 failures.
- [x] Final post-artifact `swift build` completed successfully.
- [x] Merged `main` verification: `swift test` passed 119 tests with 1 expected skip and 0 failures.
- [x] Merged `main` verification: `swift build` completed successfully.
- [x] Polish baseline `swift test` passed 119 tests with 1 expected skip and 0 failures.
- [x] Polish baseline `swift build` completed successfully.
- [x] Focused polish check: `swift test --filter MushafPageCanvasViewTests` passed 6 tests with 0 failures.
- [x] Final polish `swift test` passed 120 tests with 1 expected skip and 0 failures.
- [x] Final polish `swift build` completed successfully.
- [x] Pre-push `swift test` passed 120 tests with 1 expected skip and 0 failures.
- [x] Pre-push `swift build` completed successfully.
- [x] Red locator check failed as expected: `swift test --filter ProgressiveTranscriptLocatorTests/testRejectsLaterCompleteShortAyahBeforeInitialLock` accepted ayah 88:8 at expected range 28..<31.
- [x] Focused marker check after sharpening the regression: `swift test --filter MushafPageRendererTests/testVisibilityProviderKeepsAyahMarkerAfterRevealedAyah` passed 1 test with 0 failures.
- [x] Focused green check after clipped full-line rendering: `swift test --filter 'ProgressiveTranscriptLocatorTests|MushafPageRendererTests/testVisibilityProviderKeepsAyahMarkerAfterRevealedAyah|MushafPageRendererTests/testVisibilityProviderSuppressesHiddenWordsWithoutChangingPageSize'` passed 14 tests with 0 failures.
- [x] App bundle verification: `./script/build_and_run.sh --verify` rebuilt, signed, relaunched, and verified `dist/HifzTracker.app`.
- [x] Final locator-fix `swift test` passed 123 tests with 1 expected local-audio skip and 0 failures.
- [x] Final locator-fix `swift build` completed successfully.

## Notes for Next Session

Start in `/Users/mostafa/Downloads/Coding_Projects/hifz-tracker` on `main`. The guarded short-ayah initial-lock and hide-renderer fixes are verified, the app bundle has been rebuilt/relaunched, and the changes are currently uncommitted.
