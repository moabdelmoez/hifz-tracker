import XCTest
import CoreGraphics
@testable import HifzCore

final class MushafFontResolverTests: XCTestCase {
    func testBuildsQpcV4TajweedFontNamesForBundledPageFonts() throws {
        for pageNumber in [1, 5, 6, 574, 604] {
            XCTAssertEqual(
                MushafFontResolver.qpcV4TajweedFontName(pageNumber: pageNumber),
                try bundledPostScriptName(pageNumber: pageNumber),
                "Page \(pageNumber) must resolve to the TTF's registered PostScript name."
            )
        }
    }

    func testBuildsQpcV4TajweedFontResourcePathsForBundledFiles() {
        XCTAssertEqual(MushafFontResolver.qpcV4TajweedFontFileName(pageNumber: 1), "p1.ttf")
        XCTAssertEqual(MushafFontResolver.qpcV4TajweedFontFileName(pageNumber: 604), "p604.ttf")
    }

    private func bundledPostScriptName(pageNumber: Int) throws -> String {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let fontURL = root.appending(path: "HifzTracker/Resources/Fonts/p\(pageNumber).ttf")
        guard let provider = CGDataProvider(url: fontURL as CFURL),
              let font = CGFont(provider),
              let postScriptName = font.postScriptName as String? else {
            throw XCTSkip("Bundled font p\(pageNumber).ttf is unavailable.")
        }
        return postScriptName
    }
}
