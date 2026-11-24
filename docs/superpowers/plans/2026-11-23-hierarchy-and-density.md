# Hierarchy and Density Implementation Plan

> Execute each fix in order. Reproduce the behavior with a failing check, implement the smallest change, then rerun the check and the Swift suite before advancing. Record results in `progress.md` and activate one feature at a time in `feature_list.json`.

The five numbered findings from the project review define the scope. Keep the app offline on macOS 14 and preserve saved sessions. The existing app, SwiftPM tests, and static site provide the verification entry points.

## 1. Reader position

- [x] Extend the existing 100-to-101 transcript regression to assert the live reader position is surah 101, ayah 1 after recognition crosses the boundary. Confirm the assertion fails against the starting-surah title. Check that picking a new start clears the previous live position.
- [x] Derive a position in `RecitationViewModel` from the confirmed reference or selected setup. Use its surah and ayah in `RecitationRootView`, `RecitationSidebarView`, and `MushafPageView`. Keep the visible page independently labeled so automatic page turns and manual browsing can occur before the next verse is confirmed.
- [x] Run the view-model tests, `swift test`, and `swift build`.

## 2. Progress hierarchy

- [x] Add a calculator regression where a confirmed session on a late-numbered surah appears ahead of an untouched surah and a zero-word session contributes no practiced row or last confirmed position.
- [x] Show practiced surahs and their latest confirmed positions first. Put the activity calendar and all 114 surahs behind disclosures, and move Reset Progress to an actions menu without removing its confirmation. Label existing percentages as furthest position where shown.
- [x] Verify that saved practice and the activity calendar remain available when the Quran repository cannot load.
- [x] Run the calculator and reset tests, `swift test`, and `swift build`.

## 3. Recording feedback and Settings

- [x] Add a check for a fresh profile whose recognition transcript is off and for a profile where an explicit opt-in remains on.
- [x] Delete the timer-driven circles, use the existing toolbar status, and flatten Settings into a single form with the transcript toggle and the three privacy facts.
- [x] Run the preference tests, `swift test`, and `swift build`.

## 4. Download page

- [x] Check the local HTML for the download, compatibility requirements, and reader preview appearing together before installation details. Verify the download and checksum links remain intact and below-fold screenshots are deferred.
- [x] Use the existing reader screenshot beside Download. Keep the signing notice visible and collapse the detailed instructions. Remove the duplicate release action and release-notes filler.
- [x] Rerun the local HTML checks, `swift test`, and `swift build`. Check desktop and narrow layouts if a browser surface is available.

## 5. Project handoff

- [x] Check that startup yields a single active feature at most, and that the current handoff lists outstanding manual acceptance checks once.
- [x] Consolidate current instructions and evidence across `AGENTS.md`, `feature_list.json`, `progress.md`, and `session-handoff.md`. Preserve unique historical evidence and remove superseded objectives and duplicated verification tables from the startup path.
- [x] Validate the tracker, walk through startup using the written instructions, and run `swift test` and `swift build`.
