# Session Handoff

## Current Objective

- Goal: None; `progress-activity-calendar-001` is complete.
- Current status: Dashboard is renamed to Progress and now includes the agreed 53-week recitation activity calendar above the existing surah progress list.
- Working tree: This task contains Progress UI, calculator, test, and harness evidence changes; unrelated untracked `.claude/`, performance-audit content, and the root source GIF remain untouched.

## Verification Evidence

| Check | Result |
|---|---|
| Baseline Progress test suite | 149 tests passed, 1 expected opt-in audio skip |
| Baseline Progress Swift build | Passed |
| Red focused check | Failed because the activity calculator and levels did not exist |
| Activity calculator suite | 3 tests passed |
| Focused Progress verification | 44 tests passed |
| Final Progress test suite | 152 tests passed, 1 expected opt-in audio skip |
| Final Progress Swift build | Passed |
| App bundle launch verification | Rebuilt, ad-hoc signed, launched, and process found |
| Progress JSON and diff validation | Passed |
| Al-Hadid GIF copy | Source and README asset SHA-256 match |
| Baseline GIF-refresh test suite | 149 tests passed, 1 expected opt-in audio skip |
| Baseline GIF-refresh Swift build | Passed |
| Final GIF-refresh test suite | 149 tests passed, 1 expected opt-in audio skip |
| Final GIF-refresh Swift build | Passed |
| GIF-refresh JSON and diff validation | Passed |
| Desktop website layout | 624px image contained inside 626px card; no page overflow |
| Narrow website layout | 682px image contained inside 684px card; no page overflow |
| Baseline containment test suite | 149 tests passed, 1 expected opt-in audio skip |
| Baseline containment Swift build | Passed |
| Final containment test suite | 149 tests passed, 1 expected opt-in audio skip |
| Final containment Swift build | Passed |
| JSON and diff validation | Passed |
| GIF copy | Source and README asset SHA-256 match |
| Screenshot copy | Source and website asset SHA-256 match |
| Baseline test suite | 149 tests passed, 1 expected opt-in audio skip |
| Baseline Swift build | Passed |
| Final media-refresh test suite | 149 tests passed, 1 expected opt-in audio skip |
| Final media-refresh Swift build | Passed |
| Media static validation | Asset references, JSON, and diff checks passed |
| README content | Old headings absent; both requested citation links present at the end |
| Final test suite | 149 tests passed, 1 expected opt-in audio skip |
| Final Swift build | Passed |
| JSON and diff validation | Passed |
| Hide Ayah control | Existing `Toggle` now uses `.toggleStyle(.switch)` |
| Final test suite | 149 tests passed, 1 expected opt-in audio skip |
| Final Swift build | Passed |
| Source commit | `89c3169` (`Fix Mushaf page layout`), pushed to `origin/main` |
| Local release gate | 149 tests, 1 expected skip; staging, launch, assets, rpaths, and ad-hoc signature checks passed |
| Updated DMG | 520,841,049 bytes; SHA-256 `c4672801c5d2753e5de1e3c0a47c0a8cbf6730155205c8287d9704fd40c5b874` |
| Image verification | `hdiutil verify` passed, CRC32 `$664C34F0` |
| Executable verification | Mounted and staged SHA-256 `9d6f41e495636ffbfeacb1cd7e0b741e7c536b4871d379d2f9202527ddd86355` |
| Mounted launch | Launched from the read-only image as PID 13975, then stopped and detached |
| GitHub publish | Authentication restored through Keychain; direct push to `main` passed |
| All-page red scan | 138 overflowing lines across 30 pages |
| Page 19 red regression | Line 3 measured 1,064pt in a 920pt area, reproduced twice |
| Root-cause probe | QPC space advance was 2.16pt on page 11 and 20.4pt on page 19 |
| All-page green scan | Every ayah line on pages 1...604 fit in 18.566 seconds |
| Corrected page 19 preview | No trimmed boundary words |
| Final renderer suite | 20 tests, 0 failures |
| Page 11 word-spacing red regression | `ﱁﱂ` instead of `ﱁ ﱂ`, reproduced twice |
| Focused word-spacing/visibility checks | 4 tests, 0 failures |
| Page 13 red regression | `unavailableFont("QCF4013_COLOR-Regular")`, reproduced twice through `drawPage` |
| Exhaustive font-name red regression | Mismatches on pages 13, 27, 28, 29, 226, and 227 |
| Spacing red regression | 88 points instead of 100 points |
| Direct canvas sweep | Pages 1...604 passed in 23.293 seconds |
| Focused renderer suite | 18 tests, 0 failures before temporary exhaustive-test cleanup |
| Full test suite | 149 tests, 1 expected skip, 0 failures |
| Swift build | Passed |
| Render preview | Page 11 visually matched the supplied vertical and QUL inter-word spacing |
| Release gate | Skipped; no asset, signing, packaging, dependency, or distribution input changed |

## Restart Notes

1. Open Progress from the toolbar or Recitation menu (`⇧⌘D`).
2. Existing saved sessions backfill the calendar; no migration or duplicate activity storage was added.
3. `feature_list.json` and `progress.md` record completion evidence.

## Risks / Out of Scope

- macOS denied automated keystrokes, so the secondary Progress window was not visually inspected through UI automation.
- No session-detail interaction, year navigation, new persistence, release assets, packaging, or signing inputs were added.
