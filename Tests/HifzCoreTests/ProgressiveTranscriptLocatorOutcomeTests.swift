import XCTest
@testable import HifzCore

final class ProgressiveTranscriptLocatorOutcomeTests: XCTestCase {
    func testReportsShortInitialMatchBeforePlaceIsLocked() {
        var locator = ProgressiveTranscriptLocator(
            minimumInitialMatchLength: 4,
            lookBehindWordCount: 4,
            lookAheadWordCount: 24
        )
        let expected = references([
            (1, ["سبح", "لله", "ما", "في", "السماوات"]),
            (2, ["هو", "الله", "الذي"])
        ])

        let outcome = locator.locateWithOutcome(expected: expected, recognizedWords: ["سبح", "لله"])

        XCTAssertEqual(outcome, .initialMatchTooShort(matchedWordCount: 2, requiredWordCount: 4))
    }

    func testReportsNotAdvancingAfterAcceptedProgress() throws {
        var locator = ProgressiveTranscriptLocator(
            minimumInitialMatchLength: 4,
            lookBehindWordCount: 4,
            lookAheadWordCount: 12
        )
        let expected = references([
            (1, ["سبح", "لله", "ما", "في", "السماوات", "وما", "في", "الارض"]),
            (2, ["هو", "الذي", "اخرج", "الذين", "كفروا"])
        ])

        let first = locator.locateWithOutcome(expected: expected, recognizedWords: ["سبح", "لله", "ما", "في"])
        guard case .located(let firstLocation) = first else {
            return XCTFail("Expected initial location, got \(first)")
        }
        XCTAssertEqual(firstLocation.completedThrough.location, "59:1:4")

        let repeated = locator.locateWithOutcome(expected: expected, recognizedWords: ["سبح", "لله", "ما", "في"])

        XCTAssertEqual(repeated, .notAdvancing(completedOffset: 3, acceptedOffset: 3))
    }

    func testExistingLocateStillReturnsNilForRejectedOutcome() {
        var locator = ProgressiveTranscriptLocator(
            minimumInitialMatchLength: 4,
            lookBehindWordCount: 4,
            lookAheadWordCount: 24
        )
        let expected = references([
            (1, ["سبح", "لله", "ما", "في", "السماوات"]),
            (22, ["هو", "الله", "الذي"])
        ])

        let location = locator.locate(expected: expected, recognizedWords: ["هو", "الله"])

        XCTAssertNil(location)
    }

    private func references(_ ayahs: [(Int, [String])], surah: Int = 59) -> [RecitationWordReference] {
        ayahs.flatMap { ayah, words in
            words.enumerated().map { offset, word in
                RecitationWordReference(surah: surah, ayah: ayah, wordIndex: offset + 1, text: word)
            }
        }
    }
}
