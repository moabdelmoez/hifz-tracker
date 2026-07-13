# Ponytail Audit

Generated: 2026-07-13

Scope: over-engineering and complexity only. This report does not apply any fixes.

delete: Stage only `libonnxruntime.1.dylib`; the executable references no other alias, so two copies add ~72 MB. One correctly named dylib. [script/build_and_run.sh](../script/build_and_run.sh#L39).

delete: Completed 371-line implementation plan duplicates permanent feature evidence. Nothing. [provisional highlight plan](superpowers/plans/2026-06-17-guarded-provisional-initial-highlight.md#L1).

delete: `logo.png` is byte-identical to the Pages icon. Point README at the existing asset, saving 1.5 MB. [logo.png](../logo.png).

native: Replace custom WAV parsing, channel mixing, and linear resampling with Apple's [AVAudioConverter](https://developer.apple.com/documentation/avfaudio/avaudioconverter). [WAVAudioFileInfo.swift](../Sources/HifzCore/WAVAudioFileInfo.swift#L3), [MicrophoneCaptureService.swift](../HifzTracker/Services/MicrophoneCaptureService.swift#L89).

delete: `QuranSTTAssetBundle` and its YAML parser are production APIs used only by tests. Direct URLs and existing release checks. [QuranSTTAssetBundle.swift](../Sources/HifzCore/QuranSTTAssetBundle.swift#L3).

delete: ONNX metadata reflection exists only to test fixed names already exercised by inference. Remove the Swift properties and C metadata bridge. [ONNXRuntime.swift](../Sources/HifzCore/ONNXRuntime.swift#L11), [COnnxRuntimeShim.c](../Sources/COnnxRuntimeShim/COnnxRuntimeShim.c#L34).

shrink: `LiveASRLocatorOutcomeProbe` repeatedly initializes the same 12-field DTO and mirrors it in tests. Defaulted metrics plus table-driven cases. [LiveASRLocatorOutcomeProbe.swift](../HifzTracker/Services/LiveASRLocatorOutcomeProbe.swift#L3).

native: Replace the hand-written FFT, bit reversal, twiddle tables, and Hann-window loops with [Accelerate/vDSP](https://developer.apple.com/documentation/accelerate/vdsp/fast_fourier_transforms). [LogMelFeatureExtractor.swift](../Sources/HifzCore/LogMelFeatureExtractor.swift#L80).

delete: Manual Advance/Correction controls and their mutation helpers are leftover prototype paths beside real ASR. Nothing. [RecitationSidebarView.swift](../HifzTracker/Views/RecitationSidebarView.swift#L246), [RecitationViewModel.swift](../HifzTracker/Services/RecitationViewModel.swift#L134).

delete: `WordAligner` has no application caller; only its own test uses it. Nothing. [RecitationCore.swift](../Sources/HifzCore/RecitationCore.swift#L25).

native: Replace app-wide manual font registration with macOS [`ATSApplicationFontsPath`](https://developer.apple.com/documentation/bundleresources/information-property-list/atsapplicationfontspath). Delete the registrar and add `Fonts/` to the generated Info.plist. [MushafFontRegistrar.swift](../HifzTracker/Services/MushafFontRegistrar.swift#L7).

delete: `RecitationEngine` is an unused actor facade around the reducer, referenced only by its facade test. Use `RecitationStateReducer` directly. [RecitationEngine.swift](../Sources/HifzCore/RecitationEngine.swift#L1).

delete: `SessionHistoryExporter` is an unshipped feature referenced only by its test. Use `JSONEncoder` when export becomes real. [SessionHistoryExporter.swift](../Sources/HifzCore/SessionHistoryExporter.swift#L3).

shrink: `matchingRunLength` and `occurrenceCount` are duplicated within one locator file. One file-private implementation each. [TranscriptPositionLocator.swift](../Sources/HifzCore/TranscriptPositionLocator.swift#L143).

shrink: Pending-store and pending-handoff timing metrics duplicate structures and calculations. One metric type with an event kind. [LiveASRTimingProbe.swift](../HifzTracker/Services/LiveASRTimingProbe.swift#L9).

shrink: DMG packaging repeats release asset validation. Call `release_checks.sh release` and delete local copies. [package_dmg.sh](../script/package_dmg.sh#L14).

yagni: `MushafFontResolver` exposes five configurable fields for one permanent configuration. Static QPC name and filename functions. [MushafFontResolver.swift](../Sources/HifzCore/MushafFontResolver.swift#L3).

delete: `applyUncertain`, `startDiscardingAudio`, the one-option microphone preference, and the empty core marker file have no callers or effect. Nothing. [RecitationViewModel.swift](../HifzTracker/Services/RecitationViewModel.swift#L716), [SettingsView.swift](../HifzTracker/Views/SettingsView.swift#L4).

shrink: Toolbar status color independently reimplements `RecitationVisualState.tint`. Reuse the existing state mapping. [RecitationRootView.swift](../HifzTracker/Views/RecitationRootView.swift#L79).

delete: `centeredScrollOffset` is production code used only by its test; the UI scrolls through `ScrollViewReader`. Nothing. [MushafPageView.swift](../HifzTracker/Views/MushafPageView.swift#L264).

yagni: Untracked `.claude/skills` is a 39-symlink mirror of `.agents/skills`. Keep it untracked unless Claude Code support is intentional. [.claude/skills](../.claude/skills).

net: -1,400 lines, -0 deps possible.
