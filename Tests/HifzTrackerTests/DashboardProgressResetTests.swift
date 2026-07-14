import SwiftData
import XCTest
import HifzCore
@testable import HifzTracker

final class DashboardProgressResetTests: XCTestCase {
    @MainActor
    func testResetDeletesAllSavedSessionRecords() throws {
        let container = try ModelContainer(
            for: StoredSessionRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let records = [1, 2].map { word in
            StoredSessionRecord(record: SessionRecord(
                startedAt: Date(timeIntervalSince1970: TimeInterval(word)),
                endedAt: nil,
                surah: 73,
                startAyah: 1,
                lastAyah: 1,
                lastWord: word,
                completedWordCount: word,
                correctionEvents: []
            ))
        }
        records.forEach { context.insert($0) }
        try context.save()

        try resetDashboardProgress(records, in: context)

        XCTAssertTrue(try context.fetch(FetchDescriptor<StoredSessionRecord>()).isEmpty)
    }
}
