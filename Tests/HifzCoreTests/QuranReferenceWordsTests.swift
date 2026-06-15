import XCTest
@testable import HifzCore

final class QuranReferenceWordsTests: XCTestCase {
    func testSplitsAndNormalizesReferenceTextForAsrMatching() {
        let words = QuranReferenceWords.wordsForAyah(
            "أو زد عليه ورتل القرآن ترتيلا",
            surah: 73,
            ayah: 4
        )

        XCTAssertEqual(words, ["او", "زد", "عليه", "ورتل", "القران", "ترتيلا"])
    }

    func testRemovesNonFatihaBasmallahPrefixFromFirstAyahReferenceText() {
        let words = QuranReferenceWords.wordsForAyah(
            "بسم الله الرحمن الرحيم قل هو الله أحد",
            surah: 112,
            ayah: 1
        )

        XCTAssertEqual(words, ["قل", "هو", "الله", "احد"])
    }

    func testKeepsFatihaBasmallahBecauseItIsPartOfTheAyah() {
        let words = QuranReferenceWords.wordsForAyah(
            "بسم الله الرحمن الرحيم",
            surah: 1,
            ayah: 1
        )

        XCTAssertEqual(words, ["بسم", "الله", "الرحمن", "الرحيم"])
    }
}
