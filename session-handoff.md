# Session Handoff

## Current Objective

- Goal: Add on-device timing instrumentation for the live ASR/highlighting path.
- Current status: Complete and verified; timing logs are emitted without changing ASR model, locator, repository, or Mushaf rendering behavior.
- Branch / commit: `main`, no commit made in this session.

## Completed This Session

- [x] Added `live-asr-timing-001` to `feature_list.json`.
- [x] Added `LiveASRTimingProbe` with deterministic timestamp inputs and reset behavior.
- [x] Wired recording lifecycle timing reset/start markers into `RecitationViewModel`.
- [x] Logged ASR window starts and finishes, including processing duration.
- [x] Logged one-time first transcript latency per recording.
- [x] Logged transcript interval and running average interval after multiple transcript completions.
- [x] Logged pending-window storage while transcription is busy.
- [x] Logged pending-window handoff starts when the scheduler immediately starts the newest pending window.
- [x] Logged highlight application after a transcript advances located progress.
- [x] Added focused unit tests for the timing probe.
- [x] Updated `progress.md` with evidence and next measurement steps.

## Verification Evidence

| Check | Command | Result | Notes |
|---|---|---|---|
| Red test | `swift test --filter LiveASRTimingProbeTests` | Failed as expected | `LiveASRTimingProbe` did not exist before production edits. |
| Focused regression | `env CLANG_MODULE_CACHE_PATH=/private/tmp/hifz-clang-module-cache SWIFT_MODULE_CACHE_PATH=/private/tmp/hifz-swift-module-cache swift test --filter LiveASRTimingProbeTests` | Passed | 3 timing-probe tests, 0 failures. |
| Standard verification | `env CLANG_MODULE_CACHE_PATH=/private/tmp/hifz-clang-module-cache SWIFT_MODULE_CACHE_PATH=/private/tmp/hifz-swift-module-cache swift test` | Passed | 80 tests passed; 1 existing local audio audit skipped by opt-in flag. |
| Standard verification | `env CLANG_MODULE_CACHE_PATH=/private/tmp/hifz-clang-module-cache SWIFT_MODULE_CACHE_PATH=/private/tmp/hifz-swift-module-cache swift build` | Passed | Debug build completed successfully. |

## Files Changed

- `HifzTracker/Services/LiveASRTimingProbe.swift`
- `HifzTracker/Services/RecitationViewModel.swift`
- `Tests/HifzTrackerTests/LiveASRTimingProbeTests.swift`
- `feature_list.json`
- `progress.md`
- `session-handoff.md`

## Decisions Made

- Keep this pass instrumentation-only: no model, locator, repository, Mushaf rendering, cadence, or scheduler behavior changes.
- Use the existing ASR OSLog subsystem/category with `live_asr_timing` in every timing event.
- Emit `-1` for timing fields that do not apply yet, such as first latency after the first transcript or interval before a second transcript.
- Separate `pending_window_stored` from `pending_window_handoff_started` so logs can show both queue pressure and actual handoff starts.
- Keep timing tests unit-level and deterministic by injecting nanosecond timestamps.

## Useful Log Filter

```bash
log show --last 10m --style compact --predicate 'subsystem == "dev.mostafa.HifzTracker" && category == "ASR" && eventMessage CONTAINS "live_asr_timing"'
```

## Blockers / Risks

- No blockers.
- On-device timing data still needs to be captured in a real recitation session before picking the next optimization.
- Release checks were skipped because this did not touch release assets, signing, packaging, or distribution flow.

## Next Session Startup

1. Read `AGENTS.md`.
2. Read `feature_list.json`, `progress.md`, and this file.
3. Run `swift test` and `swift build` before new edits when feasible.

## Recommended Next Step

- Run the app on-device, recite a short passage, collect `live_asr_timing` logs, and compare first transcript latency, average transcript interval, pending handoffs, and ASR processing time per window.
