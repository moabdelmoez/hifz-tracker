import XCTest
@testable import HifzCore

final class ProgressiveTranscriptLocatorTests: XCTestCase {
    func testRejectsShortInitialMatchBeforePlaceIsLocked() {
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

    func testAcceptsCompleteShortAyahAsInitialLock() throws {
        var locator = ProgressiveTranscriptLocator(
            minimumInitialMatchLength: 4,
            lookBehindWordCount: 4,
            lookAheadWordCount: 24
        )
        let expected = references([
            (1, ["انا", "اعطيناك", "الكوثر"]),
            (2, ["فصل", "لربك", "وانحر"])
        ], surah: 108)

        let location = try XCTUnwrap(
            locator.locate(expected: expected, recognizedWords: ["انا", "اعطيناك", "الكوثر"])
        )

        XCTAssertEqual(location.completedThrough.location, "108:1:3")
    }

    func testKeepsLockedProgressFromJumpingToDistantShortMatch() throws {
        var locator = ProgressiveTranscriptLocator(
            minimumInitialMatchLength: 4,
            lookBehindWordCount: 4,
            lookAheadWordCount: 12
        )
        let expected = references([
            (1, ["سبح", "لله", "ما", "في", "السماوات", "وما", "في", "الارض"]),
            (2, ["هو", "الذي", "اخرج", "الذين", "كفروا"]),
            (3, Array(repeating: "حشو", count: 32)),
            (22, ["هو", "الله", "الذي", "لا", "اله"])
        ])

        let initialLocation = try XCTUnwrap(
            locator.locate(expected: expected, recognizedWords: ["سبح", "لله", "ما", "في"])
        )
        XCTAssertEqual(initialLocation.completedThrough.location, "59:1:4")

        let distantShortMatch = locator.locate(expected: expected, recognizedWords: ["هو", "الله", "الذي"])

        XCTAssertNil(distantShortMatch)
    }

    func testContinuesProgressWithinLockedNeighborhood() throws {
        var locator = ProgressiveTranscriptLocator(
            minimumInitialMatchLength: 4,
            lookBehindWordCount: 4,
            lookAheadWordCount: 12
        )
        let expected = references([
            (1, ["سبح", "لله", "ما", "في", "السماوات", "وما", "في", "الارض"]),
            (2, ["هو", "الذي", "اخرج", "الذين", "كفروا"])
        ])

        _ = try XCTUnwrap(locator.locate(expected: expected, recognizedWords: ["سبح", "لله", "ما", "في"]))
        let nextLocation = try XCTUnwrap(locator.locate(expected: expected, recognizedWords: ["هو", "الذي", "اخرج", "الذين"]))

        XCTAssertEqual(nextLocation.completedThrough.location, "59:2:4")
    }

    func testInitialLockPrefersEarliestRepeatedPhraseInSelectedRange() throws {
        var locator = ProgressiveTranscriptLocator(
            minimumInitialMatchLength: 4,
            lookBehindWordCount: 4,
            lookAheadWordCount: 24
        )
        let expected = references([
            (1, ["يا", "ايها", "الذين", "امنوا", "اوفوا", "بالعقود"]),
            (2, ["حشو", "قريب"]),
            (106, ["يا", "ايها", "الذين", "امنوا", "شهادة", "بينكم"])
        ], surah: 5)

        let location = try XCTUnwrap(
            locator.locate(expected: expected, recognizedWords: ["بسم", "الله", "الرحمن", "الرحيم", "يا", "ايها", "الذين", "امنوا", "اف"])
        )

        XCTAssertEqual(location.completedThrough.location, "5:1:4")
    }

    private func references(_ ayahs: [(Int, [String])], surah: Int = 59) -> [RecitationWordReference] {
        ayahs.flatMap { ayah, words in
            words.enumerated().map { offset, word in
                RecitationWordReference(surah: surah, ayah: ayah, wordIndex: offset + 1, text: word)
            }
        }
    }
}
