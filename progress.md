# Session Progress Log

## Current State

**Last Updated:** 2026-06-17 10:40 EEST
**Session ID:** live-asr-timing-2026-06-17
**Active Feature:** `live-asr-timing-001` - Live ASR Timing Instrumentation complete.

## Status

### What's Done

- [x] Added `LiveASRTimingProbe` to keep deterministic timing counters outside the ASR model, locator, repository, and Mushaf renderer.
- [x] Wired `RecitationViewModel` to reset timing state on recording start, stop, and start failure.
- [x] Logged `live_asr_timing event=recording_started` when the microphone session becomes active.
- [x] Logged `transcription_started` with `window_id`, `sample_count`, and `audio_ms` for every ASR request window.
- [x] Logged `transcription_finished` with `processing_ms`, one-time `first_transcript_latency_ms`, per-window `transcript_interval_ms`, and `average_transcript_interval_ms`.
- [x] Logged `pending_window_stored` when the scheduler collapses a busy-window submission to the newest pending window.
- [x] Logged `pending_window_handoff_started` when an active transcription completes and immediately starts the latest pending window.
- [x] Logged `highlight_applied` when a transcript actually advances located word progress.
- [x] Added `LiveASRTimingProbeTests` covering first latency, processing duration, interval averages, pending storage, handoffs, and reset behavior.

### What's In Progress

- [ ] No active implementation work.

### What's Next

1. Run the app on-device and capture `live_asr_timing` ASR logs during a real recitation.
2. Compare `first_transcript_latency_ms`, `average_transcript_interval_ms`, `processing_ms`, and `pending_window_handoff_started` counts.
3. Use those numbers to choose the next optimization: feature extraction, smaller windows, or a streaming-style ASR path.

## Blockers / Risks

- [ ] On-device timing data has not been captured yet; this session only added and verified the instrumentation.
- [ ] Full release verification was skipped because this was not a release, signing, asset, packaging, or distribution change.

## Decisions Made

- **Instrument before optimizing again:** This pass only measures the live ASR path; it does not change model behavior, locator behavior, repository code, or Mushaf rendering.
- **Use OSLog:** Timing is emitted through the existing ASR logger with the `live_asr_timing` marker so device logs can be filtered without persisting user audio.
- **Keep tests deterministic:** The timing probe accepts explicit nanosecond timestamps, so unit tests do not depend on wall-clock timing.
- **Separate pending states:** The logs distinguish windows stored while ASR is busy from pending windows that are actually handed off and started.

## Files Modified This Session

- `HifzTracker/Services/LiveASRTimingProbe.swift` - Added deterministic timing metrics for live ASR recordings, windows, intervals, and pending handoffs.
- `HifzTracker/Services/RecitationViewModel.swift` - Wired the timing probe into recording lifecycle, live ASR scheduling, transcription completion, and highlight application.
- `Tests/HifzTrackerTests/LiveASRTimingProbeTests.swift` - Added focused timing-probe coverage.
- `feature_list.json` - Added the completed `live-asr-timing-001` feature entry.
- `progress.md` - Recorded current state and verification evidence.
- `session-handoff.md` - Updated restart notes for this completed work.

## Evidence of Completion

- [x] Red check: `swift test --filter LiveASRTimingProbeTests` initially failed because `LiveASRTimingProbe` did not exist.
- [x] Focused green check: `env CLANG_MODULE_CACHE_PATH=/private/tmp/hifz-clang-module-cache SWIFT_MODULE_CACHE_PATH=/private/tmp/hifz-swift-module-cache swift test --filter LiveASRTimingProbeTests` passed 3 tests with 0 failures.
- [x] Final full verification: `env CLANG_MODULE_CACHE_PATH=/private/tmp/hifz-clang-module-cache SWIFT_MODULE_CACHE_PATH=/private/tmp/hifz-swift-module-cache swift test` passed 80 tests with 1 existing opt-in local audio audit skipped and 0 failures.
- [x] Final build verification: `env CLANG_MODULE_CACHE_PATH=/private/tmp/hifz-clang-module-cache SWIFT_MODULE_CACHE_PATH=/private/tmp/hifz-swift-module-cache swift build` completed successfully.

## Useful Log Filter

```bash
log show --last 10m --style compact --predicate 'subsystem == "dev.mostafa.HifzTracker" && category == "ASR" && eventMessage CONTAINS "live_asr_timing"'
```

## Notes for Next Session

Start with `AGENTS.md`, `feature_list.json`, this file, and `session-handoff.md`. The repo is ready for the standard `swift test` and `swift build` checks.
