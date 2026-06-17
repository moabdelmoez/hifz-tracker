import XCTest
import HifzCore
@testable import HifzTracker

final class StoredSessionRecordTests: XCTestCase {
    func testStoresAndRestoresLastSurah() {
        let record = SessionRecord(
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            endedAt: Date(timeIntervalSince1970: 1_700_000_030),
            surah: 100,
            startAyah: 11,
            lastSurah: 101,
            lastAyah: 1,
            lastWord: 4,
            completedWordCount: 4,
            correctionEvents: []
        )

        let stored = StoredSessionRecord(record: record)

        XCTAssertEqual(stored.lastSurah, 101)
        XCTAssertEqual(stored.coreRecord.lastSurah, 101)
    }

    func testMissingStoredLastSurahFallsBackToStartSurah() {
        let record = SessionRecord(
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            endedAt: Date(timeIntervalSince1970: 1_700_000_030),
            surah: 73,
            startAyah: 1,
            lastAyah: 4,
            lastWord: 7,
            completedWordCount: 7,
            correctionEvents: []
        )
        let stored = StoredSessionRecord(record: record)
        stored.lastSurah = 0

        XCTAssertEqual(stored.coreRecord.lastSurah, 73)
    }
}
