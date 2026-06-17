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

    func testRejectsLaterCompleteShortAyahBeforeInitialLock() {
        var locator = ProgressiveTranscriptLocator(
            minimumInitialMatchLength: 4,
            lookBehindWordCount: 4,
            lookAheadWordCount: 24
        )
        let expected = references([
            (1, ["هل", "اتاك", "حديث", "الغاشية"]),
            (2, ["وجوه", "يومئذ", "خاشعة"]),
            (3, ["عاملة", "ناصبة"]),
            (4, ["تصلى", "نارا", "حامية"]),
            (5, ["تسقى", "من", "عين", "انية"]),
            (6, ["ليس", "لهم", "طعام", "الا", "من", "ضريع"]),
            (7, ["لا", "يسمن", "ولا", "يغني", "من", "جوع"]),
            (8, ["وجوه", "يومئذ", "ناعمة"])
        ], surah: 88)

        let location = locator.locate(
            expected: expected,
            recognizedWords: ["وجوه", "يومئذ", "ناعمة"]
        )

        XCTAssertNil(
            location,
            "A complete short ayah later in the selected scope should not initial-lock when it can be an ASR confusion of the near-start ayah."
        )
    }

    func testAcceptsNearbyCompleteShortAyahBeforeInitialLock() throws {
        var locator = ProgressiveTranscriptLocator(
            minimumInitialMatchLength: 4,
            lookBehindWordCount: 4,
            lookAheadWordCount: 24
        )
        let expected = references([
            (1, ["هل", "اتاك", "حديث", "الغاشية"]),
            (2, ["وجوه", "يومئذ", "خاشعة"]),
            (3, ["عاملة", "ناصبة"])
        ], surah: 88)

        let location = try XCTUnwrap(locator.locate(
            expected: expected,
            recognizedWords: ["وجوه", "يومئذ", "خاشعة"]
        ))

        XCTAssertEqual(location.completedThrough.location, "88:2:3")
    }

    func testAcceptsUniqueThreeWordInitialMatchNearStart() throws {
        var locator = ProgressiveTranscriptLocator(
            minimumInitialMatchLength: 4,
            lookBehindWordCount: 4,
            lookAheadWordCount: 24
        )
        let expected = references([
            (1, ["يا", "ايها", "المزمل", "قم", "الليل", "الا"]),
            (2, ["رب", "المشرق", "والمغرب"])
        ], surah: 73)

        let location = try XCTUnwrap(
            locator.locate(expected: expected, recognizedWords: ["يا", "ايها", "المزمل"])
        )

        XCTAssertEqual(location.completedThrough.location, "73:1:3")
        XCTAssertEqual(location.matchedWordCount, 3)
    }

    func testRejectsRepeatedThreeWordInitialMatchUntilFourWordMatch() throws {
        var locator = ProgressiveTranscriptLocator(
            minimumInitialMatchLength: 4,
            lookBehindWordCount: 4,
            lookAheadWordCount: 24
        )
        let expected = references([
            (1, ["يا", "ايها", "الذين", "امنوا", "اوفوا"]),
            (2, ["قريب", "منكم"]),
            (3, ["يا", "ايها", "الذين", "صدقوا", "الله"])
        ], surah: 5)

        let ambiguousShortMatch = locator.locate(
            expected: expected,
            recognizedWords: ["يا", "ايها", "الذين"]
        )
        XCTAssertNil(ambiguousShortMatch)

        let strongMatch = try XCTUnwrap(
            locator.locate(expected: expected, recognizedWords: ["يا", "ايها", "الذين", "امنوا"])
        )
        XCTAssertEqual(strongMatch.completedThrough.location, "5:1:4")
        XCTAssertEqual(strongMatch.matchedWordCount, 4)
    }

    func testRejectsUniqueThreeWordInitialMatchBeyondRelaxedStartLimit() {
        var locator = ProgressiveTranscriptLocator(
            minimumInitialMatchLength: 4,
            lookBehindWordCount: 4,
            lookAheadWordCount: 24
        )
        let filler = (1...32).map { "حشو\($0)" }
        let expected = references([
            (1, filler),
            (2, ["نادر", "قريب", "واضح", "بعد"])
        ])

        let location = locator.locate(expected: expected, recognizedWords: ["نادر", "قريب", "واضح"])

        XCTAssertNil(location)
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

    func testPostLockPrefersAdvancingMatchOverStrongerOldMatch() throws {
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
        let nextLocation = try XCTUnwrap(locator.locate(
            expected: expected,
            recognizedWords: ["سبح", "لله", "ما", "في", "حشو", "السماوات", "وما"]
        ))

        XCTAssertEqual(nextLocation.completedThrough.location, "59:1:6")
        XCTAssertEqual(nextLocation.matchedWordCount, 2)
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

    func testPreparedIndexKeepsRepeatedLiveLocatesFast() throws {
        var locator = ProgressiveTranscriptLocator(
            minimumInitialMatchLength: 4,
            lookBehindWordCount: 12,
            lookAheadWordCount: 96
        )
        let expected = longRepeatedReferences(wordCount: 6_000)
        let index = TranscriptPositionIndex(expected: expected)
        let firstChunk = Array(expected[2_400..<2_416].map(\.text))
        let liveChunks = (0..<360).map { iteration in
            let start = 2_404 + (iteration % 72)
            return Array(expected[start..<(start + 16)].map(\.text))
        }

        let firstLocation = try XCTUnwrap(locator.locate(index: index, recognizedWords: firstChunk))
        XCTAssertEqual(firstLocation.completedThrough.location, "2:5:8")
        XCTAssertEqual(firstLocation.matchedWordCount, 16)

        let startedAt = ContinuousClock.now
        for chunk in liveChunks {
            _ = locator.locate(index: index, recognizedWords: chunk)
        }
        let elapsed = startedAt.duration(to: .now)
        let milliseconds = Double(elapsed.components.seconds * 1_000)
            + Double(elapsed.components.attoseconds) / 1_000_000_000_000_000

        XCTAssertLessThan(milliseconds, 120, "Prepared live locates took \(milliseconds)ms")
    }

    private func references(_ ayahs: [(Int, [String])], surah: Int = 59) -> [RecitationWordReference] {
        ayahs.flatMap { ayah, words in
            words.enumerated().map { offset, word in
                RecitationWordReference(surah: surah, ayah: ayah, wordIndex: offset + 1, text: word)
            }
        }
    }

    private func longRepeatedReferences(wordCount: Int) -> [RecitationWordReference] {
        precondition(wordCount > 0)
        let uniqueWords = (0..<64).map { "كلمة\($0)" }
        return (0..<wordCount).map { offset in
            RecitationWordReference(
                surah: 2,
                ayah: (offset / 10) + 1,
                wordIndex: (offset % 10) + 1,
                text: uniqueWords[offset % uniqueWords.count]
            )
        }
    }
}
