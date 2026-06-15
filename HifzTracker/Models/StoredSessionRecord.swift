import Foundation
import SwiftData
import HifzCore

@Model
final class StoredSessionRecord {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var surah: Int
    var startAyah: Int
    var lastAyah: Int
    var lastWord: Int
    var completedWordCount: Int
    var correctionEventsJSON: String

    init(record: SessionRecord) {
        self.id = record.id
        self.startedAt = record.startedAt
        self.endedAt = record.endedAt
        self.surah = record.surah
        self.startAyah = record.startAyah
        self.lastAyah = record.lastAyah
        self.lastWord = record.lastWord
        self.completedWordCount = record.completedWordCount
        self.correctionEventsJSON = Self.encode(events: record.correctionEvents)
    }

    var coreRecord: SessionRecord {
        SessionRecord(
            id: id,
            startedAt: startedAt,
            endedAt: endedAt,
            surah: surah,
            startAyah: startAyah,
            lastAyah: lastAyah,
            lastWord: lastWord,
            completedWordCount: completedWordCount,
            correctionEvents: Self.decode(json: correctionEventsJSON)
        )
    }

    private static func encode(events: [CorrectionEvent]) -> String {
        guard let data = try? JSONEncoder().encode(events) else {
            return "[]"
        }
        return String(decoding: data, as: UTF8.self)
    }

    private static func decode(json: String) -> [CorrectionEvent] {
        guard let data = json.data(using: .utf8) else {
            return []
        }
        return (try? JSONDecoder().decode([CorrectionEvent].self, from: data)) ?? []
    }
}
