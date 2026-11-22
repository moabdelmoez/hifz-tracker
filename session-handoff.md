# Session Handoff

## Al-Qasas locator fix test build, November 22, 2026

Open `dist/surah-28-fix/HifzTracker.app` and recite Al-Qasas from ayah 1 to verify the live microphone path. The build passed signature verification, the full suite passed, and three public INT8 replays progressed through ayah 2. One replay exposed inconsistent model recognition of the opening. If a live run stalls again, compare locator outcomes around the opening. [Verification evidence](progress.md)

## INT8 manual test build, November 22, 2026

`dist/HifzTracker.app` is the local INT8 build. The tester gate and model warm-up passed, and the bundle is 42.20% smaller than the published FP32 app. The remaining acceptance check is to start a live recitation, confirm microphone input, and watch the word highlights on a familiar surah. [Verification evidence](progress.md)

## ASR assessment, November 22, 2026

The paired public benchmark and local locator check favor FastConformer for tracking. TajweedFormer caught more planted mistakes and produced more false alarms. A local streaming comparison would require authorized v4 access and representative audio. [Results and methodology](docs/tajweedformer-v4-assessment.md)

The future streaming comparison is listed as `tajweedformer-v4-live-evaluation-001` in the [feature backlog](feature_list.json).

## Current Objective

- Goal: Publish the Dark Mode Mushaf divider fix and synchronized replacement tester DMG/checksum under the existing `v0.1.0-alpha` URLs.
- Current status: Root cause, regression, fix, full tester gate, source push, replacement DMG/checksum publication, release notes, and README checksum are complete. Only clean-Mac verification of the replacement divider and microphone remains.
- Working tree: The scoped distribution hardening files are modified; unrelated `.claude/`, performance-audit content, root screenshots, and source GIF remain untouched.

## Verification Evidence

| Check | Result |
|---|---|
| Explicit script modes | Syntax passed; invalid/missing modes fail before mutation |
| Tester release gate | 152 tests, 1 expected skip; builds, staging, launch, assets, ad-hoc signing, and entitlements passed |
| Tester package gate | Full gate passed; generated unsigned DMG verified and checksumed |
| Previous public DMG | 520,587,236 bytes; SHA-256 `027693170c9b24888555a403eaf00e6c5913ad1a11abf8046c07dca22696b768`; CRC32 `$F4901868` |
| Dark Mode page 570 regression | Failed twice with header/bismillah pixels `0/0`; passed after fixed black white-canvas token color |
| Replacement tester gate | 153 tests, 1 expected skip; builds, staging/launch, assets, signing, entitlements, image verification passed |
| Replacement local DMG | 519,949,553 bytes; SHA-256 `1c6a12a9bfe02478c795a46862b913b5eeb23199b5b4a832ad1e5b7059618642`; CRC32 `$7F1B0C44` |
| Staged app trust state | Deep signature valid; ad-hoc; no Team ID; sandbox and microphone entitlements present |
| Website layout | 1440px and 390px passed; no overflow, anchor clipping, or console errors |
| GitHub release | Replacement DMG asset `501698206` and checksum asset `501663145` published under the stable URLs; release notes and hashes synchronized |
| Hardened Pages publication | Commit `8a88cbd`; deployment `30900801534` passed; live content, links, containment, and console checks passed |
| Clean-Mac acceptance | Open Anyway and launch passed on the previous artifact; replacement Dark Mode divider and microphone checks remain |
| Direct download route | Tag-specific URL resolves to HTTP 200 with attachment filename `HifzTracker-0.1.0-arm64.dmg` |
| DMG release metadata | 519,949,553 bytes; SHA-256 `1c6a12a9bfe02478c795a46862b913b5eeb23199b5b4a832ad1e5b7059618642` |
| Direct-download test suite | Baseline and final runs passed 152 tests with 1 expected opt-in audio skip |
| Direct-download Swift build | Baseline and final runs passed |
| Direct-download browser check | Unavailable because no connected browser backend was exposed |
| Website source | Commit `fb178aa` pushed to `origin/main` |
| GitHub Pages deployment | Workflow `30511294998` completed successfully |
| Live content | All three feature headings and screenshot references are present |
| Live presentation CSS | Sage feature surface, alternating desktop rows, mobile reset, and white sticker filters are present |
| Screenshot integrity | Supplied, copied, and live SHA-256 values match for all three images |
| Website test suite | 152 tests passed, 1 expected opt-in audio skip |
| Website Swift build | Passed |
| Browser preview | Blocked because no connected browser backend was available; no visual-render claim made |
| DMG source | Pushed main commit `af5081f` |
| DMG release gate | 152 tests passed, 1 expected skip; build, launch, assets, rpaths, and ad-hoc signature passed |
| Staged/mounted executable | Matching SHA-256 `66f29e3b2b6be5bf703d6137a0d0cf5648c882b4ebe8e3a64047603337cd8e16` |
| Mounted app | Deep strict signature passed; bundle ID and version verified |
| Mounted launch | PID 21834 from read-only image; stopped and detached |
| Updated DMG | 520,587,236 bytes; SHA-256 `027693170c9b24888555a403eaf00e6c5913ad1a11abf8046c07dca22696b768` |
| DMG image verification | Passed; CRC32 `$F4901868` |
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

1. Ask a tester to verify the replacement DMG's Dark Mode divider and microphone.
2. Mark `free-tester-distribution-001` done after that evidence is recorded.

## Risks / Out of Scope

- No Developer ID identity or notarization profile is installed; the app remains ad-hoc signed and the DMG remains unsigned and not notarized by design.
- The artifact is for the free/manual tester path, not Gatekeeper-trusted public distribution.
