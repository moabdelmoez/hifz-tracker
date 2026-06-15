import XCTest
@testable import HifzCore

final class NormalizationTests: XCTestCase {
    func testNormalizesQuranTextForAsrComparison() {
        let input = "قُلْ هُوَ ٱللَّهُ أَحَدٌ"

        let normalized = QuranTextNormalizer.asrComparable(input)

        XCTAssertEqual(normalized, "قل هو الله احد")
    }

    func testCollapsesWhitespaceAndRemovesTatweel() {
        let input = "  بِسۡمِ   ٱللَّـهِ  ــ الرَّحْمَٰنِ "

        let normalized = QuranTextNormalizer.asrComparable(input)

        XCTAssertEqual(normalized, "بسم الله الرحمن")
    }
}
