import XCTest
import HifzCore
@testable import HifzTracker

final class MushafWordGlyphPresentationTests: XCTestCase {
    func testHiddenFallbackWordDoesNotExposeGlyphText() {
        let word = WordProgress(wordIndex: 1, text: "ﱁ", state: .pending)

        let presentation = MushafWordGlyphPresentation(word: word, isTextVisible: false)

        XCTAssertEqual(presentation.displayText, "")
        XCTAssertEqual(presentation.help, "Hidden")
    }

    func testVisibleFallbackWordKeepsGlyphTextAndExistingHelp() {
        let word = WordProgress(wordIndex: 1, text: "ﱁ", state: .completed)

        let presentation = MushafWordGlyphPresentation(word: word, isTextVisible: true)

        XCTAssertEqual(presentation.displayText, "ﱁ")
        XCTAssertEqual(presentation.help, "Completed")
    }
}
