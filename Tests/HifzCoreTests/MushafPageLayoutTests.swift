import XCTest
@testable import HifzCore

final class MushafPageLayoutTests: XCTestCase {
    func testLoadsFullMushafPageLinesFromQulLayoutDatabase() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let qpcURL = root.appending(path: "qpc-v4.db")
        let layoutURL = root.appending(path: "HifzTracker/Resources/Layout/kfgqpc-v4-layout.sqlite")
        let mapping = try PageMapping.loadKFGQPCV4Layout(layoutDatabaseURL: layoutURL, qpcDatabaseURL: qpcURL)
        let repo = try SQLiteQuranRepository(
            databaseURL: qpcURL,
            tanzilURL: root.appending(path: "tanzil/quran-simple-clean.txt"),
            pageMapping: mapping,
            layoutDatabaseURL: layoutURL
        )

        let page = try repo.mushafPage(pageNumber: 574)

        XCTAssertEqual(page.pageNumber, 574)
        XCTAssertEqual(page.lines.count, 15)
        XCTAssertEqual(page.lines.first?.lineType, .surahName)
        XCTAssertEqual(page.lines.first?.surahNumber, 73)
        XCTAssertEqual(page.lines.first?.isCentered, true)
        XCTAssertEqual(page.lines[1].lineType, .basmallah)

        let recitationLine = page.lines[3]
        XCTAssertEqual(recitationLine.lineNumber, 4)
        XCTAssertEqual(recitationLine.lineType, .ayah)
        XCTAssertEqual(recitationLine.isCentered, false)
        XCTAssertEqual(recitationLine.firstWordID, 79_572)
        XCTAssertEqual(recitationLine.lastWordID, 79_582)
        XCTAssertEqual(recitationLine.words.count, 11)
        XCTAssertEqual(recitationLine.words.first?.location, "73:4:1")
        XCTAssertEqual(recitationLine.words[6].location, "73:4:7")
        XCTAssertEqual(recitationLine.words.last?.location, "73:5:4")
    }
}
