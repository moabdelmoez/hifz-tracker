# Guarded Provisional Initial Highlight Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a safe provisional first highlight from repeated 2-word near-start evidence without committing recitation progress until the existing 3-word/4-word locator confirms.

**Architecture:** Add a tiny HifzCore tracker that observes rejected initial transcripts and confirms the same 2-word near-start candidate only after consecutive windows. RecitationViewModel uses that tracker only while committed progress is zero, applies a provisional visual state, and clears it as soon as evidence disagrees or real progress applies.

**Tech Stack:** SwiftPM, Swift, HifzCore locator types, macOS SwiftUI/AppKit Mushaf highlighting, XCTest, OSLog.

---

## File Structure

- Modify `Sources/HifzCore/Models.swift`
  - Add `WordProgressState.provisional` so provisional UI is distinct from completed/current/uncertain.
- Modify `Sources/HifzCore/TranscriptPositionLocator.swift`
  - Add `ProvisionalInitialHighlightTracker`, `ProvisionalInitialHighlightOutcome`, and a small candidate identity type near the existing progressive locator.
- Create `Tests/HifzCoreTests/ProvisionalInitialHighlightTrackerTests.swift`
  - Cover consecutive confirmation, conflict clearing, start-window guard, and no committed locator mutation.
- Modify `HifzTracker/Services/RecitationViewModel.swift`
  - Own and reset the provisional tracker.
  - Evaluate provisional evidence only when `snapshot.completedWordCount == 0` and real locating did not apply.
  - Apply/clear `.provisional` visual state without calling the reducer.
  - Log provisional candidate/confirmed/cleared events.
- Modify `HifzTracker/Views/MushafPageView.swift`
  - Render `.provisional` with a subtle distinct highlight and accessibility label.
- Modify `Sources/HifzCore/MushafPageRenderer.swift`
  - Render `.provisional` in exported/rendered page images.
- Modify or add focused tests in `Tests/HifzTrackerTests`
  - Prefer a small view-model/unit test if current test seams allow it; otherwise add focused state-rendering tests around the pure helpers exposed by the implementation.
- Update `feature_list.json`, `progress.md`, and `session-handoff.md`
  - Record implementation evidence and real-log verification criteria.

---

### Task 1: Add the Provisional Visual State

**Files:**
- Modify: `Sources/HifzCore/Models.swift`
- Modify: `HifzTracker/Views/MushafPageView.swift`
- Modify: `Sources/HifzCore/MushafPageRenderer.swift`

- [ ] **Step 1: Add failing compile target mentally before edit**

Expected failing condition after adding `.provisional` only in `Models.swift`: exhaustive switches in Mushaf rendering should require updates. This is desirable because every visual renderer must decide how provisional looks.

- [ ] **Step 2: Add the enum case**

In `WordProgressState`, add:

```swift
case provisional
```

- [ ] **Step 3: Update SwiftUI Mushaf colors**

In `HifzTracker/Views/MushafPageView.swift`, handle `.provisional` in the existing state switch helpers:

```swift
case .provisional: Color.orange.opacity(0.14)
```

```swift
case .provisional: .orange
```

```swift
case .provisional: "Provisional"
```

- [ ] **Step 4: Update rendered Mushaf images**

In `Sources/HifzCore/MushafPageRenderer.swift`, handle `.provisional` in `drawHighlight(for:in:)`:

```swift
case .provisional:
    color = NSColor.systemOrange.withAlphaComponent(0.14)
```

- [ ] **Step 5: Run focused compile**

Run:

```bash
env CLANG_MODULE_CACHE_PATH=/private/tmp/hifz-clang-module-cache SWIFT_MODULE_CACHE_PATH=/private/tmp/hifz-swift-module-cache swift build
```

Expected: build passes, or any remaining exhaustive switch errors point to additional UI state switches that must explicitly handle `.provisional`.

---

### Task 2: Add Core Provisional Initial Tracker Tests

**Files:**
- Create: `Tests/HifzCoreTests/ProvisionalInitialHighlightTrackerTests.swift`

- [ ] **Step 1: Write failing tests**

Create tests for these exact behaviors:

```swift
func testConfirmsSameTwoWordNearStartCandidateOnSecondConsecutiveWindow()
func testRestartsWhenCandidateChangesBeforeConfirmation()
func testRejectsTwoWordCandidateAtOrBeyondInitialStartLimit()
func testRejectsThreeWordCandidateBecauseRealLocatorOwnsThatPath()
func testResetClearsPendingCandidate()
```

Use a reference helper matching `ProgressiveTranscriptLocatorTests.references`.

The expected policy:

```swift
var tracker = ProvisionalInitialHighlightTracker(requiredConsecutiveMatches: 2, initialStartLimit: 16)
let first = tracker.evaluate(index: index, recognizedWords: ["يا", "ايها"])
guard case .candidate(let firstLocation, let firstCount) = first else {
    return XCTFail("Expected first repeated 2-word evidence to be a candidate")
}
XCTAssertEqual(firstLocation.completedThrough.location, "73:1:2")
XCTAssertEqual(firstCount, 1)

let second = tracker.evaluate(index: index, recognizedWords: ["يا", "ايها"])
guard case .confirmed(let secondLocation, let secondCount) = second else {
    return XCTFail("Expected second consecutive 2-word evidence to confirm provisional highlight")
}
XCTAssertEqual(secondLocation.completedThrough.location, "73:1:2")
XCTAssertEqual(secondCount, 2)
```

- [ ] **Step 2: Run the failing test**

Run:

```bash
env CLANG_MODULE_CACHE_PATH=/private/tmp/hifz-clang-module-cache SWIFT_MODULE_CACHE_PATH=/private/tmp/hifz-swift-module-cache swift test --filter ProvisionalInitialHighlightTrackerTests
```

Expected: fail because `ProvisionalInitialHighlightTracker` does not exist.

---

### Task 3: Implement Core Provisional Initial Tracker

**Files:**
- Modify: `Sources/HifzCore/TranscriptPositionLocator.swift`

- [ ] **Step 1: Add public outcome type**

Add a small public outcome:

```swift
public enum ProvisionalInitialHighlightOutcome: Equatable, Sendable {
    case none
    case candidate(location: TranscriptLocation, consecutiveCount: Int)
    case confirmed(location: TranscriptLocation, consecutiveCount: Int)
    case cleared
}
```

- [ ] **Step 2: Add the tracker**

Add:

```swift
public struct ProvisionalInitialHighlightTracker: Sendable {
    private struct CandidateKey: Equatable, Sendable {
        var expectedRange: Range<Int>
        var completedLocation: String
    }

    public var requiredConsecutiveMatches: Int
    public var initialStartLimit: Int
    public var locator: TranscriptPositionLocator

    private var pendingCandidate: CandidateKey?
    private var consecutiveCount: Int

    public init(
        requiredConsecutiveMatches: Int = 2,
        initialStartLimit: Int = 16,
        locator: TranscriptPositionLocator = TranscriptPositionLocator(minimumRunLength: 2)
    ) {
        self.requiredConsecutiveMatches = max(2, requiredConsecutiveMatches)
        self.initialStartLimit = max(1, initialStartLimit)
        self.locator = locator
        self.pendingCandidate = nil
        self.consecutiveCount = 0
    }

    public mutating func reset() {
        pendingCandidate = nil
        consecutiveCount = 0
    }
}
```

- [ ] **Step 3: Implement evaluation policy**

Implement `evaluate(index:recognizedWords:)` so it:

- returns `.none` for empty expected or recognized words
- searches only `0..<min(initialStartLimit, index.count)`
- requires `matchedWordCount == 2`
- rejects any 3+ word match because the real locator owns 3-word/4-word lock
- requires the 2-word phrase to occur once across the selected reference scope, while the candidate start remains within the guarded start window
- returns `.candidate` on first sighting
- returns `.confirmed` when the same candidate appears in consecutive windows
- returns `.cleared` when a different candidate or no candidate replaces a pending one

- [ ] **Step 4: Run tracker tests**

Run:

```bash
env CLANG_MODULE_CACHE_PATH=/private/tmp/hifz-clang-module-cache SWIFT_MODULE_CACHE_PATH=/private/tmp/hifz-swift-module-cache swift test --filter ProvisionalInitialHighlightTrackerTests
```

Expected: all provisional tracker tests pass.

---

### Task 4: Wire Provisional Highlight Into RecitationViewModel

**Files:**
- Modify: `HifzTracker/Services/RecitationViewModel.swift`

- [ ] **Step 1: Add tracker state**

Add:

```swift
private var provisionalInitialHighlightTracker = ProvisionalInitialHighlightTracker()
private var provisionalHighlightLocation: TranscriptLocation?
```

- [ ] **Step 2: Reset tracker state**

Reset both fields in:

- `startRecording()`
- `stopRecording()`
- `invalidateReferenceScope()`
- immediately after any real `.located` progress applies

- [ ] **Step 3: Evaluate provisional only after real locator rejects**

In `applyASRTranscript`, after logging a non-located real outcome and before returning `false`, call a helper only when:

```swift
snapshot.completedWordCount == 0
```

The helper should evaluate `provisionalInitialHighlightTracker` and:

- apply visual provisional state on `.confirmed`
- keep no visual change on `.candidate`
- clear existing provisional state on `.cleared` or `.none`
- never call `reducer.reduce(.progressAdvanced(...))`
- never call `applyLocatedProgress`

- [ ] **Step 4: Add visual apply/clear helpers**

Add helpers with these responsibilities:

```swift
private func applyProvisionalInitialHighlight(through location: TranscriptLocation, references: [RecitationWordReference])
private func clearProvisionalInitialHighlight()
```

`applyProvisionalInitialHighlight` should mark only words inside `location.expectedRange` as `.provisional`, preserve the first pending/current word after the range as `.current`, and avoid changing `snapshot.completedWordCount`.

- [ ] **Step 5: Add OSLog events**

Log:

```text
live_asr_locator event=provisional_initial_highlight state=candidate|confirmed|cleared window_id=... matched_word_count=2 confirmation_count=... completed_surah=... completed_ayah=... completed_word=...
```

Do not log transcript text or audio.

---

### Task 5: Add View-Model Level Safety Tests

**Files:**
- Modify or create: `Tests/HifzTrackerTests/RecitationViewModelTests.swift`

- [ ] **Step 1: Add focused tests where seams allow**

Add tests for:

```swift
func testProvisionalInitialHighlightDoesNotAdvanceSnapshotProgress()
func testRealLocatedProgressClearsProvisionalHighlight()
func testProvisionalHighlightClearsWhenEvidenceDisagrees()
```

Expected assertions:

```swift
XCTAssertEqual(viewModel.snapshot.completedWordCount, 0)
XCTAssertEqual(viewModel.progressState(for: provisionalWord), .provisional)
XCTAssertEqual(viewModel.progressState(for: nextWord), .current)
```

- [ ] **Step 2: If private seams block direct testing, extract a tiny pure helper**

Only if needed, extract the visual state update into a small internal helper in `HifzTracker/Services`, then test that helper directly. Do not expose app internals publicly just for tests.

---

### Task 6: Verification and Documentation

**Files:**
- Modify: `feature_list.json`
- Modify: `progress.md`
- Modify: `session-handoff.md`

- [ ] **Step 1: Run focused checks**

Run:

```bash
env CLANG_MODULE_CACHE_PATH=/private/tmp/hifz-clang-module-cache SWIFT_MODULE_CACHE_PATH=/private/tmp/hifz-swift-module-cache swift test --filter ProvisionalInitialHighlightTrackerTests
env CLANG_MODULE_CACHE_PATH=/private/tmp/hifz-clang-module-cache SWIFT_MODULE_CACHE_PATH=/private/tmp/hifz-swift-module-cache swift test --filter ProgressiveTranscriptLocatorTests
env CLANG_MODULE_CACHE_PATH=/private/tmp/hifz-clang-module-cache SWIFT_MODULE_CACHE_PATH=/private/tmp/hifz-swift-module-cache swift test --filter RecitationViewModelTests
```

Expected: all focused tests pass.

- [ ] **Step 2: Run standard checks**

Run:

```bash
env CLANG_MODULE_CACHE_PATH=/private/tmp/hifz-clang-module-cache SWIFT_MODULE_CACHE_PATH=/private/tmp/hifz-swift-module-cache swift test
env CLANG_MODULE_CACHE_PATH=/private/tmp/hifz-clang-module-cache SWIFT_MODULE_CACHE_PATH=/private/tmp/hifz-swift-module-cache swift build
```

Expected: full test suite and build pass.

- [ ] **Step 3: Real-world log verification**

Run one on-device recitation from the selected `startAyah` and inspect:

```bash
log show --info --last 10m --style compact --predicate 'subsystem == "dev.mostafa.HifzTracker" && category == "ASR" && eventMessage CONTAINS "provisional_initial_highlight"'
```

Success criteria:

- provisional candidate appears before the first committed `progress_applied` when ASR repeats the same 2-word near-start phrase
- `snapshot.completedWordCount` remains 0 until a real 3-word/4-word lock
- provisional highlight clears or is replaced when evidence disagrees
- first visible highlight improves versus the 16:38 run when windows 12-14 contain repeated 2-word evidence
- ASR timing remains healthy: first transcript near 1s, interval near 0.5s, no pending-window backlog

- [ ] **Step 4: Update tracking docs**

Record command output and log evidence in `progress.md`, add or update the feature entry in `feature_list.json`, and refresh `session-handoff.md` with the next decision point.

---

## Self-Review

- Spec coverage: The plan covers the agreed first optimization only: guarded provisional 2-word initial highlighting. Tail-weighted post-lock matching remains a later feature.
- Safety: The plan explicitly avoids reducer progress changes until the existing real locator returns `.located`.
- Scope: The only rendering change is a new visual state required to show provisional highlighting distinctly.
- Ambiguity resolved: The v1 guard is exactly 2 words, same candidate across 2 consecutive windows, starting within the first 16 expected words, and unique across the selected reference scope.
