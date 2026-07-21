# Session Handoff

## Current Objective

- Goal: No active feature; `confirmed-word-cursor-001` is complete.
- Current status: The view model now focuses and page-follows the final ASR-confirmed word. Later words remain pending; both authoritative and provisional paths no longer show an unrecited successor as current.
- Working tree: cursor implementation/tests plus harness evidence, and unrelated untracked `.claude/` and performance-audit content.

## Verification Evidence

| Check | Result |
|---|---|
| Red regression | Reproduced `60:1:12 -> 60:1:36`, expected range `34..<36` |
| Focused locator suites | 23 progressive + 3 outcome tests passed |
| Focused replay | Passed in 24.546 s; 377 windows |
| False `60:1:36` outcomes | 0 |
| Progress after word 12 | `60:1:15` at 13.309 s, 1.536 s later |
| Recognition coverage | Expected-word LCS 139/140 |
| Final locator position | `60:5:13` |
| Full test suite | 144 tests, 1 expected skip, 0 failures |
| Swift build | Passed |
| Source audio | Original SHA-256 unchanged |
| Generated audit | Restored to prior SHA-256 `39065d03ba913449291c8b9bd29e306e964f58c74b9277db04903cb7648dd896` |
| Source commit | `1d87647`, pushed to `origin/main` |
| Release gate | Passed 144 tests with 1 expected skip; build, launch, assets, rpaths, and signature checks passed |
| Updated DMG | 520,849,620 bytes; SHA-256 `5d0de05df139b0c52438f7913ed19df017a7c81da1e36aec771ba2d2c2867ad0` |
| Image verification | `hdiutil verify` passed, CRC32 `$87E875E6` |
| Mounted app | Deep strict signature valid; executable SHA-256 matched staged build |
| Mounted launch | Launched from read-only image as PID 73847, then stopped and detached |

## Restart Notes

1. The user chose a confirmed-word cursor. `applyLocatedProgress`, `syncSelectedAyahWordProgress`, and provisional rendering leave successor words pending, while focused/page-follow references the completed word.
2. Verification on 2026-07-21: red test showed three old successor `.current` assertions; focused `RecitationViewModelTests` (25) and `RecitationEngineCoreTests` (4), full `swift test`, `swift build`, JSON validation, and diff check passed with temporary compiler caches. `./script/release_checks.sh` passed, and the rebuilt ignored DMG is 521,226,275 bytes, SHA-256 `56bcf7a167dd2cff8b08b14cfb2a541fea309602a26ce5c607ce3db51d898e9e`; `hdiutil verify` passed.
3. The normal sandbox baseline fails before test execution only because its default Clang module cache is not writable; use the documented `/private/tmp/hifz-*-module-cache` environment for verification.
4. The private guard rejects only a candidate that skips unconfirmed words and whose full normalized phrase occurs more than once in the current search range.
5. Adjacent repeated phrases and unique discontinuous catch-up candidates remain eligible.
6. The temporary `060001.wav` and conversion directory are gone; the original M4A was unchanged.
7. The tracked audit JSON contains its prior public fixture, not the supplied Surah 60 transcript.
8. The ignored `dist/HifzTracker-0.1.0-arm64.dmg` now contains the pushed locator fix.
9. The app is ad-hoc signed and the DMG is unsigned and not notarized because no Developer ID identity is installed.
10. `gh auth status` reports the active GitHub CLI token is invalid; authenticate before pushing the local confirmed-word cursor commit.

## Risks / Out of Scope

- The fix does not impose a global distance threshold or change the two-word minimum.
- ASR, audio, cadence, rendering, model assets, and release-signing configuration are unchanged.
- Public distribution remains out of scope until Developer ID signing and notarization credentials are available.
