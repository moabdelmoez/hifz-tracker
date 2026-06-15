import XCTest
@testable import HifzCore

final class HistoryExportTests: XCTestCase {
    func testExportsMetadataOnlyHistoryAsJson() throws {
        let record = SessionRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            endedAt: Date(timeIntervalSince1970: 1_700_000_120),
            surah: 73,
            startAyah: 4,
            lastAyah: 4,
            lastWord: 7,
            completedWordCount: 7,
            correctionEvents: [
                CorrectionEvent(expectedWordIndex: 4, expectedWord: "ورتل", recognizedWord: "وزد")
            ]
        )

        let json = try SessionHistoryExporter.exportJSON(records: [record])
        let text = String(decoding: json, as: UTF8.self)

        XCTAssertTrue(text.contains("\"surah\" : 73"))
        XCTAssertTrue(text.contains("\"expectedWord\" : \"ورتل\""))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("audio"))
    }
}
