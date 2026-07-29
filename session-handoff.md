# Session Handoff

## Current Objective

- Goal: None; `mushaf-layout-reliability-001` is complete.
- Current status: Every ayah line across all 604 pages fits; the updated local DMG is fully verified; commit/push is waiting on GitHub CLI re-authentication.
- Working tree: uncommitted source, test, and harness changes plus unrelated untracked `.claude/` and performance-audit content.

## Verification Evidence

| Check | Result |
|---|---|
| Local release gate | 149 tests, 1 expected skip; staging, launch, assets, rpaths, and ad-hoc signature checks passed |
| Updated DMG | 520,841,049 bytes; SHA-256 `c4672801c5d2753e5de1e3c0a47c0a8cbf6730155205c8287d9704fd40c5b874` |
| Image verification | `hdiutil verify` passed, CRC32 `$664C34F0` |
| Executable verification | Mounted and staged SHA-256 `9d6f41e495636ffbfeacb1cd7e0b741e7c536b4871d379d2f9202527ddd86355` |
| Mounted launch | Launched from the read-only image as PID 13975, then stopped and detached |
| GitHub publish | Blocked: `gh auth status` reports an invalid token |
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

1. QPC fonts have inconsistent regular-space advances, so drawing positions words with a stable 0.04-em gap instead.
2. Lines wider than the 920-point ayah area are scaled just enough to fit.
3. Highlights and Hide Ayah use the same fitted font and word positions.
4. The permanent all-page regression opens every page font and checks every ayah line, adding about 18 seconds to `swift test`.
5. `MushafFontResolver` handles the six bundled fonts whose immutable PostScript names omit `-Regular`: pages 13, 27, 28, 29, 226, and 227.
6. `MushafLineLayout.ayahToAyahStep` is 100 canonical points, up from 88.
7. Page 13 remains covered through the same throwing `MushafPageRenderer.drawPage` seam used by the app canvas.
8. The normal sandbox baseline needs the documented `/private/tmp/hifz-*-module-cache` environment for verification.
9. The ignored `dist/` app and DMG were rebuilt and verified; the DMG SHA-256 is `c4672801c5d2753e5de1e3c0a47c0a8cbf6730155205c8287d9704fd40c5b874`.
10. Run `gh auth login -h github.com` before resuming the requested commit and direct push to `main`.

## Risks / Out of Scope

- The spacing change makes normal pages taller and relies on the existing vertical scroll behavior.
- Exceptionally wide lines are reduced only enough to preserve the border; normal lines keep their base font size.
- No font files, layout databases, ASR behavior, audio, model assets, or signing configuration changed.
- The refreshed DMG is for local distribution only; Developer ID signing and notarization still require credentials.
