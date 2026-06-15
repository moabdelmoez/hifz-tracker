import XCTest
@testable import HifzCore

final class TranscriptPositionLocatorTests: XCTestCase {
    func testLocatesTranscriptThatStartsInMiddleOfSelectedSurah() {
        let locator = TranscriptPositionLocator(minimumRunLength: 2)
        let expected = surah73References()

        let location = locator.locate(
            expected: expected,
            recognizedWords: ["نصفه", "او", "انقص", "منه", "قليلا", "او", "زد", "عليه", "ورتل", "القران", "ترعا"]
        )

        XCTAssertEqual(location?.completedThrough.ayah, 4)
        XCTAssertEqual(location?.completedThrough.wordIndex, 5)
        XCTAssertEqual(location?.matchedWordCount, 10)
    }

    func testLocatesFragmentEvenWhenAsrSplitsLeadingWord() {
        let locator = TranscriptPositionLocator(minimumRunLength: 2)
        let expected = surah73References()

        let location = locator.locate(
            expected: expected,
            recognizedWords: ["ي", "ي", "ايها", "المزمل"]
        )

        XCTAssertEqual(location?.completedThrough.ayah, 1)
        XCTAssertEqual(location?.completedThrough.wordIndex, 3)
        XCTAssertEqual(location?.matchedWordCount, 2)
    }

    func testIgnoresSingleWordNoise() {
        let locator = TranscriptPositionLocator(minimumRunLength: 2)

        let location = locator.locate(
            expected: surah73References(),
            recognizedWords: ["س"]
        )

        XCTAssertNil(location)
    }

    private func surah73References() -> [RecitationWordReference] {
        [
            RecitationWordReference(surah: 73, ayah: 1, wordIndex: 1, text: "يا"),
            RecitationWordReference(surah: 73, ayah: 1, wordIndex: 2, text: "أيها"),
            RecitationWordReference(surah: 73, ayah: 1, wordIndex: 3, text: "المزمل"),
            RecitationWordReference(surah: 73, ayah: 2, wordIndex: 1, text: "قم"),
            RecitationWordReference(surah: 73, ayah: 2, wordIndex: 2, text: "الليل"),
            RecitationWordReference(surah: 73, ayah: 2, wordIndex: 3, text: "إلا"),
            RecitationWordReference(surah: 73, ayah: 2, wordIndex: 4, text: "قليلا"),
            RecitationWordReference(surah: 73, ayah: 3, wordIndex: 1, text: "نصفه"),
            RecitationWordReference(surah: 73, ayah: 3, wordIndex: 2, text: "أو"),
            RecitationWordReference(surah: 73, ayah: 3, wordIndex: 3, text: "انقص"),
            RecitationWordReference(surah: 73, ayah: 3, wordIndex: 4, text: "منه"),
            RecitationWordReference(surah: 73, ayah: 3, wordIndex: 5, text: "قليلا"),
            RecitationWordReference(surah: 73, ayah: 4, wordIndex: 1, text: "أو"),
            RecitationWordReference(surah: 73, ayah: 4, wordIndex: 2, text: "زد"),
            RecitationWordReference(surah: 73, ayah: 4, wordIndex: 3, text: "عليه"),
            RecitationWordReference(surah: 73, ayah: 4, wordIndex: 4, text: "ورتل"),
            RecitationWordReference(surah: 73, ayah: 4, wordIndex: 5, text: "القرآن"),
            RecitationWordReference(surah: 73, ayah: 4, wordIndex: 6, text: "ترتيلا")
        ]
    }
}
