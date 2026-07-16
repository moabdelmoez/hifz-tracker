# Session Handoff

## Current Objective

- Goal: Prevent the live locator from skipping unfinished ayahs or reusing repeated words from overlapping ASR audio as next-ayah evidence.
- Current status: Complete. `strict-fresh-ayah-order-001` is marked `done`.
- Branch: `main`.
- Working tree: scoped core/live-ASR tests and harness updates are uncommitted; pre-existing `.claude/` remains untouched.

## Implemented Behavior

- Initial and provisional matches stay inside the selected start ayah.
- Each update searches only the unfinished current ayah, or its immediate successor after the current final word was accepted.
- The live path carries CTC frame ranges through timed tokenizer words and absolute rolling-window sample ranges.
- Successor evidence must begin after the accepted final-word sample boundary, so stale repeated phrases cannot be reused.
- Post-boundary words from the same rolling window remain eligible on a later ASR update.
- Missing/inconsistent timing holds progress and logs a privacy-safe diagnostic; audio and transcripts are not persisted.

## Verification Evidence

| Check | Result |
|---|---|
| Strict locator/provisional regressions | 30 passed |
| Timed ASR and view-model regressions | Passed |
| Local audio/model audit | 1 passed in 32.703 s |
| Full tests | 140 tests, 1 expected opt-in skip, 0 failures |
| Build | `swift build` passed |
| Static checks | Valid feature JSON and clean diff check |

## Restart Notes

1. `cd /Users/mostafa/Downloads/Coding_Projects/hifz-tracker`
2. Confirm `git status --short`; preserve `.claude/` and unrelated user changes.
3. Rerun `swift test` and `swift build` before starting another feature.
4. Optionally perform a live Surah 72 recitation to confirm the microphone-session behavior manually.

## Risks / Out of Scope

- Frame timing is inferred from CTC output positions across each rolling window; the local model/audio audit validates the pipeline, but a live microphone confirmation remains optional.
- No UI, persistence, network, model asset, signing, packaging, or dependency changes were made.
- Release checks were skipped because distribution-sensitive inputs did not change.
