import XCTest
@testable import HifzCore

final class ProvisionalInitialHighlightTrackerTests: XCTestCase {
    func testConfirmsSameTwoWordNearStartCandidateOnSecondConsecutiveWindow() throws {
        var tracker = ProvisionalInitialHighlightTracker(
            requiredConsecutiveMatches: 2,
            initialStartLimit: 8
        )
        let index = TranscriptPositionIndex(expected: references([
            (1, ["يا", "أيها", "المزمل"]),
            (2, ["قم", "الليل"])
        ]))

        let first = tracker.evaluate(index: index, recognizedWords: ["يا", "ايها"])
        guard case .candidate(let firstLocation, let firstCount) = first else {
            return XCTFail("Expected candidate, got \(first)")
        }
        XCTAssertEqual(firstLocation.completedThrough.location, "73:1:2")
        XCTAssertEqual(firstLocation.matchedWordCount, 2)
        XCTAssertEqual(firstCount, 1)

        let second = tracker.evaluate(index: index, recognizedWords: ["يا", "ايها"])
        guard case .confirmed(let secondLocation, let secondCount) = second else {
            return XCTFail("Expected confirmation, got \(second)")
        }
        XCTAssertEqual(secondLocation.completedThrough.location, "73:1:2")
        XCTAssertEqual(secondLocation.matchedWordCount, 2)
        XCTAssertEqual(secondCount, 2)
    }

    func testRestartsWhenCandidateChangesBeforeConfirmation() throws {
        var tracker = ProvisionalInitialHighlightTracker(
            requiredConsecutiveMatches: 2,
            initialStartLimit: 8
        )
        let index = TranscriptPositionIndex(expected: references([
            (1, ["يا", "أيها", "المزمل"]),
            (2, ["قم", "الليل", "إلا"])
        ]))

        let first = tracker.evaluate(index: index, recognizedWords: ["يا", "ايها"])
        guard case .candidate(_, let firstCount) = first else {
            return XCTFail("Expected first candidate, got \(first)")
        }
        XCTAssertEqual(firstCount, 1)

        let changed = tracker.evaluate(index: index, recognizedWords: ["الليل", "الا"])
        XCTAssertEqual(changed, .cleared)

        let confirmed = tracker.evaluate(index: index, recognizedWords: ["الليل", "الا"])
        guard case .confirmed(let changedLocation, let changedCount) = confirmed else {
            return XCTFail("Expected changed candidate to confirm after restart, got \(confirmed)")
        }
        XCTAssertEqual(changedLocation.completedThrough.location, "73:2:3")
        XCTAssertEqual(changedLocation.matchedWordCount, 2)
        XCTAssertEqual(changedCount, 2)
    }

    func testRejectsTwoWordCandidateAtOrBeyondInitialStartLimit() {
        var tracker = ProvisionalInitialHighlightTracker(
            requiredConsecutiveMatches: 2,
            initialStartLimit: 2
        )
        let index = TranscriptPositionIndex(expected: references([
            (1, ["حشو1", "حشو2", "يا", "أيها", "المزمل"])
        ]))

        let outcome = tracker.evaluate(index: index, recognizedWords: ["يا", "ايها"])

        XCTAssertEqual(outcome, .none)
    }

    func testAcceptsTwoWordCandidateStartingAtLastAllowedInitialStartOffset() {
        var tracker = ProvisionalInitialHighlightTracker(
            requiredConsecutiveMatches: 2,
            initialStartLimit: 2
        )
        let index = TranscriptPositionIndex(expected: references([
            (1, ["حشو1", "يا", "أيها", "المزمل"])
        ]))

        let outcome = tracker.evaluate(index: index, recognizedWords: ["يا", "ايها"])

        guard case .candidate(let location, let count) = outcome else {
            return XCTFail("Expected candidate at last allowed start offset, got \(outcome)")
        }
        XCTAssertEqual(location.completedThrough.location, "73:1:3")
        XCTAssertEqual(location.matchedWordCount, 2)
        XCTAssertEqual(count, 1)
    }

    func testRejectsThreeWordCandidateStartingAtLastAllowedInitialStartOffset() {
        var tracker = ProvisionalInitialHighlightTracker(
            requiredConsecutiveMatches: 2,
            initialStartLimit: 2
        )
        let index = TranscriptPositionIndex(expected: references([
            (1, ["حشو1", "يا", "أيها", "المزمل"])
        ]))

        let outcome = tracker.evaluate(index: index, recognizedWords: ["يا", "ايها", "المزمل"])

        XCTAssertEqual(outcome, .none)
    }

    func testRejectsThreeWordCandidateBecauseRealLocatorOwnsThatPath() {
        var tracker = ProvisionalInitialHighlightTracker(
            requiredConsecutiveMatches: 2,
            initialStartLimit: 8
        )
        let index = TranscriptPositionIndex(expected: references([
            (1, ["يا", "أيها", "المزمل", "قم", "الليل"])
        ]))

        let outcome = tracker.evaluate(index: index, recognizedWords: ["يا", "ايها", "المزمل"])

        XCTAssertEqual(outcome, .none)
    }

    func testRejectsTwoWordCandidateRepeatedOutsideInitialStartWindow() {
        var tracker = ProvisionalInitialHighlightTracker(
            requiredConsecutiveMatches: 2,
            initialStartLimit: 8
        )
        let index = TranscriptPositionIndex(expected: references([
            (1, ["يا", "أيها", "المزمل"]),
            (2, ["حشو1", "حشو2", "حشو3", "حشو4", "حشو5", "حشو6"]),
            (3, ["حشو", "يا", "أيها", "المدثر"])
        ]))

        let outcome = tracker.evaluate(index: index, recognizedWords: ["يا", "ايها"])

        XCTAssertEqual(outcome, .none)
    }

    func testResetClearsPendingCandidate() throws {
        var tracker = ProvisionalInitialHighlightTracker(
            requiredConsecutiveMatches: 2,
            initialStartLimit: 8
        )
        let index = TranscriptPositionIndex(expected: references([
            (1, ["يا", "أيها", "المزمل", "قم", "الليل"])
        ]))

        let first = tracker.evaluate(index: index, recognizedWords: ["يا", "ايها"])
        guard case .candidate(_, let firstCount) = first else {
            return XCTFail("Expected first candidate, got \(first)")
        }
        XCTAssertEqual(firstCount, 1)

        tracker.reset()

        let afterReset = tracker.evaluate(index: index, recognizedWords: ["يا", "ايها"])
        guard case .candidate(let resetLocation, let resetCount) = afterReset else {
            return XCTFail("Expected reset to clear pending evidence, got \(afterReset)")
        }
        XCTAssertEqual(resetLocation.completedThrough.location, "73:1:2")
        XCTAssertEqual(resetLocation.matchedWordCount, 2)
        XCTAssertEqual(resetCount, 1)
    }

    private func references(_ ayahs: [(Int, [String])], surah: Int = 73) -> [RecitationWordReference] {
        ayahs.flatMap { ayah, words in
            words.enumerated().map { offset, word in
                RecitationWordReference(surah: surah, ayah: ayah, wordIndex: offset + 1, text: word)
            }
        }
    }
}
